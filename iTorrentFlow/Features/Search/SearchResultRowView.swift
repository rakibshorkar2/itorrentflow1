import SwiftUI

// MARK: - Search Result Row View
public struct SearchResultRowView: View {
    let result: TorrentSearchResult
    var onTap: () -> Void
    @State private var isAdded = false
    @State private var isPressed = false

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.spacing12) {
                // Category icon
                categoryIcon

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(Theme.headlineFont(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: Theme.spacing8) {
                        // Size
                        Label(result.formattedSize, systemImage: "externaldrive.fill")
                            .font(Theme.captionFont(size: 11))
                            .foregroundStyle(Theme.textTertiary)

                        // Date
                        if !result.uploadDate.isEmpty {
                            Text(result.uploadDate)
                                .font(Theme.captionFont(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        // Provider
                        Text(result.providerName)
                            .font(Theme.captionFont(size: 10))
                            .foregroundStyle(Theme.accentSecondary.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.accentSecondary.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    // Health bar
                    TorrentHealthView(seeders: result.seeders, leechers: result.leechers)
                }

                Spacer(minLength: 4)

                // Download button
                downloadButton
            }
            .padding(Theme.spacing12)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .fill(Theme.surfaceElevated.opacity(isPressed ? 0.8 : 1.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusLarge)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(Theme.snappy, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    // MARK: - Category Icon
    private var categoryIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(categoryColor.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: categoryIconName)
                .font(.system(size: 20))
                .foregroundStyle(categoryColor)
        }
    }

    // MARK: - Download Button
    private var downloadButton: some View {
        Button {
            guard let magnet = result.magnetLink else { return }
            Task { @MainActor in
                do {
                    let session = try TorrentEngine.shared.addTorrent(magnetURL: magnet)
                    if SettingsManager.shared.startOnAdd { session.start() }
                    withAnimation(Theme.bounce) { isAdded = true }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    isAdded = false
                } catch {
                    print("Failed to add: \(error)")
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isAdded ? Theme.accentTertiary.opacity(0.2) : Theme.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: isAdded ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isAdded ? Theme.accentTertiary : Theme.accent)
                    .bounceSymbolEffect(value: isAdded)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var categoryColor: Color {
        switch result.category.lowercased() {
        case let c where c.contains("video") || c.contains("movie"): return .blue
        case let c where c.contains("audio") || c.contains("music"): return .purple
        case let c where c.contains("game"): return .orange
        case let c where c.contains("software") || c.contains("app"): return .mint
        case let c where c.contains("book"): return .brown
        default: return Theme.accent
        }
    }

    private var categoryIconName: String {
        switch result.category.lowercased() {
        case let c where c.contains("video") || c.contains("movie"): return "film.fill"
        case let c where c.contains("audio") || c.contains("music"): return "music.note"
        case let c where c.contains("game"): return "gamecontroller.fill"
        case let c where c.contains("software") || c.contains("app"): return "app.fill"
        case let c where c.contains("book"): return "book.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Search Result Detail Sheet
public struct SearchResultDetailView: View {
    let result: TorrentSearchResult
    @Environment(\.dismiss) private var dismiss
    @State private var didAdd = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: Theme.spacing20) {
                    // Hero
                    VStack(spacing: Theme.spacing12) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.accentGradient)
                        Text(result.name)
                            .font(Theme.headlineFont())
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Theme.spacing20)

                    // Stats Grid
                    HStack(spacing: Theme.spacing12) {
                        StatCard(label: "Size", value: result.formattedSize, icon: "externaldrive.fill", color: Theme.accent)
                        StatCard(label: "Seeders", value: "\(result.seeders)", icon: "arrow.up", color: .green)
                        StatCard(label: "Leechers", value: "\(result.leechers)", icon: "arrow.down", color: .red)
                    }
                    .padding(.horizontal, Theme.spacing16)

                    // Info
                    VStack(spacing: Theme.spacing8) {
                        InfoRow(label: "Uploader", value: result.uploader.isEmpty ? "Anonymous" : result.uploader)
                        InfoRow(label: "Uploaded", value: result.uploadDate)
                        InfoRow(label: "Category", value: result.category)
                        InfoRow(label: "Source", value: result.providerName)
                    }
                    .cardStyle()
                    .padding(.horizontal, Theme.spacing16)

                    Spacer()

                    // Download button
                    Button {
                        guard let magnet = result.magnetLink else { return }
                        Task { @MainActor in
                            do {
                                let session = try TorrentEngine.shared.addTorrent(magnetURL: magnet)
                                if SettingsManager.shared.startOnAdd { session.start() }
                                didAdd = true
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                dismiss()
                            } catch {}
                        }
                    } label: {
                        Label(didAdd ? "Added!" : "Download", systemImage: didAdd ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(Theme.headlineFont())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(Theme.spacing16)
                            .background(didAdd ? AnyShapeStyle(Theme.accentTertiary) : AnyShapeStyle(Theme.accentGradient))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
                            .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal, Theme.spacing16)
                    .padding(.bottom, Theme.spacing24)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Torrent Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}


