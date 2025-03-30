//
//  FileProviderWrapper.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import FileProvider
import UniformTypeIdentifiers

/// A wrapper around NSFileProviderManager to make it easier to work with
public class FileProviderWrapper {
    // MARK: - Properties
    
    /// The domain for this file provider
    private let domain: NSFileProviderDomain
    
    /// The file provider manager
    private let manager: NSFileProviderManager
    
    /// Cache for file provider item metadata
    private var itemCache: [String: [URLResourceKey: Any]] = [:]
    
    // MARK: - Initialization
    
    /// Initializes a wrapper for a file provider domain
    /// - Parameter domain: The domain to wrap
    /// - Throws: An error if the manager cannot be created
    public init(domain: NSFileProviderDomain) throws {
        self.domain = domain
        
        guard let manager = NSFileProviderManager(for: domain) else {
            throw FileProviderError.providerUnavailable
        }
        
        self.manager = manager
    }
    
    // MARK: - Public Methods
    
    /// Gets the root directory URL
    /// - Returns: The root directory URL
    public func getRootDirectoryURL() async throws -> URL {
        do {
            return try await manager.getUserVisibleURL(for: .rootContainer)
        } catch {
            throw FileProviderError.fromNSError(error as NSError)
        }
    }
    
    /// Gets the contents of a directory
    /// - Parameter directoryURL: The URL of the directory
    /// - Returns: The contents of the directory as URLs
    public func getContents(of directoryURL: URL) async throws -> [URL] {
        let fileManager = FileManager.default
        
        // Check if this URL is accessible
        guard fileManager.isReadableFile(atPath: directoryURL.path) else {
            throw FileProviderError.fileAccessDenied
        }
        
        // Get directory contents
        return try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )
    }
    
    /// Gets a URL for an item identifier
    /// - Parameter identifier: The identifier
    /// - Returns: The URL for the item
    public func getURL(for identifier: NSFileProviderItemIdentifier) async throws -> URL {
        do {
            return try await manager.getUserVisibleURL(for: identifier)
        } catch {
            throw FileProviderError.fromNSError(error as NSError)
        }
    }
    
    /// Gets metadata for a file URL
    /// - Parameter url: The URL of the file
    /// - Returns: The metadata for the file
    public func getItemMetadata(for url: URL) async throws -> [URLResourceKey: Any] {
        // Check if we have cached metadata
        if let cachedMetadata = itemCache[url.path] {
            return cachedMetadata
        }
        
        // Get resource values from the URL
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .nameKey,
            .pathKey,
            .fileResourceTypeKey
        ]
        
        let resourceValues = try url.resourceValues(forKeys: resourceKeys)
        
        // Convert to dictionary
        var metadata: [URLResourceKey: Any] = [:]
        
        if let isDirectory = resourceValues.isDirectory {
            metadata[.isDirectoryKey] = isDirectory
        }
        
        if let fileSize = resourceValues.fileSize {
            metadata[.fileSizeKey] = fileSize
        }
        
        if let modificationDate = resourceValues.contentModificationDate {
            metadata[.contentModificationDateKey] = modificationDate
        }
        
        if let creationDate = resourceValues.creationDate {
            metadata[.creationDateKey] = creationDate
        }
        
        if let name = resourceValues.name {
            metadata[.nameKey] = name
        }
        
        if let path = resourceValues.path {
            metadata[.pathKey] = path
        }
        
        if let fileResourceType = resourceValues.fileResourceType {
            metadata[.fileResourceTypeKey] = fileResourceType
        }
        
        // Cache the metadata
        itemCache[url.path] = metadata
        
        return metadata
    }
    
    /// Synchronizes the provider
    public func synchronize() async throws {
        do {
            try await manager.signalEnumerator(for: .rootContainer)
        } catch {
            throw FileProviderError.fromNSError(error as NSError)
        }
    }
    
    /// Creates a file item from a URL
    /// - Parameter url: The URL
    /// - Returns: A FileItem
    public func createFileItem(from url: URL) async throws -> FileItem {
        // Get metadata
        let metadata = try await getItemMetadata(for: url)
        
        // Get basic properties
        let isDirectory = metadata[.isDirectoryKey] as? Bool ?? false
        let fileSize = metadata[.fileSizeKey] as? Int64 ?? 0
        let modificationDate = metadata[.contentModificationDateKey] as? Date
        let creationDate = metadata[.creationDateKey] as? Date
        
        // Get content type based on filename
        let contentType = UTType(filenameExtension: url.pathExtension)
        
        return FileItem(
            id: url.path,
            name: url.lastPathComponent,
            url: url,
            size: isDirectory ? nil : fileSize,
            modificationDate: modificationDate,
            creationDate: creationDate,
            isDirectory: isDirectory,
            contentType: contentType,
            providerDomainName: domain.identifier.rawValue,
            providerItemIdentifier: nil,
            parentID: url.deletingLastPathComponent().path
        )
    }
    
    /// Converts a list of URLs to FileItems
    /// - Parameter urls: The URLs to convert
    /// - Returns: An array of FileItems
    public func createFileItems(from urls: [URL]) async throws -> [FileItem] {
        var fileItems: [FileItem] = []
        
        for url in urls {
            do {
                let fileItem = try await createFileItem(from: url)
                fileItems.append(fileItem)
            } catch {
                // Skip items that can't be converted
                continue
            }
        }
        
        return fileItems
    }
    
    /// Gets recent files
    /// - Parameters:
    ///   - maxItems: Maximum number of items to return
    ///   - contentTypes: Optional content types to filter by
    /// - Returns: Recently modified files
    public func getRecentFiles(maxItems: Int = 20, contentTypes: [UTType]? = nil) async throws -> [FileItem] {
        // Start from root directory
        let rootURL = try await getRootDirectoryURL()
        
        // Get all files recursively, up to a reasonable depth
        let fileItems = try await getFilesRecursively(from: rootURL, maxDepth: 3)
        
        // Filter by content type if specified
        let filteredItems: [FileItem]
        if let contentTypes = contentTypes, !contentTypes.isEmpty {
            filteredItems = fileItems.filter { item in
                guard let itemType = item.contentType else { return false }
                return contentTypes.contains { itemType.conforms(to: $0) }
            }
        } else {
            filteredItems = fileItems
        }
        
        // Sort by modification date (newest first)
        let sortedItems = filteredItems.sorted { (item1, item2) -> Bool in
            let date1 = item1.modificationDate ?? Date.distantPast
            let date2 = item2.modificationDate ?? Date.distantPast
            return date1 > date2
        }
        
        // Return the top N items
        return Array(sortedItems.prefix(maxItems))
    }
    
    // MARK: - Private Methods
    
    /// Gets files recursively from a directory
    /// - Parameters:
    ///   - directoryURL: The directory URL
    ///   - maxDepth: Maximum recursion depth
    ///   - currentDepth: Current recursion depth
    /// - Returns: Files in the directory and subdirectories
    private func getFilesRecursively(from directoryURL: URL, maxDepth: Int, currentDepth: Int = 0) async throws -> [FileItem] {
        // Stop if we've reached the maximum depth
        if currentDepth >= maxDepth {
            return []
        }
        
        // Get directory contents
        let contents = try await getContents(of: directoryURL)
        
        var fileItems: [FileItem] = []
        
        for url in contents {
            // Get metadata
            let metadata = try await getItemMetadata(for: url)
            let isDirectory = metadata[.isDirectoryKey] as? Bool ?? false
            
            // If it's a directory, process recursively
            if isDirectory {
                let subdirectoryItems = try await getFilesRecursively(
                    from: url,
                    maxDepth: maxDepth,
                    currentDepth: currentDepth + 1
                )
                fileItems.append(contentsOf: subdirectoryItems)
            }
            
            // Create file item
            let fileItem = try await createFileItem(from: url)
            fileItems.append(fileItem)
        }
        
        return fileItems
    }
}
