import SwiftUI
import AppKit

@main
struct ChillRarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onAppear {
                    appDelegate.appModel = model
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Mở file .rar...") {
                    openFileDialog()
                }
                .keyboardShortcut("o", modifiers: .command)

                if model.archiveURL != nil {
                    Button("Đóng file") {
                        model.closeArchive()
                    }
                    .keyboardShortcut("w", modifiers: .command)
                }
            }

            CommandGroup(after: .pasteboard) {
                if model.archiveURL != nil {
                    Button("Chọn tất cả file") {
                        model.selectAll()
                    }
                    .keyboardShortcut("a", modifiers: .command)

                    Button("Bỏ chọn") {
                        model.deselectAll()
                    }
                }
            }
        }
    }

    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Mở file .rar"
        if panel.runModal() == .OK, let url = panel.url {
            model.openArchive(url: url)
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            if model.archiveURL == nil {
                DropZoneView(model: model)
            } else {
                ArchiveDetailView(model: model)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .sheet(isPresented: $model.showPasswordSheet) {
            PasswordModalView(model: model)
        }
        .sheet(isPresented: $model.isExtracting) {
            ProgressModalView(model: model)
        }
        .sheet(isPresented: $model.showSuccessDialog) {
            SuccessModalView(model: model)
        }
        .alert("Thông báo", isPresented: $model.showErrorAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(model.errorMessage)
        }
    }
}
