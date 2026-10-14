import SwiftUI
import RarKit

struct ProgressModalView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 42))
                .foregroundColor(.accentColor)

            VStack(spacing: 4) {
                Text("Đang giải nén...")
                    .font(.headline)

                if let progress = model.extractionProgress {
                    Text(progress.currentFile.isEmpty ? "Chuẩn bị..." : progress.currentFile)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 320)
                } else {
                    Text("Đang khởi tạo...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                if let progress = model.extractionProgress {
                    ProgressView(value: progress.fraction)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("\(Int(progress.fraction * 100))%")
                            .font(.caption.monospacedDigit())
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(formatBytes(progress.completedBytes)) / \(formatBytes(progress.totalBytes))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Spacer()
                        Text("Đã xử lý: \(progress.filesDone)/\(progress.filesTotal) file")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }
            .frame(width: 320)

            Button("Huỷ") {
                model.cancelExtraction()
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.regular)
        }
        .padding(24)
        .frame(width: 380)
    }
}

struct SuccessModalView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            VStack(spacing: 6) {
                Text("Giải nén thành công!")
                    .font(.headline)

                if let resultURL = model.extractionResultURL {
                    Text("Đã lưu tại:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(resultURL.path)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: 320)

            HStack(spacing: 12) {
                Button("Đóng") {
                    model.showSuccessDialog = false
                }
                .keyboardShortcut(.cancelAction)

                Button(action: {
                    model.revealResultInFinder()
                    model.showSuccessDialog = false
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text("Mở trong Finder")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
