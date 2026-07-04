import SwiftUI

public struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var showResetAlert = false
    @State private var showAboutSheet = false

    public var body: some View {
        NavigationStack {
            List {
                downloadSection
                networkSection
                behaviorSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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

    // MARK: - Download
    private var downloadSection: some View {
        Section("Download") {
            SpeedLimitRow(label: "Max Download Speed", value: $settings.maxDownloadSpeed, unit: "KB/s")
            SpeedLimitRow(label: "Max Upload Speed", value: $settings.maxUploadSpeed, unit: "KB/s")
            HStack {
                Label("Max Active Torrents", systemImage: "square.stack.fill")
                    .foregroundStyle(.primary)
                Spacer()
                Stepper("\(settings.maxActiveTorrents)", value: $settings.maxActiveTorrents, in: 1...20)
                    .labelsHidden()
            }
            HStack {
                Label("Max Connections", systemImage: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(.primary)
                Spacer()
                Stepper("\(settings.maxConnections)", value: $settings.maxConnections, in: 10...1000, step: 10)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Network
    private var networkSection: some View {
        Section("Network & Protocols") {
            Toggle(isOn: $settings.enableDHT) {
                Label("DHT", systemImage: "network")
                Text("Trackerless peer discovery")
            }
            Toggle(isOn: $settings.enablePEX) {
                Label("PEX", systemImage: "arrow.triangle.swap")
                Text("Peer Exchange")
            }
            Toggle(isOn: $settings.enableLSD) {
                Label("Local Peer Discovery", systemImage: "wifi")
                Text("Find peers on your network")
            }
            Toggle(isOn: $settings.enableUTP) {
                Label("µTP", systemImage: "tortoise.fill")
                Text("Congestion-friendly transport")
            }
            LabeledContent("Listen Port") {
                Text("\(settings.listenPort)")
                    .foregroundStyle(.secondary)
                    .font(.system(.subheadline, design: .monospaced))
            }
        }
    }

    // MARK: - Behavior
    private var behaviorSection: some View {
        Section("Behavior") {
            Toggle(isOn: $settings.startOnAdd) {
                Label("Start on Add", systemImage: "play.circle.fill")
                Text("Begin downloading immediately")
            }
            Toggle(isOn: $settings.sequentialDownload) {
                Label("Sequential Download", systemImage: "list.number")
                Text("Download pieces in order")
            }
            Toggle(isOn: $settings.showDynamicIsland) {
                Label("Dynamic Island", systemImage: "oval.portrait.fill")
                Text("Show progress in Dynamic Island")
            }
            HStack {
                Label("Default Category", systemImage: "tag.fill")
                    .foregroundStyle(.primary)
                Spacer()
                Picker("Default Category", selection: $settings.defaultCategory) {
                    ForEach(TorrentCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        Section("About") {
            Button {
                showAboutSheet = true
            } label: {
                Label("About iTorrentFlow", systemImage: "info.circle.fill")
                    .foregroundStyle(.primary)
            }
            LabeledContent("Developer") {
                Text("RAKIB")
                    .foregroundStyle(.secondary)
                    .font(.system(.subheadline, design: .monospaced))
            }
            Link(destination: URL(string: "https://github.com")!) {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(.primary)
            }
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label("Reset Settings", systemImage: "arrow.counterclockwise")
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

// MARK: - Speed Limit Row
struct SpeedLimitRow: View {
    let label: String
    @Binding var value: Int
    let unit: String
    var icon: String {
        label.contains("Download") ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 4) {
                Text(value == 0 ? "Unlimited" : "\(value)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .monospacedDigit()
                    .frame(minWidth: 40, alignment: .trailing)
                Stepper("", value: $value, in: 0...100000, step: value < 100 ? 10 : (value < 1000 ? 50 : 500))
                    .labelsHidden()
            }
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 20)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                        Text("iTorrentFlow")
                            .font(.title.weight(.bold))
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("A powerful, native iOS torrent client with Dynamic Island live activities, background downloading, and BitTorrent protocol support.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer().frame(height: 20)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color(.systemGroupedBackground))
                }

                Section {
                    LabeledContent("License") {
                        Text("MIT")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Language") {
                        Text("Swift")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Platform") {
                        Text("iOS 16+")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Info")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
