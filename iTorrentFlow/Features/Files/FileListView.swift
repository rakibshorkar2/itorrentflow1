import SwiftUI

// MARK: - File List View with Priority Controls
public struct FileListView: View {
    let files: [TorrentFileEntry]
    let filePriorityMap: [UUID: FilePriority]
    let onPriorityChange: (UUID, FilePriority) -> Void

    public init(
        files: [TorrentFileEntry],
        filePriorityMap: [UUID: FilePriority] = [:],
        onPriorityChange: @escaping (UUID, FilePriority) -> Void = { _, _ in }
    ) {
        self.files = files
        self.filePriorityMap = filePriorityMap
        self.onPriorityChange = onPriorityChange
    }

    public var body: some View {
        VStack(spacing: Theme.spacing8) {
            ForEach(files) { file in
                FilePriorityRow(
                    file: file,
                    priority: filePriorityMap[file.id] ?? file.priority,
                    onChange: { onPriorityChange(file.id, $0) }
                )
            }
        }
    }
}

// MARK: - File Priority Row
struct FilePriorityRow: View {
    let file: TorrentFileEntry
    let priority: FilePriority
    let onChange: (FilePriority) -> Void

    var body: some View {
        HStack(spacing: Theme.spacing12) {
            Image(systemName: iconName(for: file.name))
                .font(.system(size: 18))
                .foregroundStyle(priority == .skip ? Theme.textTertiary : Theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundStyle(priority == .skip ? Theme.textTertiary : Theme.textPrimary)
                    .lineLimit(2)
                    .strikethrough(priority == .skip)
                Text(file.formattedSize)
                    .font(Theme.captionFont(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            Menu {
                ForEach(FilePriority.allCases, id: \.self) { p in
                    Button {
                        onChange(p)
                    } label: {
                        HStack {
                            Text(p.label)
                            if p == priority { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(priority.label)
                        .font(Theme.captionFont(size: 11))
                    Image(systemName: priorityIcon)
                        .font(.system(size: 10))
                }
                .foregroundStyle(priorityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(priorityColor.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(Theme.spacing8)
        .glassMorphism(cornerRadius: Theme.radiusMedium)
    }

    private var priorityIcon: String {
        switch priority {
        case .skip: return "slash.circle"
        case .low: return "arrow.down.circle"
        case .normal: return "circle"
        case .high: return "arrow.up.circle"
        }
    }

    private var priorityColor: Color {
        switch priority {
        case .skip: return Theme.textTertiary
        case .low: return Theme.textSecondary
        case .normal: return Theme.accent
        case .high: return Theme.accentSecondary
        }
    }

    private func iconName(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov": return "film.fill"
        case "mp3", "flac", "m4a", "aac": return "music.note"
        case "jpg", "jpeg", "png", "gif", "webp": return "photo.fill"
        case "pdf": return "doc.richtext.fill"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox.fill"
        default: return "doc.fill"
        }
    }
}
