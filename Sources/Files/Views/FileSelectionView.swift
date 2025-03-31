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
                BreadcrumbNavigationView(
                    directoryPath: viewModel.directoryPath,
                    currentDirectory: viewModel.currentDirectory,
                    onNavigateUp: {
                        await viewModel.navigateUp()
                    },
                    onNavigateToDirectory: { directory in
                        await viewModel.navigateToDirectory(directory)
                    }
                )
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
                        FileRowView(
                            item: item,
                            allowMultipleSelection: allowMultipleSelection,
                            onSelect: {
                                handleItemSelection(item)
                            },
                            onAddToPlaylist: {
                                onAddToPlaylist?(item)
                            }
                        )
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
            ToolbarItem(placement: .automatic) {
                FileSelectionToolbarView(
                    showOnlyFolders: showOnlyFolders,
                    canNavigateUp: viewModel.currentDirectory != nil,
                    onSort: {
                        showSortOptions = true
                    },
                    onFilter: {
                        showFilterOptions = true
                    },
                    onRefresh: {
                        await viewModel.refresh()
                    },
                    onNavigateUp: {
                        await viewModel.navigateUp()
                    }
                )
            }
        }
        .overlay {
            if isLoading || viewModel.isLoading {
                LoadingOverlayView()
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
        .onChange(of: viewModel.lastError) { _, newError in
            if let error = newError as? FileProviderError {
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
    
    private var navigationTitle: String {
        if let directory = viewModel.currentDirectory {
            return directory.name
        } else if let provider = viewModel.selectedProvider {
            return provider.displayName
        } else {
            return "Files"
        }
    }
    
    private func handleItemSelection(_ item: FileItem) {
        if item.isDirectory {
            Task {
                await viewModel.navigateToDirectory(item)
            }
        } else {
            Task {
                await onSelectFile?(item)
            }
        }
    }
    
    private func sortOptionsView() -> some View {
        NavigationStack {
            List {
                let sortOrders: [FileProviderViewModel.SortOrder] = [
                    .byName,
                    .byDate,
                    .bySize
                ]
                
                ForEach(sortOrders, id: \.self) { order in
                    Button {
                        viewModel.sortOrder = order
                    } label: {
                        HStack {
                            Text(order.description)
                            Spacer()
                            if viewModel.sortOrder == order {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort By")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        showSortOptions = false
                    }
                }
            }
        }
    }
    
    private func filterOptionsView() -> some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        // Clear filters
                        Task {
                            await viewModel.setContentTypeFilter([])
                            showFilterOptions = false
                        }
                    } label: {
                        HStack {
                            Text("All Files")
                            Spacer()
                            if viewModel.contentTypeFilter.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                
                Section("Media Types") {
                    Button {
                        Task {
                            await viewModel.setContentTypeFilter([.movie, .video])
                            showFilterOptions = false
                        }
                    } label: {
                        HStack {
                            Label("Videos", systemImage: "play.rectangle")
                            Spacer()
                            if viewModel.contentTypeFilter == [.movie, .video] {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    Button {
                        Task {
                            await viewModel.setContentTypeFilter([.audio])
                            showFilterOptions = false
                        }
                    } label: {
                        HStack {
                            Label("Audio", systemImage: "music.note")
                            Spacer()
                            if viewModel.contentTypeFilter == [.audio] {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    Button {
                        Task {
                            await viewModel.setContentTypeFilter([.audiovisualContent])
                            showFilterOptions = false
                        }
                    } label: {
                        HStack {
                            Label("All Media", systemImage: "play.tv")
                            Spacer()
                            if viewModel.contentTypeFilter == [.audiovisualContent] {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        showFilterOptions = false
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FileSelectionView()
    }
}
