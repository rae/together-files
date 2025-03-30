//
//  Files.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import SwiftUI
import UniformTypeIdentifiers

/// Main entry point for the Files package
public struct Files {
    /// Returns a view for browsing and selecting files
    /// - Parameters:
    ///   - onSelectFile: Callback for when a file is selected
    ///   - onAddToPlaylist: Callback for when a file is added to the playlist
    ///   - allowMultipleSelection: Whether to allow selecting multiple files
    ///   - contentTypes: Content types to filter by
    /// - Returns: A view for browsing and selecting files
    public static func fileSelectionView(
        onSelectFile: ((FileItem) async -> Void)? = nil,
        onAddToPlaylist: ((FileItem) -> Void)? = nil,
        allowMultipleSelection: Bool = false,
        contentTypes: [UTType]? = nil
    ) -> some View {
        let viewModel = FileProviderViewModel()
        
        if let contentTypes = contentTypes {
            Task {
                await viewModel.setContentTypeFilter(contentTypes)
            }
        }
        
        return FileSelectionView(
            viewModel: viewModel,
            onSelectFile: onSelectFile,
            onAddToPlaylist: onAddToPlaylist,
            allowMultipleSelection: allowMultipleSelection
        )
    }
    
    /// Returns a view for selecting a directory
    /// - Parameter onSelectDirectory: Callback for when a directory is selected
    /// - Returns: A view for browsing and selecting directories
    public static func directorySelectionView(
        onSelectDirectory: ((FileItem) async -> Void)? = nil
    ) -> some View {
        let viewModel = FileProviderViewModel()
        viewModel.showOnlyFolders = true
        
        return FileSelectionView(
            viewModel: viewModel,
            onSelectFile: onSelectDirectory,
            showOnlyFolders: true
        )
    }
    
    /// Returns a view for displaying the file playlist
    /// - Parameter viewModel: The view model to use
    /// - Returns: A view for displaying and managing the playlist
    public static func playlistView(
        viewModel: FileSelectionViewModel
    ) -> some View {
        PlaylistView(viewModel: viewModel)
    }
    
    /// Creates a new file selection view model
    /// - Returns: A new FileSelectionViewModel instance
    public static func createFileSelectionViewModel() -> FileSelectionViewModel {
        FileSelectionViewModel()
    }
}

/// A view for displaying and managing the playlist
public struct PlaylistView: View {
    // Using the modern @State with @Observable model
    @State var viewModel: FileSelectionViewModel
    
    // For iOS/tvOS/visionOS, we'll use EditMode
    #if os(iOS) || os(tvOS) || os(visionOS)
    @State private var editMode: EditMode = .inactive
    #else
    // For macOS, we'll use a simple boolean
    @State private var isEditing: Bool = false
    #endif
    
    public var body: some View {
        List {
            if viewModel.selectedFiles.isEmpty {
                ContentUnavailableView {
                    Label("No Files", systemImage: "play.slash")
                } description: {
                    Text("Your playlist is empty. Add files to get started.")
                } actions: {
                    NavigationLink(destination: Files.fileSelectionView(
                        onSelectFile: { file in
                            viewModel.addToPlaylist(file)
                        },
                        onAddToPlaylist: { file in
                            viewModel.addToPlaylist(file)
                        },
                        allowMultipleSelection: true,
                        contentTypes: viewModel.supportedContentTypes
                    )) {
                        Text("Browse Files")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Platform-specific way to enable list editing
                #if os(iOS) || os(tvOS) || os(visionOS)
                playlistContent
                    .environment(\.editMode, $editMode)
                #else
                playlistContent
                    .moveDisabled(!isEditing)
                #endif
                
                Section {
                    Button(action: {
                        viewModel.clearPlaylist()
                    }) {
                        HStack {
                            Spacer()
                            Text("Clear Playlist")
                                .foregroundColor(FilesColor.red.color)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Playlist")
        .toolbar {
            // Cross-platform toolbar items
            ToolbarItem {
                NavigationLink(destination: Files.fileSelectionView(
                    onSelectFile: { file in
                        viewModel.addToPlaylist(file)
                    },
                    onAddToPlaylist: { file in
                        viewModel.addToPlaylist(file)
                    },
                    allowMultipleSelection: true,
                    contentTypes: viewModel.supportedContentTypes
                )) {
                    Image(systemName: "plus")
                }
            }
            
            // Platform-specific edit button
            #if os(iOS) || os(tvOS) || os(visionOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .disabled(viewModel.selectedFiles.isEmpty)
            }
            #else
            ToolbarItem {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .disabled(viewModel.selectedFiles.isEmpty)
            }
            #endif
        }
    }
    
    // Extract playlist content to avoid duplication
    private var playlistContent: some View {
        ForEach(viewModel.selectedFiles) { file in
            HStack {
                Image(systemName: file == viewModel.currentPlayingFile ? "play.circle.fill" : "play.circle")
                    .foregroundColor(file == viewModel.currentPlayingFile ? FilesColor.accent.color : FilesColor.secondaryText.color)
                
                VStack(alignment: .leading) {
                    Text(file.name)
                        .font(.body)
                        .lineLimit(1)
                    
                    if let size = file.size {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption)
                            .foregroundColor(FilesColor.secondaryText.color)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.removeFromPlaylist(file)
                }) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(FilesColor.red.color)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.setCurrentPlayingFile(file)
            }
        }
        .onMove { from, to in
            if from.count == 1 && to < viewModel.selectedFiles.count {
                viewModel.movePlaylistItem(fromIndex: from.first!, toIndex: to)
            }
        }
    }
}

#Preview {
    NavigationStack {
        Files.playlistView(viewModel: FileSelectionViewModel())
    }
}
