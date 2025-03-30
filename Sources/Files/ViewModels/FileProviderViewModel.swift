//
//  FileProviderViewModel.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import FileProvider
import Combine
import Observation
import UniformTypeIdentifiers

/// ViewModel for managing file providers and their contents
@Observable public class FileProviderViewModel {
    // MARK: - Properties
    
    /// The list of available file providers
    public private(set) var providers: [FileProviderModel] = []
    
    /// The currently selected file provider
    public var selectedProvider: FileProviderModel?
    
    /// The current directory being displayed
    public var currentDirectory: FileItem?
    
    /// The breadcrumb path to the current directory
    public private(set) var directoryPath: [FileItem] = []
    
    /// The contents of the current directory
    public private(set) var directoryContents: [FileItem] = []
    
    /// Search query for filtering files
    public var searchQuery: String = ""
    
    /// Filter for content types
    public var contentTypeFilter: [UTType] = []
    
    /// Sort order for the file list
    public var sortOrder: SortOrder = .nameAscending
    
    /// Indicates if a loading operation is in progress
    public private(set) var isLoading: Bool = false
    
    /// The last error that occurred
    public private(set) var lastError: Error?
    
    /// Flag indicating if only folders should be shown (for directory selection)
    public var showOnlyFolders: Bool = false
    
    // Service for interacting with file providers
    private let service: FileProviderServiceProtocol
    
    // Cancellables for monitoring directory changes
    private var directoryCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    /// Initializes the view model
    /// - Parameter service: The service to use for file provider operations
    public init(service: FileProviderServiceProtocol = FileProviderService.shared) {
        self.service = service
    }
    
    // MARK: - Public Methods
    
    /// Loads the list of available file providers
    public func loadProviders() async {
        isLoading = true
        lastError = nil
        
        do {
            providers = try await service.getProviders()
            
            // If we haven't selected a provider yet, select the local file system
            if selectedProvider == nil, let localProvider = providers.first(where: { $0.isLocal }) {
                selectedProvider = localProvider
                await loadContents()
            }
        } catch {
            lastError = error
        }
        
        isLoading = false
    }
    
    /// Sets the selected provider and loads its contents
    /// - Parameter provider: The provider to select
    public func selectProvider(_ provider: FileProviderModel) async {
        selectedProvider = provider
        currentDirectory = nil
        directoryPath = []
        await loadContents()
    }
    
    /// Navigates to a directory and loads its contents
    /// - Parameter directory: The directory to navigate to
    public func navigateToDirectory(_ directory: FileItem) async {
        guard let selectedProvider = selectedProvider else { return }
        
        isLoading = true
        lastError = nil
        
        do {
            // Stop monitoring the current directory
            if let currentDirectory = currentDirectory {
                service.stopMonitoring(currentDirectory, provider: selectedProvider)
            }
            
            // Update current directory and breadcrumb path
            currentDirectory = directory
            updateDirectoryPath()
            
            // Load the contents of the new directory
            directoryContents = try await service.getContents(of: directory, from: selectedProvider)
            
            // Apply filters and sorting
            applyFiltersAndSorting()
            
            // Start monitoring the new directory for changes
            startDirectoryMonitoring()
        } catch {
            lastError = error
        }
        
        isLoading = false
    }
    
    /// Navigates to the parent directory
    public func navigateUp() async {
        guard let selectedProvider = selectedProvider, let currentDirectory = currentDirectory else { return }
        
        // If we're already at the root, do nothing
        if directoryPath.count <= 1 {
            self.currentDirectory = nil
            directoryPath = []
            await loadContents()
            return
        }
        
        isLoading = true
        lastError = nil
        
        do {
            // Stop monitoring the current directory
            service.stopMonitoring(currentDirectory, provider: selectedProvider)
            
            // Get the parent directory from the path
            let parentDirectory = directoryPath[directoryPath.count - 2]
            
            // Update current directory and breadcrumb path
            self.currentDirectory = parentDirectory
            directoryPath.removeLast()
            
            // Load the contents of the parent directory
            directoryContents = try await service.getContents(of: parentDirectory, from: selectedProvider)
            
            // Apply filters and sorting
            applyFiltersAndSorting()
            
            // Start monitoring the parent directory for changes
            startDirectoryMonitoring()
        } catch {
            lastError = error
        }
        
        isLoading = false
    }
    
    /// Refreshes the contents of the current directory
    public func refresh() async {
        await loadContents()
    }
    
    /// Creates a new directory
    /// - Parameter name: The name of the directory to create
    public func createDirectory(name: String) async -> FileItem? {
        guard let selectedProvider = selectedProvider, let currentDirectory = currentDirectory else { return nil }
        
        isLoading = true
        lastError = nil
        
        do {
            let newDirectory = try await service.createDirectory(name: name, in: currentDirectory, provider: selectedProvider)
            
            // Reload the directory contents
            await loadContents()
            
            isLoading = false
            return newDirectory
        } catch {
            lastError = error
            isLoading = false
            return nil
        }
    }
    
    /// Deletes a file or directory
    /// - Parameter item: The item to delete
    public func deleteItem(_ item: FileItem) async -> Bool {
        guard let selectedProvider = selectedProvider else { return false }
        
        isLoading = true
        lastError = nil
        
        do {
            try await service.deleteItem(item, from: selectedProvider)
            
            // Reload the directory contents
            await loadContents()
            
            isLoading = false
            return true
        } catch {
            lastError = error
            isLoading = false
            return false
        }
    }
    
    /// Renames a file or directory
    /// - Parameters:
    ///   - item: The item to rename
    ///   - newName: The new name
    public func renameItem(_ item: FileItem, to newName: String) async -> FileItem? {
        guard let selectedProvider = selectedProvider else { return nil }
        
        isLoading = true
        lastError = nil
        
        do {
            let renamedItem = try await service.renameItem(item, to: newName, provider: selectedProvider)
            
            // Reload the directory contents
            await loadContents()
            
            isLoading = false
            return renamedItem
        } catch {
            lastError = error
            isLoading = false
            return nil
        }
    }
    
    /// Gets a local URL for a file
    /// - Parameter item: The file to get a local URL for
    /// - Returns: A local URL that can be used to access the file
    public func getLocalURL(for item: FileItem) async -> URL? {
        guard let selectedProvider = selectedProvider else { return nil }
        
        lastError = nil
        
        do {
            return try await service.getLocalURL(for: item, provider: selectedProvider)
        } catch {
            lastError = error
            return nil
        }
    }
    
    /// Searches for files matching the query
    /// - Parameter query: The search query
    public func search() async {
        guard let selectedProvider = selectedProvider else { return }
        
        isLoading = true
        lastError = nil
        
        do {
            // If search query is empty, just reload the current directory
            if searchQuery.isEmpty {
                await loadContents()
                return
            }
            
            let contentTypes = contentTypeFilter.isEmpty ? nil : contentTypeFilter
            
            // Perform the search
            directoryContents = try await service.searchFiles(
                query: searchQuery,
                in: selectedProvider,
                contentTypes: contentTypes
            )
            
            // Apply sorting
            applySorting()
        } catch {
            lastError = error
        }
        
        isLoading = false
    }
    
    /// Changes the content type filter
    /// - Parameter contentTypes: The content types to filter by
    public func setContentTypeFilter(_ contentTypes: [UTType]) async {
        contentTypeFilter = contentTypes
        await loadContents()
    }
    
    /// Changes the sort order
    /// - Parameter sortOrder: The sort order to use
    public func setSortOrder(_ sortOrder: SortOrder) {
        self.sortOrder = sortOrder
        applySorting()
    }
    
    // MARK: - Private Methods
    
    /// Loads the contents of the current directory
    private func loadContents() async {
        guard let selectedProvider = selectedProvider else { return }
        
        isLoading = true
        lastError = nil
        
        do {
            // Stop monitoring the current directory if there is one
            if let currentDirectory = currentDirectory {
                service.stopMonitoring(currentDirectory, provider: selectedProvider)
            }
            
            // Load the contents of the current directory
            directoryContents = try await service.getContents(of: currentDirectory, from: selectedProvider)
            
            // Apply filters and sorting
            applyFiltersAndSorting()
            
            // Start monitoring the directory for changes
            startDirectoryMonitoring()
        } catch {
            lastError = error
        }
        
        isLoading = false
    }
    
    /// Updates the breadcrumb path based on the current directory
    private func updateDirectoryPath() {
        guard let currentDirectory = currentDirectory else {
            directoryPath = []
            return
        }
        
        // If we just navigated down by selecting a directory, add it to the path
        if let lastDirectory = directoryPath.last, lastDirectory.id != currentDirectory.id {
            directoryPath.append(currentDirectory)
            return
        }
        
        // If we're setting a new current directory and need to rebuild the path
        // This is a simplified implementation and may not work for all scenarios
        directoryPath = [currentDirectory]
    }
    
    /// Starts monitoring the current directory for changes
    private func startDirectoryMonitoring() {
        guard let selectedProvider = selectedProvider, let currentDirectory = currentDirectory else { return }
        
        directoryCancellable = service.startMonitoring(currentDirectory, provider: selectedProvider)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.lastError = error
                    }
                },
                receiveValue: { [weak self] contents in
                    self?.directoryContents = contents
                    self?.applyFiltersAndSorting()
                }
            )
    }
    
    /// Applies filters and sorting to the directory contents
    private func applyFiltersAndSorting() {
        // Apply content type filter if specified
        if !contentTypeFilter.isEmpty {
            directoryContents = directoryContents.filter { item in
                // Always include directories
                if item.isDirectory {
                    return !showOnlyFolders || item.isDirectory
                }
                
                // Filter by content type
                guard let contentType = item.contentType else { return false }
                
                return contentTypeFilter.contains { type in
                    contentType.conforms(to: type)
                }
            }
        } else if showOnlyFolders {
            // Show only folders if that option is enabled
            directoryContents = directoryContents.filter { $0.isDirectory }
        }
        
        // Apply sorting
        applySorting()
    }
    
    /// Applies sorting to the directory contents
    private func applySorting() {
        switch sortOrder {
        case .nameAscending:
            directoryContents.sort { (lhs, rhs) in
                // Directories come first, then sort by name
                if lhs.isDirectory && !rhs.isDirectory { return true }
                if !lhs.isDirectory && rhs.isDirectory { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .nameDescending:
            directoryContents.sort { (lhs, rhs) in
                // Directories come first, then sort by name
                if lhs.isDirectory && !rhs.isDirectory { return true }
                if !lhs.isDirectory && rhs.isDirectory { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedDescending
            }
        case .dateAscending:
            directoryContents.sort { (lhs, rhs) in
                // Directories come first, then sort by date
                if lhs.isDirectory && !rhs.isDirectory { return true }
                if !lhs.isDirectory && rhs.isDirectory { return false }
                
                guard let lhsDate = lhs.modificationDate else { return true }
                guard let rhsDate = rhs.modificationDate else { return false }
                return lhsDate < rhsDate
            }
        case .dateDescending:
            directoryContents.sort { (lhs, rhs) in
                // Directories come first, then sort by date
                if lhs.isDirectory && !rhs.isDirectory { return true }
                if !lhs.isDirectory && rhs.isDirectory { return false }
                
                guard let lhsDate = lhs.modificationDate else { return false }
                guard let rhsDate = rhs.modificationDate else { return true }
                return lhsDate > rhsDate
            }
        case .sizeAscending:
            directoryContents.sort { (lhs, rhs) in
                // Directories come first, then sort by size
                if lhs.isDirectory && !rhs.isDirectory { return true }
                if !lhs.isDirectory && rhs.isDirectory { return false }
                
                guard let lhsSize = lhs.size else { return true }
                guard let rhsSize = rhs.size else { return false }
                return lhsSize < rhsSize
            }
        case .sizeDescending:
            directoryContents.sort { (lhs, rhs) in
                // Directories come first, then sort by size
                if lhs.isDirectory && !rhs.isDirectory { return true }
                if !lhs.isDirectory && rhs.isDirectory { return false }
                
                guard let lhsSize = lhs.size else { return false }
                guard let rhsSize = rhs.size else { return true }
                return lhsSize > rhsSize
            }
        }
    }
    
    // MARK: - Sorting Options
    
    /// Sort order options for file lists
    public enum SortOrder: String, CaseIterable {
        case nameAscending = "Name: A-Z"
        case nameDescending = "Name: Z-A"
        case dateAscending = "Date: Oldest first"
        case dateDescending = "Date: Newest first"
        case sizeAscending = "Size: Smallest first"
        case sizeDescending = "Size: Largest first"
    }
}
