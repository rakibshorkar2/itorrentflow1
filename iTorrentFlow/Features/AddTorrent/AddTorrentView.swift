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

                        // Clipboard banner
                        if viewModel.clipboardHasMagnet && viewModel.magnetText.isEmpty {
                            clipboardBanner
                        }

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
                        if viewModel.parsedInfo != nil || viewModel.magnetText.count > 20 || viewModel.hasPendingFile {
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
            .onChange(of: viewModel.didStart) { started in
                if started { dismiss() }
            }
            .onAppear {
                viewModel.checkClipboard()
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

    // MARK: - Clipboard Banner
    private var clipboardBanner: some View {
        Button {
            viewModel.pasteClipboard()
        } label: {
            HStack(spacing: Theme.spacing12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.accent.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Magnet Link Detected")
                        .font(Theme.captionFont(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tap to paste from clipboard")
                        .font(Theme.captionFont(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 20))
            }
            .padding(Theme.spacing12)
            .background(Theme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Magnet Section
    private var magnetSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Label("Magnet Link", systemImage: "link")
                .font(Theme.captionFont())
                .foregroundStyle(Theme.textTertiary)

            ZStack(alignment: .topLeading) {
                if viewModel.magnetText.isEmpty {
                    Text("Paste magnet link, info hash, or URN...")
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
                    .frame(minHeight: 72, maxHeight: 100)
                    .onChange(of: viewModel.magnetText) { newText in
                        viewModel.validateMagnet(newText)
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(
                        viewModel.parsedInfo != nil ? Color.green.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
            .padding(Theme.spacing12)
            .glassMorphism(cornerRadius: Theme.radiusMedium)

            // Paste button with clipboard indicator
            HStack {
                if !viewModel.magnetText.isEmpty {
                    Button {
                        viewModel.magnetText = ""
                        viewModel.parsedInfo = nil
                        viewModel.errorMessage = nil
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .font(Theme.captionFont(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer()
                Button {
                    viewModel.pasteClipboard()
                } label: {
                    Label(
                        viewModel.clipboardHasMagnet ? "Paste Magnet" : "Paste",
                        systemImage: "doc.on.clipboard"
                    )
                    .font(Theme.captionFont(size: 12))
                    .foregroundStyle(viewModel.clipboardHasMagnet ? Theme.accent : Theme.textTertiary)
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
                    if info.isMagnet {
                        InfoRow(label: "Trackers", value: "\(info.trackerCount)")
                        InfoRow(label: "Hash", value: info.infoHash)
                    } else {
                        InfoRow(label: "Files", value: "\(info.fileCount)")
                        InfoRow(label: "Pieces", value: "\(info.pieceCount)")
                        InfoRow(label: "Trackers", value: "\(info.trackerCount)")
                    }
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

    @Published var clipboardHasMagnet: Bool = false
    @Published var clipboardMagnet: String? = nil

    private var pendingTorrentData: Data?
    var hasPendingFile: Bool { pendingTorrentData != nil }

    func checkClipboard() {
        guard let clipboard = UIPasteboard.general.string, !clipboard.isEmpty else {
            clipboardHasMagnet = false
            clipboardMagnet = nil
            return
        }
        if let magnet = extractMagnet(from: clipboard) {
            clipboardMagnet = magnet
            clipboardHasMagnet = true
        } else {
            clipboardHasMagnet = false
            clipboardMagnet = nil
        }
    }

    func pasteClipboard() {
        guard let magnet = clipboardMagnet else {
            if let clipboard = UIPasteboard.general.string {
                magnetText = clipboard
                validateMagnet(clipboard)
            }
            return
        }
        magnetText = magnet
        clipboardHasMagnet = false
        clipboardMagnet = nil
        validateMagnet(magnet)
    }

    private func extractMagnet(from text: String) -> String? {
        // Try full magnet link
        if text.lowercased().contains("magnet:?") {
            if let range = text.range(of: "magnet:\\?.*?(?=$|\\s)", options: [.regularExpression, .caseInsensitive]) {
                return String(text[range])
            }
        }
        // Try bare info hash (40 hex chars)
        if let range = text.range(of: "[0-9a-fA-F]{40}", options: .regularExpression) {
            return String(text[range])
        }
        // Try base32 (32 chars)
        if let range = text.range(of: "[A-Za-z2-7]{32}", options: .regularExpression) {
            return String(text[range])
        }
        // Try URN
        if text.lowercased().contains("urn:btih:") {
            if let range = text.range(of: "urn:btih:[0-9a-fA-F]{40}", options: [.regularExpression, .caseInsensitive]) {
                return String(text[range])
            }
        }
        return nil
    }

    func validateMagnet(_ text: String) {
        errorMessage = nil
        parsedInfo = nil
        guard !text.isEmpty else { return }
        do {
            let magnet = try MagnetLink.parse(from: text)
            if magnet.displayName != nil || !magnet.trackers.isEmpty || magnet.exactLength != nil {
                parsedInfo = ParsedTorrentInfo(
                    name: magnet.displayName ?? "Unknown Torrent",
                    formattedSize: magnet.exactLength.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Unknown",
                    fileCount: 0,
                    pieceCount: 0,
                    trackerCount: magnet.trackers.count,
                    infoHash: magnet.shortHash,
                    isMagnet: true
                )
            } else {
                // Minimal magnet (just hash) — still show it but mark as minimal
                parsedInfo = ParsedTorrentInfo(
                    name: "Magnet Link",
                    formattedSize: "Unknown",
                    fileCount: 0,
                    pieceCount: 0,
                    trackerCount: magnet.trackers.count,
                    infoHash: magnet.shortHash,
                    isMagnet: true
                )
            }
        } catch let error as MagnetError {
            errorMessage = error.localizedDescription
        } catch {
            // Unknown error — ignore during typing
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
                pendingTorrentData = data
                parsedInfo = ParsedTorrentInfo(
                    name: metadata.name,
                    formattedSize: ByteCountFormatter.string(fromByteCount: metadata.totalSize, countStyle: .file),
                    fileCount: max(metadata.files.count, 1),
                    pieceCount: metadata.pieces.count,
                    trackerCount: metadata.trackerURLs.count,
                    infoHash: metadata.infoHashHex.prefix(16) + "...",
                    isMagnet: false
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func startDownload() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                if let data = pendingTorrentData {
                    let session = try TorrentEngine.shared.addTorrent(data: data)
                    session.isSequential = sequentialDownload
                    if startImmediately { session.start() }
                } else {
                    let text = magnetText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else {
                        errorMessage = "Enter a magnet link or select a .torrent file"
                        isLoading = false
                        return
                    }
                    let session = try TorrentEngine.shared.addTorrent(magnetURL: text)
                    session.isSequential = sequentialDownload
                    if startImmediately { session.start() }
                }
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
    let trackerCount: Int
    let infoHash: String
    let isMagnet: Bool
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
