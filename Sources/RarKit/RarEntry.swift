import Foundation

/// A file or directory stored inside a RAR archive.
public struct RarEntry: Identifiable, Hashable, Sendable {
    /// Position of the entry in the archive (stable across list calls).
    public let id: Int
    /// Relative path inside the archive, always using `/` as separator.
    public let path: String
    public let isDirectory: Bool
    public let isEncrypted: Bool
    public let unpackedSize: UInt64
    public let packedSize: UInt64
    public let modified: Date?

    public var name: String { (path as NSString).lastPathComponent }

    public init(id: Int, path: String, isDirectory: Bool, isEncrypted: Bool,
                unpackedSize: UInt64, packedSize: UInt64, modified: Date?) {
        self.id = id
        self.path = path
        self.isDirectory = isDirectory
        self.isEncrypted = isEncrypted
        self.unpackedSize = unpackedSize
        self.packedSize = packedSize
        self.modified = modified
    }
}

/// Result of listing an archive.
public struct RarArchiveInfo: Sendable {
    public let url: URL
    public let entries: [RarEntry]
    public let isSolid: Bool
    public let isMultiVolume: Bool
    public let hasEncryptedHeaders: Bool
    public let comment: String?

    public init(url: URL, entries: [RarEntry], isSolid: Bool, isMultiVolume: Bool,
                hasEncryptedHeaders: Bool, comment: String?) {
        self.url = url
        self.entries = entries
        self.isSolid = isSolid
        self.isMultiVolume = isMultiVolume
        self.hasEncryptedHeaders = hasEncryptedHeaders
        self.comment = comment
    }

    public var totalUnpackedSize: UInt64 {
        entries.reduce(0) { $0 + ($1.isDirectory ? 0 : $1.unpackedSize) }
    }

    public var fileCount: Int { entries.filter { !$0.isDirectory }.count }

    public var hasEncryptedFiles: Bool { hasEncryptedHeaders || entries.contains { $0.isEncrypted } }
}

/// Progress snapshot reported during extraction.
public struct ExtractionProgress: Sendable {
    public let completedBytes: UInt64
    public let totalBytes: UInt64
    public let currentFile: String
    public let filesDone: Int
    public let filesTotal: Int

    public var fraction: Double {
        totalBytes == 0 ? (filesTotal == 0 ? 0 : Double(filesDone) / Double(filesTotal))
                        : min(1, Double(completedBytes) / Double(totalBytes))
    }
}
