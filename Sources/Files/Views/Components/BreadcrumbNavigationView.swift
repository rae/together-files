import SwiftUI

struct BreadcrumbNavigationView: View {
    let directoryPath: [FileItem]
    let currentDirectory: FileItem?
    let onNavigateUp: () async -> Void
    let onNavigateToDirectory: (FileItem) async -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Button(action: {
                    Task {
                        await onNavigateUp()
                    }
                }) {
                    Label("Root", systemImage: "house")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                
                ForEach(directoryPath) { directory in
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(directory.name) {
                        // Do nothing for the last (current) directory
                        if directory.id != currentDirectory?.id {
                            Task {
                                await onNavigateToDirectory(directory)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(directory.id == currentDirectory?.id)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(FilesColor.secondaryBackground.color)
    }
} 