import Cocoa
import SwiftUI
import RarKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public var appModel: AppModel?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.servicesProvider = self
        NSUpdateDynamicServices()
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first(where: { VolumeResolver.isSupported($0) }) else { return }
        Task { @MainActor in
            self.appModel?.openArchive(url: first)
        }
    }

    public func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        guard let first = urls.first(where: { VolumeResolver.isSupported($0) }) else { return }
        Task { @MainActor in
            self.appModel?.openArchive(url: first)
        }
    }

    // MARK: - NSServices Handlers

    @objc public func extractHere(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return }
        guard let first = urls.first(where: { VolumeResolver.isSupported($0) }) else { return }

        Task { @MainActor in
            guard let model = self.appModel else { return }
            model.openArchive(url: first)
            // Automatically start extraction into the same directory
            model.destinationDirectory = first.deletingLastPathComponent()
            // Wait brief moment for list info then extract
            try? await Task.sleep(nanoseconds: 200_000_000)
            model.extract(selectedOnly: false)
        }
    }

    @objc public func openArchives(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return }
        guard let first = urls.first(where: { VolumeResolver.isSupported($0) }) else { return }

        Task { @MainActor in
            self.appModel?.openArchive(url: first)
        }
    }
}
