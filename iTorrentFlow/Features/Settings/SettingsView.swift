import SwiftUI

// MARK: - Settings View
public struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var showResetAlert = false
    @State private var showAboutSheet = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                List {
                    // MARK: Download
                    Section {
                        SpeedLimitRow(
                            label: "Max Download Speed",
                            icon: "arrow.down.circle.fill",
                            color: Theme.downloadColor,
                            value: $settings.maxDownloadSpeed,
                            unit: "KB/s"
                        )
                        SpeedLimitRow(
                            label: "Max Upload Speed",
                            icon: "arrow.up.circle.fill",
                            color: Theme.uploadColor,
                            value: $settings.maxUploadSpeed,
                            unit: "KB/s"
                        )
                        SettingsRow(label: "Max Active Torrents", icon: "square.stack.fill", color: Theme.accentSecondary) {
                            Stepper("\(settings.maxActiveTorrents)", value: $settings.maxActiveTorrents, in: 1...20)
                                .foregroundStyle(Theme.textPrimary)
                                .font(Theme.bodyFont(size: 14))
                        }
                        SettingsRow(label: "Max Connections", icon: "point.3.connected.trianglepath.dotted", color: Theme.accent) {
                            Stepper("\(settings.maxConnections)", value: $settings.maxConnections, in: 10...1000, step: 10)
                                .foregroundStyle(Theme.textPrimary)
                                .font(Theme.bodyFont(size: 14))
                        }
                    } header: {
                        SectionHeader(label: "Download", icon: "arrow.down.circle.fill")
                    }
                    .listRowBackground(Theme.surfaceElevated)

                    // MARK: Network
                    Section {
                        ToggleRow(label: "DHT", icon: "network", color: .blue, binding: $settings.enableDHT,
                                  description: "Trackerless peer discovery")
                        ToggleRow(label: "PEX", icon: "arrow.triangle.swap", color: .purple, binding: $settings.enablePEX,
                                  description: "Peer Exchange")
                        ToggleRow(label: "Local Peer Discovery", icon: "wifi", color: .green, binding: $settings.enableLSD,
                                  description: "Find peers on your network")
                        ToggleRow(label: "µTP", icon: "tortoise.fill", color: .orange, binding: $settings.enableUTP,
                                  description: "Congestion-friendly transport")
                        SettingsRow(label: "Listen Port", icon: "antenna.radiowaves.left.and.right", color: Theme.accent) {
                            Text("\(settings.listenPort)")
                                .foregroundStyle(Theme.textSecondary)
                                .font(Theme.monoFont(size: 13))
                        }
                    } header: {
                        SectionHeader(label: "Network & Protocols", icon: "network")
                    }
                    .listRowBackground(Theme.surfaceElevated)

                    // MARK: Behavior
                    Section {
                        ToggleRow(label: "Start on Add", icon: "play.circle.fill", color: Theme.accent, binding: $settings.startOnAdd,
                                  description: "Begin downloading immediately")
                        ToggleRow(label: "Sequential Download", icon: "list.number", color: .purple, binding: $settings.sequentialDownload,
                                  description: "Download pieces in order")
                        ToggleRow(label: "Dynamic Island", icon: "oval.portrait.fill", color: .black, binding: $settings.showDynamicIsland,
                                  description: "Show progress in Dynamic Island")
                        SettingsRow(label: "Default Category", icon: "tag.fill", color: Theme.accentTertiary) {
                            Picker("", selection: $settings.defaultCategory) {
                                ForEach(TorrentCategory.allCases, id: \.self) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.accent)
                        }
                    } header: {
                        SectionHeader(label: "Behavior", icon: "gearshape.2.fill")
                    }
                    .listRowBackground(Theme.surfaceElevated)

                    // MARK: Appearance
                    Section {
                        SettingsRow(label: "Appearance", icon: "sun.max.fill", color: .orange) {
                            Picker("", selection: $settings.colorScheme) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .tint(Theme.accent)
                        }
                    } header: {
                        SectionHeader(label: "Appearance", icon: "sun.max.fill")
                    }
                    .listRowBackground(Theme.surfaceElevated)

                    // MARK: About
                    Section {
                        Button {
                            showAboutSheet = true
                        } label: {
                            SettingsRow(label: "About iTorrentFlow", icon: "info.circle.fill", color: Theme.accentSecondary) {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Theme.textTertiary)
                                    .font(.system(size: 12))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        SettingsRow(label: "Developer", icon: "person.fill", color: Theme.accent) {
                            Text("RAKIB")
                                .foregroundStyle(Theme.textSecondary)
                                .font(Theme.monoFont(size: 13))
                        }

                        Link(destination: URL(string: "https://github.com")!) {
                            SettingsRow(label: "GitHub", icon: "chevron.left.forwardslash.chevron.right", color: Theme.textSecondary.opacity(1)) {
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(Theme.textTertiary)
                                    .font(.system(size: 12))
                            }
                        }

                        Button(role: .destructive) {
                            showResetAlert = true
                        } label: {
                            SettingsRow(label: "Reset Settings", icon: "arrow.counterclockwise", color: .red) {
                                EmptyView()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    } header: {
                        SectionHeader(label: "About", icon: "info.circle.fill")
                    }
                    .listRowBackground(Theme.surfaceElevated)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .alert("Reset Settings", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) { resetSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all settings to their defaults.")
            }
            .sheet(isPresented: $showAboutSheet) {
                AboutView()
            }
        }
    }

    private func resetSettings() {
        settings.maxDownloadSpeed = 0
        settings.maxUploadSpeed = 50
        settings.maxConnections = 200
        settings.maxActiveTorrents = 5
        settings.enableDHT = true
        settings.enablePEX = true
        settings.enableLSD = true
        settings.enableUTP = true
        settings.startOnAdd = true
        settings.sequentialDownload = false
        settings.showDynamicIsland = true
        settings.colorScheme = "dark"
    }
}

// MARK: - Settings Row
struct SettingsRow<Trailing: View>: View {
    let label: String
    let icon: String
    let color: Color
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }

            Text(label)
                .font(Theme.bodyFont(size: 15))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            trailing()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Toggle Row
struct ToggleRow: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var binding: Bool
    var description: String = ""

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.bodyFont(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                if !description.isEmpty {
                    Text(description)
                        .font(Theme.captionFont(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer()

            Toggle("", isOn: $binding)
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Speed Limit Row
struct SpeedLimitRow: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var value: Int
    let unit: String

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.bodyFont(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                Text(value == 0 ? "Unlimited" : "\(value) \(unit)")
                    .font(Theme.captionFont(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            Stepper("", value: $value, in: 0...100000, step: value < 100 ? 10 : (value < 1000 ? 50 : 500))
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let label: String
    let icon: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(Theme.captionFont(size: 12))
            .foregroundStyle(Theme.textTertiary)
            .textCase(nil)
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: Theme.spacing24) {
                    Spacer()

                    // App icon placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Theme.accentGradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: Theme.accent.opacity(0.5), radius: 20, x: 0, y: 8)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.black)
                    }

                    VStack(spacing: Theme.spacing8) {
                        Text("iTorrentFlow")
                            .font(Theme.titleFont(size: 28))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Version 1.0.0")
                            .font(Theme.captionFont())
                            .foregroundStyle(Theme.textTertiary)
                    }

                    VStack(spacing: Theme.spacing8) {
                        Text("A powerful, native iOS torrent client with Dynamic Island live activities, background downloading, and BitTorrent protocol support.")
                            .font(Theme.bodyFont())
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Theme.spacing32)

                    // Feature badges
                    HStack(spacing: Theme.spacing8) {
                        FeatureBadge(icon: "oval.portrait.fill", label: "Dynamic Island")
                        FeatureBadge(icon: "bolt.fill", label: "Background DL")
                        FeatureBadge(icon: "link", label: "Magnet Links")
                    }

                    Spacer()

                    Text("MIT License • Open Source")
                        .font(Theme.captionFont(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.bottom, Theme.spacing24)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

struct FeatureBadge: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(Theme.captionFont(size: 10))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 90)
        .padding(Theme.spacing12)
        .glassMorphism(cornerRadius: Theme.radiusMedium)
    }
}
