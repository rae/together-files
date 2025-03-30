// FileBrowserViewModel.swift
// Files
//
// Created on 2025-03-30.
//

import Foundation
import FileProvider
import Observation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "tnir.ca.WatchTogether.Files", category: "FileBrowserViewModel")

/// View model for browsing files from file providers
@Observable public final class FileBrowserViewModel {
    // MARK: - Properties
    
    // Available file provider domains
    public private(set) var availableDomains: [FileProviderDomain] = []
    
    // Currently selected domain
    public private(set) var selectedDomain: FileProviderDomain?
    
    // Current directory stack for navigation
    public private(set) var directoryStack: [FileItem] = []
    
    // Files in current directory
    public private(set) var files: [FileItem] = []
    
    // Search state
    public private(set) var searchResults: [FileItem] = []
    public var searchText: String = ""
    
    // Loading and error states
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?
    
    // Recently accessed files for quick access
    public private(set) var recentFiles: [FileItem] = []
    
    // Selected file items (for multi-select)
    public private(set) var selectedItems: Set<FileItem> = []
    
    // Currently playing item
    public private(set) var currentPlayingItem: FileItem?
    
    // Service to interact with file providers
    private let fileProviderService: FileProviderService
    
    // MARK: - Initialization
    
    public init(fileProviderService: FileProviderService = FileProviderService.shared) {
        self.fileProviderService = fileProviderService
    }
    
    // MARK: - Domain Management
    
    /// Load all available file provider domains
    public func loadDomains() async {
        isLoading = true
        errorMessage = nil
        
        do {
            availableDomains = try await fileProviderService.getDomains()
            if let firstDomain = availableDomains.first, selectedDomain == nil {
                selectedDomain = firstDomain
                await loadRootDirectory()
            }
        } catch {
            let providerError = error as? FileProviderError ?? FileProviderError(error: error)
            errorMessage = providerError.errorDescription
            logger.error("Failed to load domains: \(providerError.errorDescription ?? error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Select a specific domain
    public func selectDomain(_ domain: FileProviderDomain) async {
        guard domain != selectedDomain else { return }
        
        selectedDomain = domain
        directoryStack = []
        await loadRootDirectory()
    }
    
    // MARK: - Directory Navigation
    
    /// Load the root directory of the selected domain
    public func loadRootDirectory() async {
        guard let domain = selectedDomain else {
            errorMessage = "No file provider selected"
            return
        }
        
        isLoading = true
        errorMessage = nil
        directoryStack = []
        
        do {
            files = try await fileProviderService.listItems(domain: domain)
            sortFiles()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    /// Navigate into a directory
    public func navigateToDirectory(_ directory: FileItem) async {
        guard directory.isDirectory else {
            logger.warning("Attempted to navigate to a non-directory item: \(directory.filename)")
            return
        }
        
        guard let domain = selectedDomain else {
            errorMessage = "No file provider selected"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let items = try await fileProviderService.listItems(in: directory, domain: domain)
            directoryStack.append(directory)
            files = items
            sortFiles()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    /// Navigate back to parent directory
    public func navigateBack() async {
        guard !directoryStack.isEmpty else {
            // Already at root
            return
        }
        
        guard let domain = selectedDomain else {
            errorMessage = "No file provider selected"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Pop the current directory
        _ = directoryStack.popLast()
        
        do {
            // Get the parent directory (or nil for root)
            let parentDirectory = directoryStack.last
            
            let items = try await fileProviderService.listItems(in: parentDirectory, domain: domain)
            files = items
            sortFiles()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - File Operations
    
    /// Get URL for a file item
    public func getFileURL(_ item: FileItem) async -> URL? {
        guard !item.isDirectory else {
            logger.warning("Cannot get URL for a directory: \(item.filename)")
            return nil
        }
        
        do {
            item.setLoading(true)
            let url = try await fileProviderService.getURL(for: item)
            item.setLoading(false)
            addToRecentFiles(item)
            return url
        } catch {
            item.setLoading(false)
            handleError(error)
            return nil
        }
    }
    
    /// Select a file for playback
    public func selectFileForPlayback(_ item: FileItem) async -> URL? {
        guard item.isPlayableVideo else {
            errorMessage = "The selected file is not a supported video format"
            return nil
        }
        
        if let url = await getFileURL(item) {
            currentPlayingItem = item
            return url
        }
        
        return nil
    }
    
    /// Select a file item (for multi-select operations)
    public func toggleItemSelection(_ item: FileItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    /// Clear all selections
    public func clearSelection() {
        selectedItems.removeAll()
    }
    
    /// Add a file to recent files list
    private func addToRecentFiles(_ item: FileItem) {
        // Remove if already exists to avoid duplicates
        recentFiles.removeAll { $0.id == item.id }
        
        // Add to beginning of list
        recentFiles.insert(item, at: 0)
        
        // Limit to 10 recent files
        if recentFiles.count > 10 {
            recentFiles = Array(recentFiles.prefix(10))
        }
    }
    
    // MARK: - Search
    
    /// Search for files matching the search text
    public func search() async {
        guard !searchText.isEmpty, let domain = selectedDomain else {
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // For simplicity, we're just filtering the current directory
            // In a real implementation, you might want to use the file provider's search capabilities
            let results = files.filter { $0.filename.localizedCaseInsensitiveContains(searchText) }
            searchResults = results
        } catch {
            handleError(error)
            searchResults = []
        }
        
        isLoading = false
    }
    
    /// Clear search results
    public func clearSearch() {
        searchText = ""
        searchResults = []
    }
    
    // MARK: - Helper Methods
    
    /// Sort files (directories first, then alphabetically)
    private func sortFiles() {
        files.sort { lhs, rhs in
            if lhs.isDirectory && !rhs.isDirectory {
                return true
            } else if !lhs.isDirectory && rhs.isDirectory {
                return false
            } else {
                return lhs.filename.localizedCaseInsensitiveCompare(rhs.filename) == .orderedAscending
            }
        }
    }
    
    /// Handle errors from file provider operations
    private func handleError(_ error: Error) {
        let providerError = error as? FileProviderError ?? FileProviderError(error: error)
        errorMessage = providerError.errorDescription
        logger.error("File provider error: \(providerError.errorDescription ?? error.localizedDescription)")
        
        if let recovery = providerError.recoverySuggestion {
            logger.info("Recovery suggestion: \(recovery)")
        }
    }
    
    // MARK: - Cleanup
    
    /// Clean up resources when done
    public func cleanup() {
        // Stop accessing any open file URLs
        if let item = currentPlayingItem, let url = item.url {
            fileProviderService.stopAccessing(url: url)
        }
        currentPlayingItem = nil
    }
}
