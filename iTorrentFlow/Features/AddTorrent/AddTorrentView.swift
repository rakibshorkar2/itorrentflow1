import SwiftUI

public struct AddTorrentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddTorrentViewModel()
    @FocusState private var isMagnetFocused: Bool

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: Magnet Link
                Section {
                    if viewModel.clipboardHasMagnet && viewModel.magnetText.isEmpty {
                        Button {
                            viewModel.pasteClipboard()
                        } label: {
                            Label("Magnet Link Detected — Tap to paste", systemImage: "doc.on.clipboard")
                                .font(.subheadline)
                                .foregroundStyle(Theme.accent)
                        }
                    }

                    TextField("Paste magnet link, info hash, or URN...", text: $viewModel.magnetText, axis: .vertical)
                        .font(.system(.subheadline, design: .monospaced))
                        .focused($isMagnetFocused)
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: viewModel.magnetText) { _ in
                            viewModel.validateMagnet(viewModel.magnetText)
                        }

                    HStack {
                        if !viewModel.magnetText.isEmpty {
                            Button("Clear", role: .destructive) {
                                viewModel.magnetText = ""
                                viewModel.parsedInfo = nil
                                viewModel.errorMessage = nil
                            }
                            .font(.caption)
                        }
                        Spacer()
                        Button {
                            viewModel.pasteClipboard()
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                                .font(.caption)
                        }
                    }
                } header: {
                    Label("Magnet Link", systemImage: "link")
                }

                // MARK: Or Import
                Section {
                    Button {
                        viewModel.showFilePicker = true
                    } label: {
                        Label("Import .torrent File", systemImage: "doc.badge.plus")
                    }
                } header: {
                    Label("Or Import File", systemImage: "folder")
                }

                // MARK: Torrent Info
                if let info = viewModel.parsedInfo {
                    Section("Torrent Info") {
                        LabeledContent("Name", value: info.name)
                        LabeledContent("Size", value: info.formattedSize)
                        if info.isMagnet {
                            LabeledContent("Trackers", value: "\(info.trackerCount)")
                            LabeledContent("Hash", value: info.infoHash)
                        } else {
                            LabeledContent("Files", value: "\(info.fileCount)")
                            LabeledContent("Pieces", value: "\(info.pieceCount)")
                            LabeledContent("Trackers", value: "\(info.trackerCount)")
                        }
                    }
                }

                // MARK: File Selection
                if !(viewModel.parsedInfo?.isMagnet ?? true), let metadata = viewModel.pendingMetadata {
                    Section("Select Files to Download") {
                        ForEach(metadata.files) { file in
                            FilePriorityRow(
                                file: file,
                                priority: viewModel.filePriorities[file.id] ?? file.priority,
                                onChange: { priority in
                                    viewModel.filePriorities[file.id] = priority
                                }
                            )
                        }
                    }
                }

                // MARK: Options
                if viewModel.parsedInfo != nil || viewModel.hasPendingFile {
                    Section("Options") {
                        Toggle("Start Immediately", isOn: $viewModel.startImmediately)
                        Toggle("Sequential Download", isOn: $viewModel.sequentialDownload)
                    }
                }

                // MARK: Error
                if let error = viewModel.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // MARK: Start Button
                if viewModel.parsedInfo != nil || viewModel.magnetText.count > 20 || viewModel.hasPendingFile {
                    Section {
                        Button {
                            viewModel.startDownload()
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Start Download")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                        }
                        .disabled(viewModel.isLoading)
                        .listRowBackground(Theme.accent)
                        .foregroundStyle(.white)
                    }
                }
            }
            .navigationTitle("Add Torrent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
    var pendingMetadata: TorrentMetadata? {
        didSet {
            if let meta = pendingMetadata {
                filePriorities = Dictionary(uniqueKeysWithValues: meta.files.map { ($0.id, $0.priority) })
            }
        }
    }
    @Published var filePriorities: [UUID: FilePriority] = [:]

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
        if text.lowercased().contains("magnet:?") {
            if let range = text.range(of: "magnet:\\?.*?(?=$|\\s)", options: [.regularExpression, .caseInsensitive]) {
                return String(text[range])
            }
        }
        if let range = text.range(of: "[0-9a-fA-F]{40}", options: .regularExpression) {
            return String(text[range])
        }
        if let range = text.range(of: "[A-Za-z2-7]{32}", options: .regularExpression) {
            return String(text[range])
        }
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
        } catch {}
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
                pendingMetadata = metadata
                parsedInfo = ParsedTorrentInfo(
                    name: metadata.name,
                    formattedSize: ByteCountFormatter.string(fromByteCount: metadata.totalSize, countStyle: .file),
                    fileCount: max(metadata.files.count, 1),
                    pieceCount: metadata.pieces.count,
                    trackerCount: metadata.trackerURLs.count,
                    infoHash: String(metadata.infoHashHex.prefix(16)) + "...",
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
                    for (fileID, priority) in filePriorities {
                        await session.setFilePriority(fileID: fileID, priority: priority)
                    }
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

public struct ParsedTorrentInfo {
    let name: String
    let formattedSize: String
    let fileCount: Int
    let pieceCount: Int
    let trackerCount: Int
    let infoHash: String
    let isMagnet: Bool
}
