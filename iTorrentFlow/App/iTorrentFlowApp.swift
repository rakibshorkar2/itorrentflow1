import SwiftUI

// MARK: - Main App Entry Point
@main
struct iTorrentFlowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var engine = TorrentEngine.shared
    @State private var selectedTab: AppTab = .downloads

    var body: some Scene {
        WindowGroup {
            MainTabView(selectedTab: $selectedTab)
                .environmentObject(engine)
                .preferredColorScheme(.dark)
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

// MARK: - App Tabs
enum AppTab: Hashable {
    case downloads, search, files, settings
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject var engine: TorrentEngine
    @State private var addSheetVisible = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DownloadsView()
                    .tag(AppTab.downloads)

                SearchView()
                    .tag(AppTab.search)

                FileBrowserView()
                    .tag(AppTab.files)

                SettingsView()
                    .tag(AppTab.settings)
            }
            .tabViewStyle(.automatic)

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab, onAddTap: { addSheetVisible = true })
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $addSheetVisible) {
            AddTorrentView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TorrentAdded"))) { _ in
            withAnimation(Theme.snappy) { selectedTab = .downloads }
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    var onAddTap: () -> Void

    @Namespace private var animation
    @StateObject private var engine = TorrentEngine.shared

    private struct TabItem {
        let tab: AppTab
        let icon: String
        let activeIcon: String
        let label: String
    }

    private let items: [TabItem] = [
        TabItem(tab: .downloads, icon: "arrow.down.circle", activeIcon: "arrow.down.circle.fill", label: "Downloads"),
        TabItem(tab: .search, icon: "magnifyingglass", activeIcon: "magnifyingglass.circle.fill", label: "Search"),
        TabItem(tab: .files, icon: "folder", activeIcon: "folder.fill", label: "Files"),
        TabItem(tab: .settings, icon: "gearshape", activeIcon: "gearshape.fill", label: "Settings")
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // First two tabs
            ForEach(Array(items.prefix(2)), id: \.tab) { item in
                tabButton(item: item)
            }

            // Center Add Button
            addButton

            // Last two tabs
            ForEach(Array(items.suffix(2)), id: \.tab) { item in
                tabButton(item: item)
            }
        }
        .padding(.horizontal, Theme.spacing8)
        .padding(.top, Theme.spacing12)
        .padding(.bottom, 24) // Safe area
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Theme.surface.opacity(0.8))
                )
                .overlay(
                    Rectangle()
                        .fill(Theme.glassBorder)
                        .frame(height: 0.5),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Tab Button
    @ViewBuilder
    private func tabButton(item: TabItem) -> some View {
        let isSelected = selectedTab == item.tab

        Button {
            withAnimation(Theme.snappy) { selectedTab = item.tab }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 36, height: 30)
                            .matchedGeometryEffect(id: "tabBackground", in: animation)
                    }

                    // Badge for active downloads
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: isSelected ? item.activeIcon : item.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
                            .bounceSymbolEffect(value: isSelected)

                        if item.tab == .downloads && engine.activeTorrents > 0 {
                            Text("\(engine.activeTorrents)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 14, minHeight: 14)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -6)
                        }
                    }
                }

                Text(item.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Center Add Button
    private var addButton: some View {
        Button(action: onAddTap) {
            ZStack {
                Circle()
                    .fill(Theme.accentGradient)
                    .frame(width: 52, height: 52)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 12, x: 0, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
            }
            .offset(y: -12)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}
