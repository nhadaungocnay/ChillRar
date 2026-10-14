import Foundation
import CUnrar

/// Errors produced by RarKit. Messages are user facing (Vietnamese).
public enum RarError: Error, Equatable, Sendable {
    case cannotOpen(String)
    case notAnArchive
    case unknownFormat
    case missingPassword
    case wrongPassword
    case corruptData(file: String?)
    case missingVolume(String)
    case cannotCreate(file: String?)
    case writeFailed
    case readFailed
    case outOfMemory
    case cancelled
    case unknown(code: Int32)

    /// Maps an `ERAR_*` code to a `RarError`.
    static func from(code: Int32, file: String? = nil, archive: String = "") -> RarError {
        switch code {
        case ERAR_NO_MEMORY: return .outOfMemory
        case ERAR_BAD_DATA: return .corruptData(file: file)
        case ERAR_BAD_ARCHIVE: return .notAnArchive
        case ERAR_UNKNOWN_FORMAT: return .unknownFormat
        case ERAR_EOPEN: return .cannotOpen(archive)
        case ERAR_ECREATE: return .cannotCreate(file: file)
        case ERAR_EREAD: return .readFailed
        case ERAR_EWRITE: return .writeFailed
        case ERAR_MISSING_PASSWORD: return .missingPassword
        case ERAR_BAD_PASSWORD: return .wrongPassword
        default: return .unknown(code: code)
        }
    }

    /// True when the UI should (re)ask the user for a password.
    public var needsPassword: Bool {
        self == .missingPassword || self == .wrongPassword
    }
}

extension RarError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let path):
            return "Không mở được file: \(path)"
        case .notAnArchive:
            return "File không phải archive RAR hợp lệ hoặc đã bị hỏng."
        case .unknownFormat:
            return "Định dạng RAR không được hỗ trợ."
        case .missingPassword:
            return "Archive được bảo vệ bằng mật khẩu."
        case .wrongPassword:
            return "Mật khẩu không đúng."
        case .corruptData(let file):
            return "Dữ liệu bị hỏng (lỗi CRC)" + (file.map { ": \($0)" } ?? ".")
        case .missingVolume(let name):
            return "Thiếu phần tiếp theo của archive: \(name)"
        case .cannotCreate(let file):
            return "Không tạo được file" + (file.map { ": \($0)" } ?? ".")
        case .writeFailed:
            return "Lỗi ghi file (ổ đĩa đầy hoặc không có quyền)."
        case .readFailed:
            return "Lỗi đọc archive."
        case .outOfMemory:
            return "Không đủ bộ nhớ."
        case .cancelled:
            return "Đã huỷ."
        case .unknown(let code):
            return "Lỗi không xác định (mã \(code))."
        }
    }
}
