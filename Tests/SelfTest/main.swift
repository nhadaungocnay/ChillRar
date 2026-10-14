// Lightweight unit tests runnable without XCTest (Command Line Tools only).
import Foundation
import RarKit

var failures = 0
func expect(_ cond: @autoclosure () -> Bool, _ msg: String, line: Int = #line) {
    if cond() { print("  ✅ \(msg)") } else { print("  ❌ \(msg) (line \(line))"); failures += 1 }
}

let d = URL(fileURLWithPath: "/tmp/x")
func first(_ n: String) -> String { VolumeResolver.candidates(for: d.appendingPathComponent(n)).first!.lastPathComponent }

print("== VolumeResolver")
expect(first("a.part3.rar") == "a.part1.rar", "part3 -> part1")
expect(first("a.part07.rar") == "a.part01.rar", "zero padding kept (2)")
expect(first("a.b.part010.RAR") == "a.b.part001.RAR", "zero padding kept (3) + case")
expect(first("a.r00") == "a.rar", ".r00 -> .rar")
expect(first("a.s12") == "a.rar", ".s12 -> .rar")
expect(first("plain.rar") == "plain.rar", "plain unchanged")
expect(VolumeResolver.isSupported(URL(fileURLWithPath: "/a/b.R05")), ".R05 supported")
expect(!VolumeResolver.isSupported(URL(fileURLWithPath: "/a/b.zip")), ".zip not supported")

print("== Naming")
expect(Extractor.archiveBaseName(URL(fileURLWithPath: "/a/Phim.part01.rar")) == "Phim", "base name strips partNN")
expect(Extractor.archiveBaseName(URL(fileURLWithPath: "/a/Ảnh.RAR")) == "Ảnh", "base name strips .RAR")

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("chillrar-unit-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
FileManager.default.createFile(atPath: tmp.appendingPathComponent("f.txt").path, contents: Data())
try! FileManager.default.createDirectory(at: tmp.appendingPathComponent("dir"), withIntermediateDirectories: true)
expect(Extractor.uniqueURL(for: "f.txt", in: tmp).lastPathComponent == "f 2.txt", "unique file name")
expect(Extractor.uniqueURL(for: "dir", in: tmp, isDirectory: true).lastPathComponent == "dir 2", "unique dir name")
expect(Extractor.uniqueURL(for: "new.txt", in: tmp).lastPathComponent == "new.txt", "free name unchanged")
try? FileManager.default.removeItem(at: tmp)

print("== Selection")
let info = RarArchiveInfo(url: d, entries: [
    RarEntry(id: 0, path: "A", isDirectory: true, isEncrypted: false, unpackedSize: 0, packedSize: 0, modified: nil),
    RarEntry(id: 1, path: "A/x.txt", isDirectory: false, isEncrypted: false, unpackedSize: 1, packedSize: 1, modified: nil),
    RarEntry(id: 2, path: "AB/y.txt", isDirectory: false, isEncrypted: false, unpackedSize: 1, packedSize: 1, modified: nil),
], isSolid: false, isMultiVolume: false, hasEncryptedHeaders: false, comment: nil)
expect(info.expandedSelection([0]) == [0, 1], "dir selection includes children only (not AB/)")

print(failures == 0 ? "All unit tests passed" : "\(failures) unit test(s) failed")
exit(failures == 0 ? 0 : 1)
