//
//  FileSelectionViewModel.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import UniformTypeIdentifiers
import Observation
import Combine

/// ViewModel for selecting files for playback
@Observable public class FileSelectionViewModel {
    // MARK: - Properties
    
    /// Files provider view model
    private let fileProviderViewModel: FileProviderViewModel
    
    /// List of files selected for playback
    public private(set) var selectedFiles: [FileItem] = []
    
    /// Currently playing file
    public private(set) var currentPlayingFile: FileItem?
    
    /// Recently accessed files
    public private(set) var recentFiles: [FileItem] = []
    
    /// Maximum number of recent files to track
    private let maxRecentFiles = 10
    
    /// Content types supported for playback
    public private(set) var supportedContentTypes: [UTType] = [.movie, .video, .audiovisualContent]
    
    /// Indicates if a loading operation is in progress
    public private(set) var isLoading: Bool = false
    
    /// The last error that occurred
    public private(set) var lastError: Error?
    
    // MARK: - Initialization
    
    /// Initializes the view model
    /// - Parameter fileProviderViewModel: The file provider view model to use
    public init(fileProviderViewModel: FileProviderViewModel = FileProviderViewModel()) {
        self.fileProviderViewModel = fileProviderViewModel
        
        // Set content type filter in the file provider view model
        Task {
            await fileProviderViewModel.setContentTypeFilter(supportedContentTypes)
        }
        
        // Load recent files from user defaults
        loadRecentFiles()
    }
    
    // MARK: - Public Methods
    
    /// Adds a file to the playlist
    /// - Parameter file: The file to add
    public func addToPlaylist(_ file: FileItem) {
        guard file.isVideo || file.isAudio else { return }
        
        // Don't add duplicates
        guard !selectedFiles.contains(where: { $0.id == file.id }) else { return }
        
        selectedFiles.append(file)
        addToRecentFiles(file)
    }
    
    /// Removes a file from the playlist
    /// - Parameter file: The file to remove
    public func removeFromPlaylist(_ file: FileItem) {
        selectedFiles.removeAll { $0.id == file.id }
        
        // If this was the current playing file, clear it
        if currentPlayingFile?.id == file.id {
            currentPlayingFile = nil
        }
    }
    
    /// Clears the playlist
    public func clearPlaylist() {
        selectedFiles = []
        currentPlayingFile = nil
    }
    
    /// Sets the current playing file
    /// - Parameter file: The file to set as currently playing
    public func setCurrentPlayingFile(_ file: FileItem) {
        currentPlayingFile = file
        addToRecentFiles(file)
    }
    
    /// Gets the next file in the playlist
    /// - Returns: The next file in the playlist, or nil if there is none
    public func getNextFile() -> FileItem? {
        guard let currentPlayingFile = currentPlayingFile else {
            return selectedFiles.first
        }
        
        // Find the index of the current file
        guard let currentIndex = selectedFiles.firstIndex(where: { $0.id == currentPlayingFile.id }) else {
            return selectedFiles.first
        }
        
        // Get the next file index, wrapping around to the beginning if necessary
        let nextIndex = (currentIndex + 1) % selectedFiles.count
        return selectedFiles[nextIndex]
    }
    
    /// Gets the previous file in the playlist
    /// - Returns: The previous file in the playlist, or nil if there is none
    public func getPreviousFile() -> FileItem? {
        guard let currentPlayingFile = currentPlayingFile else {
            return selectedFiles.last
        }
        
        // Find the index of the current file
        guard let currentIndex = selectedFiles.firstIndex(where: { $0.id == currentPlayingFile.id }) else {
            return selectedFiles.last
        }
        
        // Get the previous file index, wrapping around to the end if necessary
        let previousIndex = (currentIndex - 1 + selectedFiles.count) % selectedFiles.count
        return selectedFiles[previousIndex]
    }
    
    /// Gets a local URL for a file
    /// - Parameter file: The file to get a local URL for
    /// - Returns: A local URL that can be used to access the file
    public func getLocalURL(for file: FileItem) async -> URL? {
        return await fileProviderViewModel.getLocalURL(for: file)
    }
    
    /// Accesses the file provider view model for browsing
    public func getFileProviderViewModel() -> FileProviderViewModel {
        return fileProviderViewModel
    }
    
    /// Reorders the playlist
    /// - Parameters:
    ///   - fromIndex: The index to move from
    ///   - toIndex: The index to move to
    public func movePlaylistItem(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < selectedFiles.count,
              toIndex >= 0, toIndex < selectedFiles.count else {
            return
        }
        
        let item = selectedFiles.remove(at: fromIndex)
        selectedFiles.insert(item, at: toIndex)
    }
    
    /// Gets file information for displaying
    /// - Parameter file: The file to get information for
    /// - Returns: A dictionary of information about the file
    public func getFileInfo(_ file: FileItem) -> [String: String] {
        var info: [String: String] = [:]
        
        info["Name"] = file.name
        
        if let size = file.size {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            info["Size"] = formatter.string(fromByteCount: size)
        }
        
        if let contentType = file.contentType {
            info["Type"] = contentType.localizedDescription
        }
        
        if let modificationDate = file.modificationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            info["Modified"] = formatter.string(from: modificationDate)
        }
        
        if let creationDate = file.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            info["Created"] = formatter.string(from: creationDate)
        }
        
        return info
    }
    
    // MARK: - Private Methods
    
    /// Adds a file to the recent files list
    /// - Parameter file: The file to add
    private func addToRecentFiles(_ file: FileItem) {
        // Remove the file if it's already in the list
        recentFiles.removeAll { $0.id == file.id }
        
        // Add the file to the beginning of the list
        recentFiles.insert(file, at: 0)
        
        // Trim the list if it's too long
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
        
        // Save the updated list
        saveRecentFiles()
    }
    
    /// Loads recent files from user defaults
    private func loadRecentFiles() {
        guard let data = UserDefaults.standard.data(forKey: "RecentFiles") else { return }
        
        do {
            let decoder = JSONDecoder()
            recentFiles = try decoder.decode([FileItem].self, from: data)
        } catch {
            print("Error loading recent files: \(error)")
            recentFiles = []
        }
    }
    
    /// Saves recent files to user defaults
    private func saveRecentFiles() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(recentFiles)
            UserDefaults.standard.set(data, forKey: "RecentFiles")
        } catch {
            print("Error saving recent files: \(error)")
        }
    }
}
