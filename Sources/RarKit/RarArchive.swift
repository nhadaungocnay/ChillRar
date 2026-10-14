import Foundation
import CUnrar

// MARK: - Wide string helpers (wchar_t is 32-bit UTF-32 on macOS)

enum WideString {
    /// Null-terminated UTF-32 buffer.
    static func make(_ string: String) -> [wchar_t] {
        string.unicodeScalars.map { wchar_t(bitPattern: $0.value) } + [0]
    }

    static func string(from pointer: UnsafePointer<wchar_t>, maxLength: Int) -> String {
        var scalars = String.UnicodeScalarView()
        var i = 0
        while i < maxLength, pointer[i] != 0 {
            if let s = Unicode.Scalar(UInt32(bitPattern: pointer[i])) { scalars.append(s) }
            i += 1
        }
        return String(scalars)
    }

    /// Reads a fixed-size C array (imported by Swift as a tuple) of wchar_t.
    static func string<T>(fromTuple tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            let buffer = raw.bindMemory(to: wchar_t.self)
            return string(from: buffer.baseAddress!, maxLength: buffer.count)
        }
    }

    /// Copies `string` into a C buffer of `capacity` wchar_t, always null terminated.
    static func copy(_ string: String, to buffer: UnsafeMutablePointer<wchar_t>, capacity: Int) {
        guard capacity > 0 else { return }
        var i = 0
        for scalar in string.unicodeScalars where i < capacity - 1 {
            buffer[i] = wchar_t(bitPattern: scalar.value)
            i += 1
        }
        buffer[i] = 0
    }
}

// MARK: - Cancellation

/// Thread-safe cancellation flag shared between the UI and the unrar worker.
public final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
    }
}

// MARK: - Callback bridge

/// State shared with the C callback through `UserData`.
final class CallbackContext {
    var password: String?
    var passwordRequested = false
    var missingVolume: String?
    var cancel: CancellationToken?
    /// Only count bytes for files we actually extract (skipped files in solid
    /// archives are decompressed too but don't produce PROCESSDATA, still be safe).
    var countBytes = false
    var onBytes: ((Int) -> Void)?
}

/// C callback used for every archive operation. It must not capture context,
/// so state is passed through `UserData` as an unretained `CallbackContext`.
private let unrarCallback: UNRARCALLBACK = { msg, userData, p1, p2 in
    guard let raw = UnsafeRawPointer(bitPattern: userData) else { return -1 }
    let ctx = Unmanaged<CallbackContext>.fromOpaque(raw).takeUnretainedValue()

    switch msg {
    case UCM_PROCESSDATA.rawValue:
        if ctx.cancel?.isCancelled == true { return -1 }
        if ctx.countBytes { ctx.onBytes?(Int(p2)) }
        return 1

    case UCM_NEEDPASSWORDW.rawValue:
        ctx.passwordRequested = true
        guard let password = ctx.password, !password.isEmpty,
              let buffer = UnsafeMutablePointer<wchar_t>(bitPattern: p1) else { return -1 }
        WideString.copy(password, to: buffer, capacity: Int(p2))
        return 1

    case UCM_NEEDPASSWORD.rawValue:
        // ANSI fallback: only reached when the wide variant returned nothing.
        return -1

    case UCM_CHANGEVOLUMEW.rawValue:
        if p2 == Int(RAR_VOL_ASK) {
            // The next volume could not be found on disk.
            if let name = UnsafePointer<wchar_t>(bitPattern: p1) {
                ctx.missingVolume = WideString.string(from: name, maxLength: 2048)
            }
            return -1
        }
        return ctx.cancel?.isCancelled == true ? -1 : 1

    case UCM_CHANGEVOLUME.rawValue:
        return p2 == Int(RAR_VOL_ASK) ? -1 : 1

    case UCM_LARGEDICT.rawValue:
        // RAR 7 archives may use dictionaries > 4 GB. Allow them.
        return 1

    default:
        return 0
    }
}

// MARK: - Serial queue

/// UnRAR keeps global error state (`ErrHandler`), so every call into the
/// library must be serialized on this queue.
public enum UnrarQueue {
    static let queue = DispatchQueue(label: "com.chillrar.unrar", qos: .userInitiated)
    private static let localeOnce: Void = { cunrar_use_utf8_locale() }()

    /// Runs `work` on the unrar queue and returns its result asynchronously.
    public static func run<T>(_ work: @escaping () throws -> T) async throws -> T {
        _ = localeOnce
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }
}

// MARK: - Archive operations

/// Low level, synchronous access to a RAR archive. Call only through
/// `UnrarQueue.run` (or from the unrar queue).
public enum RarArchive {

    /// Opens an archive handle. Caller must `RARCloseArchive` it.
    private static func open(_ url: URL, mode: Int32, context: CallbackContext)
        throws -> (handle: UnsafeMutableRawPointer, flags: UInt32, comment: String?)
    {
        var path = WideString.make(url.path)
        let commentCapacity = 64 * 1024
        let commentBuffer = UnsafeMutablePointer<wchar_t>.allocate(capacity: commentCapacity)
        defer { commentBuffer.deallocate() }

        var data = RAROpenArchiveDataEx()
        data.OpenMode = UInt32(mode)
        data.Callback = unrarCallback
        data.UserData = Int(bitPattern: Unmanaged.passUnretained(context).toOpaque())
        data.CmtBufW = commentBuffer
        data.CmtBufSize = UInt32(commentCapacity)

        let handle: UnsafeMutableRawPointer? = path.withUnsafeMutableBufferPointer { buf in
            data.ArcNameW = buf.baseAddress
            return RAROpenArchiveEx(&data)
        }

        guard let handle, data.OpenResult == ERAR_SUCCESS else {
            throw mapError(Int32(data.OpenResult), context: context, file: nil, url: url, encrypted: true)
        }

        var comment: String?
        if data.CmtState == 1, data.CmtSize > 0 {
            comment = WideString.string(from: commentBuffer, maxLength: Int(data.CmtSize))
        }
        return (handle, data.Flags, comment)
    }

    private static func mapError(_ code: Int32, context: CallbackContext, file: String?,
                                 url: URL, encrypted: Bool) -> RarError {
        if context.cancel?.isCancelled == true { return .cancelled }
        if let volume = context.missingVolume {
            return .missingVolume((volume as NSString).lastPathComponent)
        }
        if code == ERAR_MISSING_PASSWORD
            || (context.passwordRequested && (context.password ?? "").isEmpty) {
            return .missingPassword
        }
        // RAR4 has no password check value: a wrong password shows up as CRC
        // error (bad data) on encrypted files or broken encrypted headers.
        if encrypted, context.passwordRequested, !(context.password ?? "").isEmpty,
           code == ERAR_BAD_DATA || code == ERAR_BAD_ARCHIVE || code == ERAR_BAD_PASSWORD {
            return .wrongPassword
        }
        return RarError.from(code: code, file: file, archive: url.lastPathComponent)
    }

    private static func makeHeader() -> UnsafeMutablePointer<RARHeaderDataEx> {
        // ~16 KB struct: keep it on the heap. Reserved fields must be zero.
        let header = UnsafeMutablePointer<RARHeaderDataEx>.allocate(capacity: 1)
        header.initialize(to: RARHeaderDataEx())
        return header
    }

    /// Converts Windows FILETIME (100 ns ticks since 1601-01-01) to Date.
    private static func date(low: UInt32, high: UInt32) -> Date? {
        let ticks = (UInt64(high) << 32) | UInt64(low)
        guard ticks > 0 else { return nil }
        let secondsFrom1601 = Double(ticks) / 10_000_000
        return Date(timeIntervalSince1970: secondsFrom1601 - 11_644_473_600)
    }

    /// Lists all entries of the archive (follows multi-volume sets).
    public static func list(_ url: URL, password: String?) throws -> RarArchiveInfo {
        let context = CallbackContext()
        context.password = password
        let (handle, flags, comment) = try open(url, mode: RAR_OM_LIST, context: context)
        defer { RARCloseArchive(handle) }

        let header = makeHeader()
        defer { header.deinitialize(count: 1); header.deallocate() }

        var entries: [RarEntry] = []
        while true {
            let rc = RARReadHeaderEx(handle, header)
            if rc == ERAR_END_ARCHIVE { break }
            if rc != ERAR_SUCCESS {
                throw mapError(rc, context: context, file: nil, url: url,
                               encrypted: flags & UInt32(ROADF_ENCHEADERS) != 0)
            }
            let h = header.pointee
            entries.append(RarEntry(
                id: entries.count,
                path: WideString.string(fromTuple: h.FileNameW),
                isDirectory: h.Flags & UInt32(RHDF_DIRECTORY) != 0,
                isEncrypted: h.Flags & UInt32(RHDF_ENCRYPTED) != 0,
                unpackedSize: UInt64(h.UnpSizeHigh) << 32 | UInt64(h.UnpSize),
                packedSize: UInt64(h.PackSizeHigh) << 32 | UInt64(h.PackSize),
                modified: date(low: h.MtimeLow, high: h.MtimeHigh)
            ))
            let prc = RARProcessFileW(handle, RAR_SKIP, nil, nil)
            if prc != ERAR_SUCCESS {
                throw mapError(prc, context: context, file: nil, url: url, encrypted: false)
            }
        }

        return RarArchiveInfo(
            url: url,
            entries: entries,
            isSolid: flags & UInt32(ROADF_SOLID) != 0,
            isMultiVolume: flags & UInt32(ROADF_VOLUME) != 0,
            hasEncryptedHeaders: flags & UInt32(ROADF_ENCHEADERS) != 0,
            comment: comment
        )
    }

    /// Extracts entries into `destination` (which must exist).
    /// - Parameters:
    ///   - selection: entry ids to extract; `nil` extracts everything.
    ///   - totalBytes: expected total for progress reporting.
    public static func extract(_ url: URL,
                               to destination: URL,
                               password: String?,
                               selection: Set<Int>?,
                               totalBytes: UInt64,
                               totalFiles: Int,
                               cancel: CancellationToken?,
                               progress: ((ExtractionProgress) -> Void)?) throws {
        let context = CallbackContext()
        context.password = password
        context.cancel = cancel

        var completed: UInt64 = 0
        var filesDone = 0
        var currentFile = ""
        var lastReport = Date.distantPast

        func report(force: Bool = false) {
            guard let progress else { return }
            let now = Date()
            // Throttle UI updates to ~20 per second.
            guard force || now.timeIntervalSince(lastReport) > 0.05 else { return }
            lastReport = now
            progress(ExtractionProgress(completedBytes: completed, totalBytes: totalBytes,
                                        currentFile: currentFile, filesDone: filesDone,
                                        filesTotal: totalFiles))
        }
        context.onBytes = { count in
            completed += UInt64(count)
            report()
        }

        let (handle, flags, _) = try open(url, mode: RAR_OM_EXTRACT, context: context)
        defer { RARCloseArchive(handle) }
        let encryptedHeaders = flags & UInt32(ROADF_ENCHEADERS) != 0

        let header = makeHeader()
        defer { header.deinitialize(count: 1); header.deallocate() }

        var destPath = WideString.make(destination.path)
        var index = 0
        while true {
            if cancel?.isCancelled == true { throw RarError.cancelled }

            let rc = RARReadHeaderEx(handle, header)
            if rc == ERAR_END_ARCHIVE { break }
            if rc != ERAR_SUCCESS {
                throw mapError(rc, context: context, file: nil, url: url, encrypted: encryptedHeaders)
            }

            let h = header.pointee
            if h.Flags & UInt32(RHDF_SPLITBEFORE) != 0 {
                // Continuation of a file started in a previous volume; it was
                // already handled (or this isn't the first volume).
                _ = RARProcessFileW(handle, RAR_SKIP, nil, nil)
                continue
            }

            let name = WideString.string(fromTuple: h.FileNameW)
            let isDir = h.Flags & UInt32(RHDF_DIRECTORY) != 0
            let encrypted = h.Flags & UInt32(RHDF_ENCRYPTED) != 0
            let selected = selection?.contains(index) ?? true
            currentFile = name
            context.countBytes = selected && !isDir
            if selected { report(force: true) }

            let prc = destPath.withUnsafeMutableBufferPointer { buf in
                RARProcessFileW(handle, selected ? RAR_EXTRACT : RAR_SKIP, buf.baseAddress, nil)
            }
            if prc != ERAR_SUCCESS {
                throw mapError(prc, context: context, file: name, url: url,
                               encrypted: encrypted || encryptedHeaders)
            }
            if selected && !isDir { filesDone += 1 }
            index += 1
        }
        report(force: true)
    }
}
