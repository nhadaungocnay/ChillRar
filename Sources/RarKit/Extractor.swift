import Foundation

/// How extracted items are placed in the destination directory.
public enum ExtractionLayout: String, CaseIterable, Sendable {
    /// Like Archive Utility: a single top-level item goes straight into the
    /// destination, otherwise everything is wrapped in a folder named after the archive.
    case smart
    /// Always create a folder named after the archive.
    case folder
}

public struct ExtractionRequest: Sendable {
    public var archive: URL
    public var destinationDirectory: URL
    public var password: String?
    /// Entry ids to extract (`nil` = all). Directories include their contents.
    public var selection: Set<Int>?
    public var layout: ExtractionLayout

    public init(archive: URL, destinationDirectory: URL, password: String? = nil,
                selection: Set<Int>? = nil, layout: ExtractionLayout = .smart) {
        self.archive = archive
        self.destinationDirectory = destinationDirectory
        self.password = password
        self.selection = selection
        self.layout = layout
    }
}

/// High level, async API used by the app and the CLI.
///
/// Extraction never overwrites existing files: it unpacks into a hidden
/// temporary folder next to the destination, then moves the result into place
/// with a unique name. On failure or cancellation the temp folder is removed.
public enum Extractor {

    public static func list(_ url: URL, password: String? = nil) async throws -> RarArchiveInfo {
        let first = VolumeResolver.firstVolume(for: url)
        return try await UnrarQueue.run { try RarArchive.list(first, password: password) }
    }

    /// Extracts and returns the URL of the produced item (file or folder).
    @discardableResult
    public static func extract(_ request: ExtractionRequest,
                               info knownInfo: RarArchiveInfo? = nil,
                               cancel: CancellationToken? = nil,
                               progress: (@Sendable (ExtractionProgress) -> Void)? = nil) async throws -> URL {
        let fm = FileManager.default
        let archive = VolumeResolver.firstVolume(for: request.archive)
        let info: RarArchiveInfo
        if let knownInfo { info = knownInfo } else { info = try await list(archive, password: request.password) }

        let selection = request.selection.map { info.expandedSelection($0) }
        let chosen = info.entries.filter { selection?.contains($0.id) ?? true }
        let totalBytes = chosen.reduce(UInt64(0)) { $0 + ($1.isDirectory ? 0 : $1.unpackedSize) }
        let totalFiles = chosen.filter { !$0.isDirectory }.count

        let destDir = request.destinationDirectory
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        guard fm.isWritableFile(atPath: destDir.path) else {
            throw RarError.cannotCreate(file: destDir.path)
        }

        let temp = destDir.appendingPathComponent(".chillrar-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: temp, withIntermediateDirectories: false)

        do {
            try await UnrarQueue.run {
                try RarArchive.extract(archive, to: temp, password: request.password,
                                       selection: selection, totalBytes: totalBytes,
                                       totalFiles: totalFiles, cancel: cancel, progress: progress)
            }
            if cancel?.isCancelled == true { throw RarError.cancelled }
            let result = try finalize(temp: temp, in: destDir,
                                      baseName: archiveBaseName(archive), layout: request.layout)
            Quarantine.propagate(from: archive, to: result)
            return result
        } catch {
            try? fm.removeItem(at: temp)
            throw error
        }
    }

    // MARK: - Placement

    static func finalize(temp: URL, in destDir: URL, baseName: String,
                         layout: ExtractionLayout) throws -> URL {
        let fm = FileManager.default
        let items = try fm.contentsOfDirectory(at: temp, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent != ".DS_Store" }

        if layout == .smart, items.count == 1, let only = items.first {
            let target = uniqueURL(for: only.lastPathComponent, in: destDir)
            try fm.moveItem(at: only, to: target)
            try fm.removeItem(at: temp)
            return target
        }
        let target = uniqueURL(for: baseName, in: destDir, isDirectory: true)
        try fm.moveItem(at: temp, to: target)
        return target
    }

    /// `name`, `name 2`, `name 3`, … keeping the file extension at the end.
    public static func uniqueURL(for name: String, in dir: URL, isDirectory: Bool = false) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }

        let ns = name as NSString
        let ext = isDirectory ? "" : ns.pathExtension
        let stem = ext.isEmpty ? name : ns.deletingPathExtension
        var n = 2
        repeat {
            let newName = ext.isEmpty ? "\(stem) \(n)" : "\(stem) \(n).\(ext)"
            candidate = dir.appendingPathComponent(newName)
            n += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    /// `Movie.part01.rar` -> `Movie`, `Photos.rar` -> `Photos`.
    public static func archiveBaseName(_ url: URL) -> String {
        var name = url.lastPathComponent
        if let r = name.range(of: #"(\.part\d+)?\.rar$"#, options: [.regularExpression, .caseInsensitive]) {
            name.removeSubrange(r)
        }
        return name.isEmpty ? "Archive" : name
    }
}

extension RarArchiveInfo {
    /// Adds every descendant of selected directories.
    public func expandedSelection(_ ids: Set<Int>) -> Set<Int> {
        let dirPrefixes = entries.filter { ids.contains($0.id) && $0.isDirectory }.map { $0.path + "/" }
        guard !dirPrefixes.isEmpty else { return ids }
        var result = ids
        for entry in entries where dirPrefixes.contains(where: { entry.path.hasPrefix($0) }) {
            result.insert(entry.id)
        }
        return result
    }
}

/// Propagates Gatekeeper's quarantine attribute from a downloaded archive to
/// the extracted files, like Archive Utility does.
enum Quarantine {
    static let name = "com.apple.quarantine"

    static func propagate(from archive: URL, to item: URL) {
        let size = getxattr(archive.path, name, nil, 0, 0, 0)
        guard size > 0 else { return }
        var value = [UInt8](repeating: 0, count: size)
        guard getxattr(archive.path, name, &value, size, 0, 0) == size else { return }

        func apply(_ url: URL) { _ = setxattr(url.path, name, value, size, 0, XATTR_NOFOLLOW) }
        apply(item)
        if let enumerator = FileManager.default.enumerator(at: item, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator { apply(url) }
        }
    }
}
