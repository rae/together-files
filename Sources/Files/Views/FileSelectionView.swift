//
//  FileSelectionView.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import SwiftUI
import UniformTypeIdentifiers

/// A view for browsing and selecting files
public struct FileSelectionView: View {
    @State private var viewModel: FileProviderViewModel
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var searchText = ""
    @State private var showSortOptions = false
    @State private var showFilterOptions = false
    @State private var isSearching = false
    
    // Callback for when a file is selected
    private let onSelectFile: ((FileItem) async -> Void)?
    
    // Callback for when a file is added to the playlist
    private let onAddToPlaylist: ((FileItem) -> Void)?
    
    // Flag to enable multiple selection
    private let allowMultipleSelection: Bool
    
    // Flag to only show folders (for directory selection)
    private let showOnlyFolders: Bool
    
    /// Initializes the view
    /// - Parameters:
    ///   - viewModel: The view model to use
    ///   - onSelectFile: Callback for when a file is selected
    ///   - onAddToPlaylist: Callback for when a file is added to the playlist
    ///   - allowMultipleSelection: Whether to allow selecting multiple files
    ///   - showOnlyFolders: Whether to only show folders
    public init(
        viewModel: FileProviderViewModel = FileProviderViewModel(),
        onSelectFile: ((FileItem) async -> Void)? = nil,
        onAddToPlaylist: ((FileItem) -> Void)? = nil,
        allowMultipleSelection: Bool = false,
        showOnlyFolders: Bool = false
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.onSelectFile = onSelectFile
        self.onAddToPlaylist = onAddToPlaylist
        self.allowMultipleSelection = allowMultipleSelection
        self.showOnlyFolders = showOnlyFolders
        
        // Set the view model to only show folders if needed
        viewModel.showOnlyFolders = showOnlyFolders
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb navigation
            if !viewModel.directoryPath.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button(action: {
                            Task {
                                await viewModel.navigateUp()
                            }
                        }) {
                            Label("Root", systemImage: "house")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.bordered)
                        
                        ForEach(viewModel.directoryPath) { directory in
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(directory.name) {
                                // Do nothing for the last (current) directory
                                if directory.id != viewModel.currentDirectory?.id {
                                    Task {
                                        await viewModel.navigateToDirectory(directory)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(directory.id == viewModel.currentDirectory?.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
            }
            
            // File/folder list
            List {
                if viewModel.directoryContents.isEmpty && !isLoading {
                    ContentUnavailableView {
                        Label("No Items", systemImage: "folder")
                    } description: {
                        if !searchText.isEmpty {
                            Text("No files or folders match your search.")
                        } else {
                            Text("This folder is empty.")
                        }
                    }
                } else {
                    ForEach(viewModel.directoryContents) { item in
                        fileRow(for: item)
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.refresh()
            }
            .searchable(text: $searchText, isPresented: $isSearching, prompt: "Search files")
            .onChange(of: searchText) {
                viewModel.searchQuery = searchText
                
                // Debounce the search
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Only perform the search if the text hasn't changed
                    if searchText == viewModel.searchQuery {
                        await viewModel.search()
                    }
                }
            }
            .onChange(of: isSearching) {
                // Clear search when closing the search UI
                if !isSearching && !searchText.isEmpty {
                    searchText = ""
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showSortOptions = true
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    
                    if !showOnlyFolders {
                        Button {
                            showFilterOptions = true
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                    
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    
                    Button {
                        Task {
                            await viewModel.navigateUp()
                        }
                    } label: {
                        Label("Up", systemImage: "arrow.up")
                    }
                    .disabled(viewModel.currentDirectory == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if isLoading || viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground).opacity(0.8)))
                    .shadow(radius: 10)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showSortOptions) {
            sortOptionsView()
        }
        .sheet(isPresented: $showFilterOptions) {
            filterOptionsView()
        }
        .onChange(of: viewModel.lastError) {
            if let error = viewModel.lastError {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .task {
            // Load providers if none are selected
            if viewModel.selectedProvider == nil {
                await viewModel.loadProviders()
            }
        }
    }
    
    /// Creates a row for a file or folder
    /// - Parameter item: The file item to create a row for
    /// - Returns: A view representing the file row
    private func fileRow(for item: FileItem) -> some View {
        Button(action: {
            handleItemSelection(item)
        }) {
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
                        onAddToPlaylist?(item)
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if item.isDirectory {
                Button {
                    Task {
                        await viewModel.navigateToDirectory(item)
                    }
                } label: {
                    Label("Open", systemImage: "folder")
                }
            } else if !showOnlyFolders {
                Button {
                    Task {
                        await handleItemSelection(item)
                    }
                } label: {
                    Label("Open", systemImage: "play.circle")
                }
                
                if allowMultipleSelection {
                    Button {
                        onAddToPlaylist?(item)
                    } label: {
                        Label("Add to Playlist", systemImage: "plus.circle")
                    }
                }
            }
            
            Button {
                shareItem(item)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
    
    /// Handles selection of a file or folder
    /// - Parameter item: The item that was selected
    private func handleItemSelection(_ item: FileItem) {
        Task {
            if item.isDirectory {
                await viewModel.navigateToDirectory(item)
            } else if !showOnlyFolders {
                await onSelectFile?(item)
            }
        }
    }
    
    /// Determines the icon name to use for a file item
    /// - Parameter item: The file item
    /// - Returns: The name of the system icon to use
    private func iconName(for item: FileItem) -> String {
        if item.isDirectory {
            return "folder"
        }
        
        if let contentType = item.contentType {
            if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
                return "play.rectangle"
            }
            if contentType.conforms(to: .audio) {
                return "music.note"
            }
            if contentType.conforms(to: .image) {
                return "photo"
            }
            if contentType.conforms(to: .pdf) {
                return "doc.text"
            }
        }
        
        return "doc"
    }
    
    /// Determines the icon color to use for a file item
    /// - Parameter item: The file item
    /// - Returns: The color to use for the icon
    private func iconColor(for item: FileItem) -> Color {
        if item.isDirectory {
            return .blue
        }
        
        if let contentType = item.contentType {
            if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
                return .purple
            }
            if contentType.conforms(to: .audio) {
                return .pink
            }
            if contentType.conforms(to: .image) {
                return .green
            }
        }
        
        return .gray
    }
    
    /// Shares a file item
    /// - Parameter item: The item to share
    private func shareItem(_ item: FileItem) {
        Task {
            guard let url = await viewModel.getLocalURL(for: item) else {
                errorMessage = "Could not access the file for sharing"
                showError = true
                return
            }
            
            // Share the file using UIActivityViewController
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            // Present the activity view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
    
    /// Creates a view for sorting options
    /// - Returns: A view for the sorting options
    private func sortOptionsView() -> some View {
        NavigationStack {
            List {
                ForEach(FileProviderViewModel.SortOrder.allCases, id: \.rawValue) { sortOrder in
                    Button(action: {
                        viewModel.setSortOrder(sortOrder)
                        showSortOptions = false
                    }) {
                        HStack {
                            Text(sortOrder.rawValue)
                            
                            Spacer()
                            
                            if viewModel.sortOrder == sortOrder {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showSortOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    /// Creates a view for filter options
    /// - Returns: A view for the filter options
    private func filterOptionsView() -> some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        // Clear filters
                        Task {
                            await viewModel.setContentTypeFilter([])
                            showFilterOptions = false
                        }
                    }) {
                        HStack {
                            Text("All Files")
                            
                            Spacer()
                            
                            if viewModel.contentTypeFilter.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section("Media Types") {
                    Button(action: {
                        Task {
                            await viewModel.setContentTypeFilter([.movie, .video])
                            showFilterOptions = false
                        }
                    }) {
                        HStack {
                            Label("Videos", systemImage: "play.rectangle")
                            
                            Spacer()
                            
                            if viewModel.contentTypeFilter == [.movie, .video] {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        Task {
                            await viewModel.setContentTypeFilter([.audio])
                            showFilterOptions = false
                        }
                    }) {
                        HStack {
                            Label("Audio", systemImage: "music.note")
                            
                            Spacer()
                            
                            if viewModel.contentTypeFilter == [.audio] {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        Task {
                            await viewModel.setContentTypeFilter([.audiovisualContent])
                            showFilterOptions = false
                        }
                    }) {
                        HStack {
                            Label("All Media", systemImage: "play.tv")
                            
                            Spacer()
                            
                            if viewModel.contentTypeFilter == [.audiovisualContent] {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFilterOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    /// Gets the navigation title based on the current directory
    private var navigationTitle: String {
        if let currentDirectory = viewModel.currentDirectory {
            return currentDirectory.name
        } else if let selectedProvider = viewModel.selectedProvider {
            return selectedProvider.displayName
        } else {
            return "Files"
        }
    }
}

#Preview {
    NavigationStack {
        FileSelectionView()
    }
}
