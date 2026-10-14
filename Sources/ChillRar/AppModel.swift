import Foundation
import SwiftUI
import AppKit
import RarKit

@MainActor
public final class AppModel: ObservableObject {
    // Current Archive
    @Published public var archiveURL: URL?
    @Published public var archiveInfo: RarArchiveInfo?
    @Published public var isLoading: Bool = false
    @Published public var loadingMessage: String = ""
    @Published public var currentPassword: String?

    // Filter & Selection
    @Published public var searchText: String = ""
    @Published public var selectedEntryIds: Set<Int> = []

    // Extraction Options
    @Published public var destinationDirectory: URL?
    @Published public var layout: ExtractionLayout = .smart

    // Extraction Status
    @Published public var isExtracting: Bool = false
    @Published public var extractionProgress: ExtractionProgress?
    @Published public var extractionResultURL: URL?
    @Published public var showSuccessDialog: Bool = false
    private var cancellationToken: CancellationToken?

    // Password Sheet
    @Published public var showPasswordSheet: Bool = false
    @Published public var passwordInput: String = ""
    @Published public var passwordError: String?
    private var pendingPasswordAction: ((String) -> Void)?
    private var pendingPasswordCancel: (() -> Void)?

    // Alert / Errors
    @Published public var showErrorAlert: Bool = false
    @Published public var errorMessage: String = ""

    public init() {}

    // MARK: - Computed Properties

    public var filteredEntries: [RarEntry] {
        guard let entries = archiveInfo?.entries else { return [] }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return entries
        }
        let term = searchText.lowercased()
        return entries.filter { $0.path.lowercased().contains(term) }
    }

    public var selectedEntries: [RarEntry] {
        guard let entries = archiveInfo?.entries else { return [] }
        return entries.filter { selectedEntryIds.contains($0.id) }
    }

    public var selectedUnpackedSize: UInt64 {
        selectedEntries.reduce(0) { $0 + ($1.isDirectory ? 0 : $1.unpackedSize) }
    }

    public var effectiveDestination: URL {
        if let destinationDirectory {
            return destinationDirectory
        }
        if let archiveURL {
            return archiveURL.deletingLastPathComponent()
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    // MARK: - Archive Loading

    public func openArchive(url: URL, password: String? = nil) {
        let targetURL = VolumeResolver.firstVolume(for: url)
        self.archiveURL = targetURL
        self.currentPassword = password
        self.destinationDirectory = targetURL.deletingLastPathComponent()
        self.selectedEntryIds.removeAll()
        self.searchText = ""
        self.isLoading = true
        self.loadingMessage = "Đang đọc danh sách file..."

        Task {
            do {
                let info = try await Extractor.list(targetURL, password: password)
                self.archiveInfo = info
                self.isLoading = false
            } catch let rarErr as RarError where rarErr.needsPassword {
                self.isLoading = false
                self.promptPassword(
                    errorMessage: rarErr == .wrongPassword ? "Mật khẩu không đúng. Vui lòng thử lại:" : nil,
                    onSuccess: { [weak self] pwd in
                        self?.openArchive(url: targetURL, password: pwd)
                    },
                    onCancel: { [weak self] in
                        if self?.archiveInfo == nil {
                            self?.closeArchive()
                        }
                    }
                )
            } catch {
                self.isLoading = false
                self.showError(error.localizedDescription)
            }
        }
    }

    public func closeArchive() {
        self.archiveURL = nil
        self.archiveInfo = nil
        self.selectedEntryIds.removeAll()
        self.searchText = ""
        self.destinationDirectory = nil
        self.currentPassword = nil
        self.isExtracting = false
        self.extractionProgress = nil
    }

    // MARK: - Selection

    public func selectAll() {
        guard let entries = archiveInfo?.entries else { return }
        selectedEntryIds = Set(entries.map { $0.id })
    }

    public func deselectAll() {
        selectedEntryIds.removeAll()
    }

    public func toggleSelection(for entry: RarEntry) {
        if selectedEntryIds.contains(entry.id) {
            selectedEntryIds.remove(entry.id)
        } else {
            selectedEntryIds.insert(entry.id)
        }
    }

    // MARK: - Password Handling

    public func promptPassword(errorMessage: String? = nil,
                               onSuccess: @escaping (String) -> Void,
                               onCancel: @escaping () -> Void) {
        self.passwordInput = ""
        self.passwordError = errorMessage
        self.pendingPasswordAction = onSuccess
        self.pendingPasswordCancel = onCancel
        self.showPasswordSheet = true
    }

    public func submitPassword() {
        guard !passwordInput.isEmpty else { return }
        showPasswordSheet = false
        let pwd = passwordInput
        currentPassword = pwd
        pendingPasswordAction?(pwd)
        pendingPasswordAction = nil
        pendingPasswordCancel = nil
    }

    public func cancelPasswordPrompt() {
        showPasswordSheet = false
        pendingPasswordCancel?()
        pendingPasswordAction = nil
        pendingPasswordCancel = nil
    }

    // MARK: - Extraction

    public func extract(selectedOnly: Bool) {
        guard let archiveURL else { return }
        let dest = effectiveDestination
        let token = CancellationToken()
        self.cancellationToken = token

        let selection: Set<Int>? = selectedOnly && !selectedEntryIds.isEmpty ? selectedEntryIds : nil
        let request = ExtractionRequest(
            archive: archiveURL,
            destinationDirectory: dest,
            password: currentPassword,
            selection: selection,
            layout: layout
        )

        self.isExtracting = true
        self.extractionProgress = nil
        self.extractionResultURL = nil

        Task {
            do {
                let result = try await Extractor.extract(request, info: self.archiveInfo, cancel: token) { [weak self] p in
                    Task { @MainActor [weak self] in
                        self?.extractionProgress = p
                    }
                }
                self.isExtracting = false
                self.extractionResultURL = result
                self.showSuccessDialog = true
            } catch let rarErr as RarError where rarErr.needsPassword {
                self.isExtracting = false
                self.promptPassword(
                    errorMessage: rarErr == .wrongPassword ? "Mật khẩu không đúng. Vui lòng nhập lại:" : "Yêu cầu mật khẩu:",
                    onSuccess: { [weak self] pwd in
                        self?.currentPassword = pwd
                        self?.extract(selectedOnly: selectedOnly)
                    },
                    onCancel: {}
                )
            } catch let rarErr as RarError where rarErr == .cancelled {
                self.isExtracting = false
            } catch {
                self.isExtracting = false
                self.showError(error.localizedDescription)
            }
        }
    }

    public func cancelExtraction() {
        cancellationToken?.cancel()
        cancellationToken = nil
        isExtracting = false
    }

    // MARK: - Helpers

    public func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Chọn thư mục"
        if let current = destinationDirectory {
            panel.directoryURL = current
        }
        if panel.runModal() == .OK, let selected = panel.url {
            self.destinationDirectory = selected
        }
    }

    public func revealResultInFinder() {
        guard let url = extractionResultURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func showError(_ message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
    }
}
