import SwiftUI

struct FileSelectionToolbarView: View {
    let showOnlyFolders: Bool
    let canNavigateUp: Bool
    let onSort: () -> Void
    let onFilter: () -> Void
    let onRefresh: () async -> Void
    let onNavigateUp: () async -> Void
    
    var body: some View {
        Menu {
            Button {
                onSort()
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            
            if !showOnlyFolders {
                Button {
                    onFilter()
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            
            Button {
                Task {
                    await onRefresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            
            Button {
                Task {
                    await onNavigateUp()
                }
            } label: {
                Label("Up", systemImage: "arrow.up")
            }
            .disabled(!canNavigateUp)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
} 