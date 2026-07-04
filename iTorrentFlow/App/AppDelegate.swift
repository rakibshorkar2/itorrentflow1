import UIKit
import BackgroundTasks

// MARK: - App Delegate
/// Handles lifecycle events, background task registration, and URL/file opening
public final class AppDelegate: NSObject, UIApplicationDelegate {

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register background tasks BEFORE the app finishes launching
        TorrentEngine.shared.registerBackgroundTasks()
        return true
    }

    // MARK: - Background Task Scheduling
    public func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background processing when app goes to background
        TorrentEngine.shared.scheduleBackgroundTasks()
    }

    public func applicationWillResignActive(_ application: UIApplication) {
        // Pause non-critical UI updates
    }

    public func applicationWillEnterForeground(_ application: UIApplication) {
        // Refresh UI immediately
    }

    public func applicationWillTerminate(_ application: UIApplication) {
        // End all Live Activities and save state before termination
        TorrentEngine.shared.sessions.forEach { $0.endLiveActivity() }
        TorrentEngine.shared.pauseAll()
    }

    // MARK: - Open URL (Magnet Links)
    /// Called when the app is opened via a magnet: URL
    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if url.scheme?.lowercased() == "magnet" {
            handleMagnetURL(url)
            return true
        }
        // .torrent file opened from another app
        if url.pathExtension.lowercased() == "torrent" {
            handleTorrentFile(url)
            return true
        }
        return false
    }

    // MARK: - Document Picker
    public func application(
        _ application: UIApplication,
        open urls: [URL],
        sourceApplication: String?,
        annotation: Any
    ) -> Bool {
        for url in urls {
            if url.scheme?.lowercased() == "magnet" {
                handleMagnetURL(url)
            } else if url.pathExtension.lowercased() == "torrent" {
                handleTorrentFile(url)
            }
        }
        return true
    }

    // MARK: - Handlers
    private func handleMagnetURL(_ url: URL) {
        Task { @MainActor in
            do {
                let session = try TorrentEngine.shared.addTorrent(magnetURL: url.absoluteString)
                if SettingsManager.shared.startOnAdd {
                    session.start()
                }
                postNotification(name: "TorrentAdded", info: ["name": session.metadata.name])
            } catch {
                print("Failed to handle magnet URL: \(error)")
            }
        }
    }

    private func handleTorrentFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        Task { @MainActor in
            do {
                let session = try TorrentEngine.shared.addTorrent(from: url)
                if SettingsManager.shared.startOnAdd {
                    session.start()
                }
                postNotification(name: "TorrentAdded", info: ["name": session.metadata.name])
            } catch {
                print("Failed to handle torrent file: \(error)")
            }
        }
    }

    private func postNotification(name: String, info: [String: Any]) {
        NotificationCenter.default.post(
            name: NSNotification.Name(name),
            object: nil,
            userInfo: info
        )
    }
}
