import SwiftUI

struct FileRowView: View {
    let item: FileItem
    let allowMultipleSelection: Bool
    let onSelect: () -> Void
    let onAddToPlaylist: (() -> Void)?
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: iconName(for: item))
                    .font(.title2)
                    .foregroundColor(iconColor(for: item))
                
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                    
                    if !item.isDirectory {
                        Text(item.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !item.isDirectory && allowMultipleSelection {
                    Button(action: {
                        onAddToPlaylist?()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func iconName(for item: FileItem) -> String {
        if item.isDirectory {
            return "folder"
        } else if item.isVideo {
            return "video"
        } else if item.isAudio {
            return "music.note"
        } else if item.isImage {
            return "photo"
        } else {
            return "doc"
        }
    }
    
    private func iconColor(for item: FileItem) -> Color {
        if item.isDirectory {
            return .blue
        } else if item.isVideo {
            return .red
        } else if item.isAudio {
            return .purple
        } else if item.isImage {
            return .green
        } else {
            return .gray
        }
    }
} 