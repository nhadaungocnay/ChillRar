import SwiftUI
import AppKit
import RarKit

struct ArchiveDetailView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            searchAndFilterBar
            Divider()
            fileList
            Divider()
            bottomActionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 14) {
            Button(action: { model.closeArchive() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Đóng archive và quay lại màn hình chính")

            Image(systemName: "archivebox.fill")
                .font(.system(size: 26))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(model.archiveURL?.lastPathComponent ?? "Archive")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)

                    if let info = model.archiveInfo {
                        if info.isMultiVolume {
                            TagView(text: "Nhiều phần", color: .purple)
                        }
                        if info.isSolid {
                            TagView(text: "Solid", color: .blue)
                        }
                        if info.hasEncryptedFiles {
                            TagView(text: "Có mật khẩu", color: .orange)
                        }
                    }
                }

                if let path = model.archiveURL?.path {
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if let info = model.archiveInfo {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(info.fileCount) file")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Tổng: \(formatBytes(info.totalUnpackedSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Search & Selection Filter Bar

    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Tìm file trong archive...", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                if !model.searchText.isEmpty {
                    Button(action: { model.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            Spacer()

            Button("Chọn tất cả") {
                model.selectAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Bỏ chọn") {
                model.deselectAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.selectedEntryIds.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }

    // MARK: - File List

    private var fileList: some View {
        Group {
            if model.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(model.loadingMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(model.searchText.isEmpty ? "Archive trống" : "Không tìm thấy file phù hợp")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.filteredEntries) { entry in
                        FileRowView(
                            entry: entry,
                            isSelected: model.selectedEntryIds.contains(entry.id),
                            onToggle: { model.toggleSelection(for: entry) }
                        )
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("Lưu tại:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption)
                    Text(model.effectiveDestination.path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                Button("Đổi...") {
                    model.chooseDestination()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Picker("Tùy chọn gom:", selection: $model.layout) {
                    Text("Tự động (Smart)").tag(ExtractionLayout.smart)
                    Text("Luôn tạo thư mục riêng").tag(ExtractionLayout.folder)
                }
                .pickerStyle(.menu)
                .controlSize(.small)
            }

            HStack {
                if !model.selectedEntryIds.isEmpty {
                    Text("Đã chọn: \(model.selectedEntries.count) mục (\(formatBytes(model.selectedUnpackedSize)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Chưa chọn mục cụ thể: sẽ giải nén toàn bộ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !model.selectedEntryIds.isEmpty {
                    Button("Giải nén mục đã chọn") {
                        model.extract(selectedOnly: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                Button(action: { model.extract(selectedOnly: false) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Giải nén tất cả")
                    }
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let entry: RarEntry
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)

            Image(systemName: iconName(for: entry))
                .foregroundColor(entry.isDirectory ? .accentColor : iconColor(for: entry))
                .font(.system(size: 16))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 13, weight: entry.isDirectory ? .semibold : .regular))
                    .lineLimit(1)

                if (entry.path as NSString).deletingLastPathComponent.count > 0 {
                    Text((entry.path as NSString).deletingLastPathComponent)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if entry.isEncrypted {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .help("File có mã hoá")
            }

            if let date = entry.modified {
                Text(dateFormatted(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .trailing)
            }

            Text(entry.isDirectory ? "--" : formatBytes(entry.unpackedSize))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }

    private func iconName(for entry: RarEntry) -> String {
        if entry.isDirectory { return "folder.fill" }
        let ext = (entry.path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "svg": return "photo"
        case "mp4", "mkv", "mov", "avi", "webm": return "film"
        case "mp3", "flac", "wav", "m4a", "aac": return "music.note"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox"
        case "pdf": return "doc.richtext"
        case "txt", "md", "rtf", "log": return "doc.text"
        case "swift", "c", "cpp", "h", "py", "js", "ts", "json", "xml", "html", "css": return "chevron.left.forwardslash.chevron.right"
        case "dmg", "iso", "pkg": return "externaldrive.fill"
        case "app": return "app.dashed"
        default: return "doc"
        }
    }

    private func iconColor(for entry: RarEntry) -> Color {
        let ext = (entry.path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic": return .pink
        case "mp4", "mkv", "mov", "avi": return .purple
        case "mp3", "flac", "wav", "m4a": return .orange
        case "swift", "py", "js", "cpp": return .green
        case "pdf": return .red
        default: return .secondary
        }
    }

    private func dateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

func formatBytes(_ value: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
}
