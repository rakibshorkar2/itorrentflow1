import SwiftUI

// MARK: - Add Torrent View
public struct AddTorrentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddTorrentViewModel()
    @FocusState private var isMagnetFocused: Bool

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.spacing20) {
                        // Icon
                        headerIcon

                        // Magnet Link Input
                        magnetSection

                        // Or divider
                        orDivider

                        // File picker button
                        filePickerButton

                        // Options (if torrent parsed)
                        if let info = viewModel.parsedInfo {
                            torrentOptionsSection(info: info)
                        }

                        // Error
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error)
                        }

                        // Start button
                        if viewModel.parsedInfo != nil || viewModel.magnetText.count > 20 {
                            startButton
                        }
                    }
                    .padding(Theme.spacing20)
                }
            }
            .navigationTitle("Add Torrent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .fileImporter(
                isPresented: $viewModel.showFilePicker,
                allowedContentTypes: [.init(filenameExtension: "torrent")!],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleFileImport(result: result)
            }
            .onChange(of: viewModel.didStart) { _, started in
                if started { dismiss() }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Header
    private var headerIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.accentGradient)
                .frame(width: 72, height: 72)
                .shadow(color: Theme.accent.opacity(0.4), radius: 20, x: 0, y: 8)
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.black)
        }
        .padding(.top, Theme.spacing8)
    }

    // MARK: - Magnet Section
    private var magnetSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Label("Magnet Link", systemImage: "link")
                .font(Theme.captionFont())
                .foregroundStyle(Theme.textTertiary)

            ZStack(alignment: .topLeading) {
                if viewModel.magnetText.isEmpty {
                    Text("magnet:?xt=urn:btih:...")
                        .font(Theme.monoFont(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 10)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.magnetText)
                    .font(Theme.monoFont(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .scrollContentBackground(.hidden)
                    .focused($isMagnetFocused)
                    .frame(minHeight: 80, maxHeight: 120)
                    .onChange(of: viewModel.magnetText) { _, newText in
                        viewModel.validateMagnet(newText)
                    }
            }
            .padding(Theme.spacing12)
            .glassMorphism(cornerRadius: Theme.radiusMedium)

            // Paste button
            HStack {
                Spacer()
                Button {
                    if let clipboard = UIPasteboard.general.string {
                        viewModel.magnetText = clipboard
                        viewModel.validateMagnet(clipboard)
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(Theme.captionFont(size: 12))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - Or Divider
    private var orDivider: some View {
        HStack(spacing: Theme.spacing12) {
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)
            Text("OR")
                .font(Theme.captionFont(size: 12))
                .foregroundStyle(Theme.textTertiary)
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)
        }
    }

    // MARK: - File Picker
    private var filePickerButton: some View {
        Button {
            viewModel.showFilePicker = true
        } label: {
            HStack(spacing: Theme.spacing12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.accentSecondary.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.accentSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import .torrent File")
                        .font(Theme.headlineFont(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Browse from Files app")
                        .font(Theme.captionFont(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(Theme.spacing16)
            .glassMorphism(cornerRadius: Theme.radiusLarge)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Torrent Options
    private func torrentOptionsSection(info: ParsedTorrentInfo) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing12) {
            Text("Torrent Info")
                .font(Theme.headlineFont())
                .foregroundStyle(Theme.textPrimary)

            GlassCard {
                VStack(spacing: Theme.spacing8) {
                    InfoRow(label: "Name", value: info.name)
                    InfoRow(label: "Size", value: info.formattedSize)
                    InfoRow(label: "Files", value: "\(info.fileCount)")
                    InfoRow(label: "Pieces", value: "\(info.pieceCount)")
                }
            }

            // Options
            VStack(spacing: Theme.spacing12) {
                Toggle("Start Immediately", isOn: $viewModel.startImmediately)
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                    .foregroundStyle(Theme.textPrimary)

                Toggle("Sequential Download", isOn: $viewModel.sequentialDownload)
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                    .foregroundStyle(Theme.textPrimary)
            }
            .cardStyle()
        }
    }

    // MARK: - Start Button
    private var startButton: some View {
        Button {
            viewModel.startDownload()
        } label: {
            HStack(spacing: Theme.spacing8) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(viewModel.isLoading ? "Adding..." : "Start Download")
                    .font(Theme.headlineFont())
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(Theme.spacing16)
            .background(Theme.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .shadow(color: Theme.accent.opacity(0.4), radius: 12, x: 0, y: 4)
        }
        .disabled(viewModel.isLoading)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Torrent ViewModel
@MainActor
public final class AddTorrentViewModel: ObservableObject {
    @Published var magnetText: String = ""
    @Published var parsedInfo: ParsedTorrentInfo? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false
    @Published var showFilePicker: Bool = false
    @Published var startImmediately: Bool = true
    @Published var sequentialDownload: Bool = false
    @Published var didStart: Bool = false

    func validateMagnet(_ text: String) {
        errorMessage = nil
        parsedInfo = nil
        guard text.lowercased().hasPrefix("magnet:?") else { return }
        do {
            let magnet = try MagnetLink.parse(from: text)
            parsedInfo = ParsedTorrentInfo(
                name: magnet.displayName ?? magnet.infoHash,
                formattedSize: magnet.exactLength.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Unknown",
                fileCount: 0,
                pieceCount: 0
            )
        } catch {
            // Don't show error while typing
        }
    }

    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access file"; return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let metadata = try TorrentMetadata.parse(from: data)
                magnetText = metadata.magnetLink
                parsedInfo = ParsedTorrentInfo(
                    name: metadata.name,
                    formattedSize: ByteCountFormatter.string(fromByteCount: metadata.totalSize, countStyle: .file),
                    fileCount: metadata.files.count,
                    pieceCount: metadata.pieces.count
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func startDownload() {
        guard !magnetText.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let session = try TorrentEngine.shared.addTorrent(magnetURL: magnetText)
                session.isSequential = sequentialDownload
                if startImmediately { session.start() }
                didStart = true
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Parsed Info
public struct ParsedTorrentInfo {
    let name: String
    let formattedSize: String
    let fileCount: Int
    let pieceCount: Int
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: Theme.spacing8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(Theme.captionFont(size: 12))
                .foregroundStyle(.red)
                .multilineTextAlignment(.leading)
        }
        .padding(Theme.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}
