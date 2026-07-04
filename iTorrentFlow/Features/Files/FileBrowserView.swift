import SwiftUI

// MARK: - Files Browser View
public struct FileBrowserView: View {
    @StateObject private var viewModel = FileBrowserViewModel()

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                if viewModel.completedTorrents.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.spacing8) {
                            ForEach(viewModel.completedTorrents, id: \.name) { torrent in
                                TorrentFolderRow(torrent: torrent, viewModel: viewModel)
                            }
                        }
                        .padding(.horizontal, Theme.spacing16)
                        .padding(.top, Theme.spacing12)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    storageInfo
                }
            }
            .onAppear { viewModel.refresh() }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Theme.spacing20) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.accent.opacity(0.7), Theme.accentSecondary.opacity(0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("No Downloaded Files")
                .font(Theme.titleFont(size: 22))
                .foregroundStyle(Theme.textPrimary)
            Text("Completed torrents will appear here.\nFiles are stored in the app's Documents folder.")
                .font(Theme.bodyFont())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Theme.spacing24)
    }

    // MARK: - Storage Info
    private var storageInfo: some View {
        HStack(spacing: Theme.spacing8) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(viewModel.formattedUsedStorage)
                    .font(Theme.captionFont(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                Text("used")
                    .font(Theme.captionFont(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
            VStack(alignment: .trailing, spacing: 1) {
                Text(viewModel.formattedFreeStorage)
                    .font(Theme.captionFont(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                Text("free")
                    .font(Theme.captionFont(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

// MARK: - Torrent Folder Row
struct TorrentFolderRow: View {
    let torrent: TorrentFolder
    @ObservedObject var viewModel: FileBrowserViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Folder header
            Button {
                withAnimation(Theme.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Theme.spacing12) {
                    Image(systemName: isExpanded ? "folder.fill.badge.minus" : "folder.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(torrent.name)
                            .font(Theme.headlineFont(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: Theme.spacing8) {
                            Text("\(torrent.files.count) files")
                                .font(Theme.captionFont(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                            Text("•")
                                .foregroundStyle(Theme.textTertiary)
                            Text(ByteCountFormatter.string(fromByteCount: torrent.totalSize, countStyle: .file))
                                .font(Theme.captionFont(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(Theme.snappy, value: isExpanded)
                }
                .padding(Theme.spacing12)
            }
            .buttonStyle(PlainButtonStyle())

            // Files list
            if isExpanded {
                Divider().background(Theme.divider)

                ForEach(torrent.files) { file in
                    FileRow(file: file, folderName: torrent.name, viewModel: viewModel)

                    if file.id != torrent.files.last?.id {
                        Divider()
                            .background(Theme.divider)
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .glassMorphism(cornerRadius: Theme.radiusLarge)
    }
}

// MARK: - File Row
struct FileRow: View {
    let file: BrowsableFile
    let folderName: String
    @ObservedObject var viewModel: FileBrowserViewModel
    @State private var showShareSheet = false

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            Image(systemName: fileIcon)
                .font(.system(size: 20))
                .foregroundStyle(fileColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text(file.formattedSize)
                    .font(Theme.captionFont(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: Theme.spacing8) {
                Button {
                    viewModel.openInFiles(file: file, folderName: folderName)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accent)
                }

                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, Theme.spacing12)
        .padding(.vertical, Theme.spacing10)
        .sheet(isPresented: $showShareSheet) {
            if let url = viewModel.fileURL(for: file, folderName: folderName) {
                ShareSheet(urls: [url])
            }
        }
    }

    private var fileIcon: String {
        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "m4v": return "film.fill"
        case "mp3", "flac", "m4a", "aac", "wav", "ogg": return "music.note"
        case "jpg", "jpeg", "png", "gif", "webp", "heic": return "photo.fill"
        case "pdf": return "doc.richtext.fill"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox.fill"
        case "dmg", "exe", "pkg", "apk": return "app.badge.checkmark.fill"
        case "epub", "mobi", "azw": return "book.fill"
        case "doc", "docx", "txt", "pages": return "doc.text.fill"
        case "xls", "xlsx", "csv", "numbers": return "tablecells.fill"
        case "iso": return "opticaldisc.fill"
        default: return "doc.fill"
        }
    }

    private var fileColor: Color {
        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "m4v": return .blue
        case "mp3", "flac", "m4a", "aac", "wav": return .purple
        case "jpg", "jpeg", "png", "gif", "webp": return .orange
        case "pdf": return .red
        case "zip", "rar", "7z": return .yellow
        case "epub", "mobi": return .brown
        case "iso": return .gray
        default: return Theme.accent
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - File Browser ViewModel
@MainActor
public final class FileBrowserViewModel: ObservableObject {
    @Published var completedTorrents: [TorrentFolder] = []
    @Published var usedStorage: Int64 = 0

    private let documentsDir: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads")
    }()

    public init() { refresh() }

    public func refresh() {
        var folders: [TorrentFolder] = []
        var totalSize: Int64 = 0

        guard let items = try? FileManager.default.contentsOfDirectory(
            at: documentsDir,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return }

        for item in items {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                var files: [BrowsableFile] = []
                if let subItems = try? FileManager.default.contentsOfDirectory(
                    at: item, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles
                ) {
                    for sub in subItems {
                        let size = (try? sub.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                        files.append(BrowsableFile(
                            id: UUID(),
                            name: sub.lastPathComponent,
                            size: Int64(size),
                            relativePath: sub.lastPathComponent
                        ))
                    }
                }
                let folderSize = files.reduce(0) { $0 + $1.size }
                totalSize += folderSize
                folders.append(TorrentFolder(name: item.lastPathComponent, files: files, totalSize: folderSize))
            } else {
                let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                totalSize += Int64(size)
                let file = BrowsableFile(id: UUID(), name: item.lastPathComponent, size: Int64(size), relativePath: item.lastPathComponent)
                folders.append(TorrentFolder(name: item.lastPathComponent, files: [file], totalSize: Int64(size)))
            }
        }

        completedTorrents = folders.sorted { $0.name < $1.name }
        usedStorage = totalSize
    }

    public var formattedUsedStorage: String {
        ByteCountFormatter.string(fromByteCount: usedStorage, countStyle: .file)
    }

    public var formattedFreeStorage: String {
        let free: Int64
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeBytes = attrs[.systemFreeSize] as? NSNumber {
            free = freeBytes.int64Value
        } else {
            free = 0
        }
        return ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
    }

    public func openInFiles(file: BrowsableFile, folderName: String) {
        guard let url = fileURL(for: file, folderName: folderName) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }

    public func fileURL(for file: BrowsableFile, folderName: String) -> URL? {
        let url = documentsDir.appendingPathComponent(folderName).appendingPathComponent(file.relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

// MARK: - Models
public struct TorrentFolder {
    public let name: String
    public let files: [BrowsableFile]
    public let totalSize: Int64
}

public struct BrowsableFile: Identifiable {
    public let id: UUID
    public let name: String
    public let size: Int64
    public let relativePath: String

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - spacing helper
private extension Theme {
    static let spacing10: CGFloat = 10
}
