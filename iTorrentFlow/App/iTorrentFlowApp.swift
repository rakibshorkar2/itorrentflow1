import SwiftUI

@main
struct iTorrentFlowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var engine = TorrentEngine.shared
    @State private var selectedTab: AppTab = .downloads

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                DownloadsView()
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                    .tag(AppTab.downloads)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
            }
            .tint(Theme.accent)
            .environmentObject(engine)
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        Task { @MainActor in
            if url.scheme?.lowercased() == "magnet" {
                do {
                    let session = try TorrentEngine.shared.addTorrent(magnetURL: url.absoluteString)
                    if SettingsManager.shared.startOnAdd { session.start() }
                    selectedTab = .downloads
                } catch {
                    print("Failed to add magnet: \(error)")
                }
            }
        }
    }
}

enum AppTab: Hashable {
    case downloads, settings
}
