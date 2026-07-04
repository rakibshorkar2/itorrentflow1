import SwiftUI

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
        ForEach(files) { file in
            FilePriorityRow(
                file: file,
                priority: filePriorityMap[file.id] ?? file.priority,
                onChange: { onPriorityChange(file.id, $0) }
            )
        }
    }
}

struct FilePriorityRow: View {
    let file: TorrentFileEntry
    let priority: FilePriority
    let onChange: (FilePriority) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: file.name))
                .font(.title3)
                .foregroundStyle(priority == .skip ? .tertiary : .primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .foregroundStyle(priority == .skip ? .tertiary : .primary)
                    .lineLimit(2)
                    .strikethrough(priority == .skip)
                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
                        .font(.caption)
                    Image(systemName: priorityIcon)
                        .font(.caption2)
                }
                .foregroundStyle(priorityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(priorityColor.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
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
        case .skip: return Color(.tertiaryLabel)
        case .low: return Color(.secondaryLabel)
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
