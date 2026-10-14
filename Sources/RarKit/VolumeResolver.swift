import Foundation

/// Locates the first volume of a multi-volume RAR set, so extraction always
/// starts from the beginning regardless of which part the user opened.
///
/// Supported naming schemes:
/// - New style (RAR 3+):  `name.part1.rar`, `name.part01.rar`, `name.part001.rar`
/// - Old style:           `name.rar`, `name.r00`, `name.r01`, … (`name.s00` after r99)
public enum VolumeResolver {

    /// Returns the URL of the first volume if it exists on disk, else `url`.
    public static func firstVolume(for url: URL, fileManager: FileManager = .default) -> URL {
        for candidate in candidates(for: url) where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        return url
    }

    /// Pure function (no disk access) computing the expected first-volume name.
    public static func candidates(for url: URL) -> [URL] {
        let name = url.lastPathComponent
        let dir = url.deletingLastPathComponent()

        // name.partNNN.rar
        if let match = name.range(of: #"\.part(\d+)\.rar$"#, options: [.regularExpression, .caseInsensitive]) {
            let digits = name[match].dropFirst(5).prefix { $0.isNumber }
            let base = name[..<match.lowerBound]
            let ext = name[match].suffix(4) // keep original case of ".rar"
            let padded = String(repeating: "0", count: max(0, digits.count - 1)) + "1"
            return [dir.appendingPathComponent("\(base).part\(padded)\(ext)")]
        }

        // name.r00 / name.s01 ... -> name.rar
        if name.range(of: #"\.[r-z]\d{2}$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            let base = String(name.dropLast(4))
            return [dir.appendingPathComponent(base + ".rar"),
                    dir.appendingPathComponent(base + ".RAR")]
        }

        return [url]
    }

    /// True when the file looks like a non-first part (used for UI hints).
    public static func isSecondaryVolume(_ url: URL) -> Bool {
        candidates(for: url).first?.lastPathComponent != url.lastPathComponent
    }

    /// File extensions accepted by the app.
    public static func isSupported(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name.hasSuffix(".rar")
            || name.range(of: #"\.[r-z]\d{2}$"#, options: .regularExpression) != nil
    }
}
