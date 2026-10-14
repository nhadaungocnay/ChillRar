import SwiftUI
import AppKit
import UniformTypeIdentifiers
import RarKit

struct DropZoneView: View {
    @ObservedObject var model: AppModel
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(isTargeted ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                    .frame(width: 130, height: 130)

                Image(systemName: isTargeted ? "arrow.down.doc.fill" : "archivebox.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .foregroundColor(isTargeted ? .accentColor : .secondary)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)
            }

            VStack(spacing: 8) {
                Text("Kéo và thả file .rar vào đây")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))

                Text("hoặc mở trực tiếp file nén từ máy Mac của bạn")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(action: selectFile) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                    Text("Chọn file .rar...")
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 12) {
                FeaturePill(icon: "lock.shield", text: "Mật khẩu")
                FeaturePill(icon: "square.split.2x2", text: "Nhiều phần (.partN)")
                FeaturePill(icon: "cpu", text: "Native Apple Silicon")
                FeaturePill(icon: "eye", text: "Xem trước file")
            }
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .padding(24)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "rar") ?? .data,
            UTType(filenameExtension: "r00") ?? .data,
            UTType(filenameExtension: "part1.rar") ?? .data,
        ]
        panel.prompt = "Mở Archive"

        if panel.runModal() == .OK, let url = panel.url {
            model.openArchive(url: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                if VolumeResolver.isSupported(url) {
                    self.model.openArchive(url: url)
                } else {
                    self.model.showError("Định dạng file không được hỗ trợ. Hãy chọn file .rar hoặc các phần chia nhỏ.")
                }
            }
        }
        return true
    }
}

struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08))
        .foregroundColor(.secondary)
        .cornerRadius(6)
    }
}
