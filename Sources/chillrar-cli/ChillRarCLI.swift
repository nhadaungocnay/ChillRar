import Foundation
import RarKit

// chillrar – command line front-end for RarKit.
//
//   chillrar l <archive.rar> [-p password]
//   chillrar x <archive.rar> [-p password] [-o output_dir] [--folder]

func usage() -> Never {
    let text = """
    ChillRar CLI
      chillrar l <archive.rar> [-p password]                 Liệt kê file
      chillrar x <archive.rar> [-p password] [-o dir] [--folder]  Giải nén
    """
    FileHandle.standardError.write((text + "\n").data(using: .utf8)!)
    exit(64)
}

func formatBytes(_ value: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
}

@main
struct ChillRarCLI {
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 2 else { usage() }
        let command = args.removeFirst()
        let archive = URL(fileURLWithPath: args.removeFirst())

        var password: String?
        var output: URL?
        var layout = ExtractionLayout.smart
        while !args.isEmpty {
            let flag = args.removeFirst()
            if (flag == "-p" || flag == "-o") && args.isEmpty { usage() }
            switch flag {
            case "-p": password = args.removeFirst()
            case "-o": output = URL(fileURLWithPath: args.removeFirst())
            case "--folder": layout = .folder
            default: usage()
            }
        }

        do {
            switch command {
            case "l":
                let info = try await Extractor.list(archive, password: password)
                for e in info.entries {
                    let size = e.isDirectory ? "<DIR>" : formatBytes(e.unpackedSize)
                    print(String(format: "%@ %12@  %@", e.isEncrypted ? "*" : " ", size, e.path))
                }
                print("\(info.fileCount) file, \(formatBytes(info.totalUnpackedSize))"
                      + (info.isSolid ? ", solid" : "")
                      + (info.isMultiVolume ? ", multi-volume" : "")
                      + (info.hasEncryptedHeaders ? ", encrypted headers" : ""))
            case "x":
                let dest = output ?? archive.deletingLastPathComponent()
                let request = ExtractionRequest(archive: archive, destinationDirectory: dest,
                                                password: password, layout: layout)
                let result = try await Extractor.extract(request) { p in
                    let pct = Int(p.fraction * 100)
                    FileHandle.standardError.write("\r\(pct)%  \(p.currentFile)\u{1B}[K".data(using: .utf8)!)
                }
                FileHandle.standardError.write("\n".data(using: .utf8)!)
                print(result.path)
            default:
                usage()
            }
        } catch {
            FileHandle.standardError.write("\nLỗi: \(error.localizedDescription)\n".data(using: .utf8)!)
            exit((error as? RarError)?.needsPassword == true ? 3 : 1)
        }
    }
}
