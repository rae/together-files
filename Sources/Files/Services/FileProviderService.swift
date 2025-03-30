//
//  FileProviderService.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import FileProvider
import Combine
import UniformTypeIdentifiers

/// Protocol defining the interface for file provider services
public protocol FileProviderServiceProtocol {
    /// Get all available file provider domains
    /// - Returns: A list of file provider models
    func getProviders() async throws -> [FileProviderModel]
    
    /// Get contents of a directory from a specific provider
    /// - Parameters:
    ///   - directory: The directory to list contents of, or nil for root
    ///   - provider: The file provider to use
    /// - Returns: A list of file items in the directory
    func getContents(of directory: FileItem?, from provider: FileProviderModel) async throws -> [FileItem]
    
    /// Get file item details
    /// - Parameters:
    ///   - itemID: The ID of the file item
    ///   - provider: The file provider to use
    /// - Returns: Detailed file item information
    func getItemDetails(itemID: String, from provider: FileProviderModel) async throws -> FileItem
    
    /// Search for files matching the query
    /// - Parameters:
    ///   - query: The search query
    ///   - provider: The file provider to search in
    ///   - contentTypes: Optional array of content types to filter by
    /// - Returns: A list of matching file items
    func searchFiles(query: String, in provider: FileProviderModel, contentTypes: [UTType]?) async throws -> [FileItem]
    
    /// Create a new directory
    /// - Parameters:
    ///   - name: Name of the new directory
    ///   - parent: Parent directory where to create the new directory
    ///   - provider: The file provider to use
    /// - Returns: The newly created directory item
    func createDirectory(name: String, in parent: FileItem, provider: FileProviderModel) async throws -> FileItem
    
    /// Delete a file or directory
    /// - Parameters:
    ///   - item: The item to delete
    ///   - provider: The file provider to use
    func deleteItem(_ item: FileItem, from provider: FileProviderModel) async throws
    
    /// Move a file or directory
    /// - Parameters:
    ///   - item: The item to move
    ///   - destination: The destination directory
    ///   - provider: The file provider to use
    /// - Returns: The updated file item after moving
    func moveItem(_ item: FileItem, to destination: FileItem, provider: FileProviderModel) async throws -> FileItem
    
    /// Rename a file or directory
    /// - Parameters:
    ///   - item: The item to rename
    ///   - newName: The new name
    ///   - provider: The file provider to use
    /// - Returns: The updated file item after renaming
    func renameItem(_ item: FileItem, to newName: String, provider: FileProviderModel) async throws -> FileItem
    
    /// Copy a file
    /// - Parameters:
    ///   - item: The item to copy
    ///   - destination: The destination directory
    ///   - provider: The file provider to use
    /// - Returns: The new copy of the file item
    func copyItem(_ item: FileItem, to destination: FileItem, provider: FileProviderModel) async throws -> FileItem
    
    /// Get a temporary local URL for a file
    /// - Parameters:
    ///   - item: The file item
    ///   - provider: The file provider to use
    /// - Returns: A local URL for the file
    func getLocalURL(for item: FileItem, provider: FileProviderModel) async throws -> URL
    
    /// Start monitoring changes for a directory
    /// - Parameters:
    ///   - directory: The directory to monitor
    ///   - provider: The file provider to use
    /// - Returns: A publisher that emits updated file lists when changes occur
    func startMonitoring(_ directory: FileItem, provider: FileProviderModel) -> AnyPublisher<[FileItem], Error>
    
    /// Stop monitoring changes for a directory
    /// - Parameters:
    ///   - directory: The directory to stop monitoring
    ///   - provider: The file provider to use
    func stopMonitoring(_ directory: FileItem, provider: FileProviderModel)
    
    /// Synchronize a file provider (refresh its contents)
    /// - Parameter provider: The file provider to synchronize
    func synchronize(_ provider: FileProviderModel) async throws
}

/// Implementation of the FileProviderServiceProtocol
public class FileProviderService: FileProviderServiceProtocol {
    // Singleton instance
    public static let shared = FileProviderService()
    
    // Private initializer for singleton
    private init() {}
    
    // Dictionary to store directory change publishers
    private var directoryMonitors: [String: PassthroughSubject<[FileItem], Error>] = [:]
    
    // MARK: - Provider Management
    
    public func getProviders() async throws -> [FileProviderModel] {
        var providers = [FileProviderModel]()
        
        // Add local file system provider
        let localProvider = FileProviderModel(
            id: "local.filesystem",
            name: "Local",
            displayName: "Local Files",
            iconName: "folder",
            isLocal: true
        )
        providers.append(localProvider)
        
        // Get file provider domains
        let domains = try await NSFileProviderManager.domains()
        
        for domain in domains {
            let displayName = domain.displayName
            let domainIdentifier = domain.identifier.rawValue
            
            let provider = FileProviderModel(
                id: "domain.\(domainIdentifier)",
                name: domainIdentifier,
                displayName: displayName,
                iconName: "doc.on.doc",
                isLocal: false,
                domain: domain
            )
            
            // Get domain status
            if let manager = NSFileProviderManager(for: domain) {
                do {
                    provider.updateStatus(.connecting)
                    
                    // Check if provider is available
                    let _ = try await manager.getUserVisibleURL(for: .rootContainer)
                    provider.updateStatus(.available)
                } catch {
                    provider.setError(error)
                }
            } else {
                provider.updateStatus(.unavailable)
            }
            
            providers.append(provider)
        }
        
        return providers
    }
    
    // MARK: - Directory and File Operations
    
    public func getContents(of directory: FileItem?, from provider: FileProviderModel) async throws -> [FileItem] {
        // If local file system
        if provider.isLocal {
            let fm = FileManager.default
            
            // Use the directory URL if provided, otherwise use Documents directory
            let directoryURL: URL
            if let directory = directory {
                directoryURL = directory.url
            } else {
                directoryURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            }
            
            // Get directory contents
            let contents = try fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
            ])
            
            // Map URLs to FileItem objects
            var fileItems = [FileItem]()
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [
                    .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
                ])
                
                let isDirectory = resourceValues.isDirectory ?? false
                let contentType = UTType(filenameExtension: url.pathExtension)
                
                let fileItem = FileItem(
                    id: url.path,
                    name: url.lastPathComponent,
                    url: url,
                    size: resourceValues.fileSize as? Int64,
                    modificationDate: resourceValues.contentModificationDate,
                    creationDate: resourceValues.creationDate,
                    isDirectory: isDirectory,
                    contentType: contentType,
                    parentID: directory?.id
                )
                
                fileItems.append(fileItem)
            }
            
            return fileItems
        }
        
        // For file provider domains
        guard let domain = provider.domain else {
            throw FileProviderError.providerNotFound
        }
        
        guard let manager = NSFileProviderManager(for: domain) else {
            throw FileProviderError.providerUnavailable
        }
        
        // Determine the parent item identifier
        let parentItemIdentifier: NSFileProviderItemIdentifier
        if let directory = directory, let providerItemID = directory.providerItemIdentifier {
            parentItemIdentifier = NSFileProviderItemIdentifier(providerItemID)
        } else {
            parentItemIdentifier = .rootContainer
        }
        
        // Create an enumerator for the parent item
        let enumerator = try await manager.enumerator(for: parentItemIdentifier)
        
        // Get the items from the enumerator
        let items = try await enumerator.items()
        
        // Map NSFileProviderItems to our FileItem model
        return items.compactMap { item in
            guard let itemIdentifier = item.itemIdentifier.rawValue as? String else { return nil }
            
            // Get content type based on filename
            let contentType = UTType(filenameExtension: item.filename.pathExtension)
            
            // Create URL (this may not be a real file URL for cloud providers)
            let url = URL(fileURLWithPath: item.filename)
            
            return FileItem(
                id: itemIdentifier,
                name: item.filename.lastPathComponent,
                url: url,
                size: item.documentSize as? Int64,
                modificationDate: item.contentModificationDate,
                creationDate: item.creationDate,
                isDirectory: item.capabilities.contains(.allowsContentEnumerating),
                contentType: contentType,
                providerDomainName: domain.identifier.rawValue,
                providerItemIdentifier: itemIdentifier,
                parentID: parentItemIdentifier.rawValue as? String
            )
        }
    }
    
    public func getItemDetails(itemID: String, from provider: FileProviderModel) async throws -> FileItem {
        // For local file system
        if provider.isLocal {
            let fm = FileManager.default
            let url = URL(fileURLWithPath: itemID)
            
            // Check if file exists
            guard fm.fileExists(atPath: url.path) else {
                throw FileProviderError.fileNotFound
            }
            
            // Get file attributes
            let resourceValues = try url.resourceValues(forKeys: [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
            ])
            
            let isDirectory = resourceValues.isDirectory ?? false
            let contentType = UTType(filenameExtension: url.pathExtension)
            
            return FileItem(
                id: url.path,
                name: url.lastPathComponent,
                url: url,
                size: resourceValues.fileSize as? Int64,
                modificationDate: resourceValues.contentModificationDate,
                creationDate: resourceValues.creationDate,
                isDirectory: isDirectory,
                contentType: contentType,
                parentID: url.deletingLastPathComponent().path
            )
        }
        
        // For file provider domains
        guard let domain = provider.domain else {
            throw FileProviderError.providerNotFound
        }
        
        guard let manager = NSFileProviderManager(for: domain) else {
            throw FileProviderError.providerUnavailable
        }
        
        let itemIdentifier = NSFileProviderItemIdentifier(itemID)
        
        do {
            let item = try await manager.item(for: itemIdentifier)
            
            // Get content type based on filename
            let contentType = UTType(filenameExtension: item.filename.pathExtension)
            
            // Create URL
            let url = try await manager.getUserVisibleURL(for: itemIdentifier)
            
            return FileItem(
                id: itemIdentifier.rawValue as? String ?? UUID().uuidString,
                name: item.filename.lastPathComponent,
                url: url,
                size: item.documentSize as? Int64,
                modificationDate: item.contentModificationDate,
                creationDate: item.creationDate,
                isDirectory: item.capabilities.contains(.allowsContentEnumerating),
                contentType: contentType,
                providerDomainName: domain.identifier.rawValue,
                providerItemIdentifier: itemIdentifier.rawValue as? String,
                parentID: item.parentItemIdentifier.rawValue as? String
            )
        } catch {
            throw FileProviderError.fromNSError(error as NSError)
        }
    }
    
    public func searchFiles(query: String, in provider: FileProviderModel, contentTypes: [UTType]? = nil) async throws -> [FileItem] {
        // For local file system
        if provider.isLocal {
            // Start with the user's Documents directory
            let fm = FileManager.default
            let documentsURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            
            // Create a simple recursive search function
            func searchDirectory(_ directoryURL: URL) throws -> [FileItem] {
                let contents = try fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [
                    .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
                ])
                
                var results = [FileItem]()
                
                for url in contents {
                    let resourceValues = try url.resourceValues(forKeys: [
                        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
                    ])
                    
                    let isDirectory = resourceValues.isDirectory ?? false
                    
                    // If it's a directory, search recursively
                    if isDirectory {
                        let subdirectoryResults = try searchDirectory(url)
                        results.append(contentsOf: subdirectoryResults)
                    }
                    
                    // Check if filename matches query
                    let filename = url.lastPathComponent.lowercased()
                    if filename.contains(query.lowercased()) {
                        let contentType = UTType(filenameExtension: url.pathExtension)
                        
                        // Filter by content type if specified
                        if let contentTypes = contentTypes, !contentTypes.isEmpty {
                            guard let contentType = contentType else { continue }
                            
                            let matchesContentType = contentTypes.contains { type in
                                contentType.conforms(to: type)
                            }
                            
                            if !matchesContentType {
                                continue
                            }
                        }
                        
                        let fileItem = FileItem(
                            id: url.path,
                            name: url.lastPathComponent,
                            url: url,
                            size: resourceValues.fileSize as? Int64,
                            modificationDate: resourceValues.contentModificationDate,
                            creationDate: resourceValues.creationDate,
                            isDirectory: isDirectory,
                            contentType: contentType,
                            parentID: url.deletingLastPathComponent().path
                        )
                        
                        results.append(fileItem)
                    }
                }
                
                return results
            }
            
            return try searchDirectory(documentsURL)
        }
        
        // For file provider domains
        // Note: This is a simplified implementation as not all file providers support robust search capabilities
        guard let domain = provider.domain else {
            throw FileProviderError.providerNotFound
        }
        
        guard let manager = NSFileProviderManager(for: domain) else {
            throw FileProviderError.providerUnavailable
        }
        
        // Start with root directory
        let enumerator = try await manager.enumerator(for: .rootContainer)
        let items = try await enumerator.items()
        
        // Filter the items based on the query
        return items.compactMap { item in
            // Check if filename matches query
            let filename = item.filename.lastPathComponent.lowercased()
            if filename.contains(query.lowercased()) {
                guard let itemIdentifier = item.itemIdentifier.rawValue as? String else { return nil }
                
                // Get content type based on filename
                let contentType = UTType(filenameExtension: item.filename.pathExtension)
                
                // Filter by content type if specified
                if let contentTypes = contentTypes, !contentTypes.isEmpty {
                    guard let contentType = contentType else { return nil }
                    
                    let matchesContentType = contentTypes.contains { type in
                        contentType.conforms(to: type)
                    }
                    
                    if !matchesContentType {
                        return nil
                    }
                }
                
                // Create URL
                let url = URL(fileURLWithPath: item.filename)
                
                return FileItem(
                    id: itemIdentifier,
                    name: item.filename.lastPathComponent,
                    url: url,
                    size: item.documentSize as? Int64,
                    modificationDate: item.contentModificationDate,
                    creationDate: item.creationDate,
                    isDirectory: item.capabilities.contains(.allowsContentEnumerating),
                    contentType: contentType,
                    providerDomainName: domain.identifier.rawValue,
                    providerItemIdentifier: itemIdentifier,
                    parentID: item.parentItemIdentifier.rawValue as? String
                )
            }
            
            return nil
        }
    }
    
    public func createDirectory(name: String, in parent: FileItem, provider: FileProviderModel) async throws -> FileItem {
        // For local file system
        if provider.isLocal {
            let fm = FileManager.default
            let parentURL = parent.url
            let newDirectoryURL = parentURL.appendingPathComponent(name, isDirectory: true)
            
            // Check if directory already exists
            if fm.fileExists(atPath: newDirectoryURL.path) {
                throw FileProviderError.fileAlreadyExists
            }
            
            // Create the directory
            try fm.createDirectory(at: newDirectoryURL, withIntermediateDirectories: false)
            
            // Get directory attributes
            let resourceValues = try newDirectoryURL.resourceValues(forKeys: [
                .creationDateKey, .contentModificationDateKey
            ])
            
            return FileItem(
                id: newDirectoryURL.path,
                name: name,
                url: newDirectoryURL,
                size: 0,
                modificationDate: resourceValues.contentModificationDate,
                creationDate: resourceValues.creationDate,
                isDirectory: true,
                parentID: parent.id
            )
        }
        
        // For file provider domains
        // Note: Creating directories may not be supported by all file providers
        throw FileProviderError.operationNotSupported
    }
    
    public func deleteItem(_ item: FileItem, from provider: FileProviderModel) async throws {
        // For local file system
        if provider.isLocal {
            let fm = FileManager.default
            try fm.removeItem(at: item.url)
            return
        }
        
        // For file provider domains
        // Note: Deleting items may not be supported by all file providers
        throw FileProviderError.operationNotSupported
    }
    
    public func moveItem(_ item: FileItem, to destination: FileItem, provider: FileProviderModel) async throws -> FileItem {
        // For local file system
        if provider.isLocal {
            let fm = FileManager.default
            let sourceURL = item.url
            let destinationURL = destination.url.appendingPathComponent(item.name)
            
            // Check if destination already exists
            if fm.fileExists(atPath: destinationURL.path) {
                throw FileProviderError.fileAlreadyExists
            }
            
            // Move the file
            try fm.moveItem(at: sourceURL, to: destinationURL)
            
            // Get new file attributes
            let resourceValues = try destinationURL.resourceValues(forKeys: [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
            ])
            
            let contentType = UTType(filenameExtension: destinationURL.pathExtension)
            
            return FileItem(
                id: destinationURL.path,
                name: item.name,
                url: destinationURL,
                size: resourceValues.fileSize as? Int64,
                modificationDate: resourceValues.contentModificationDate,
                creationDate: resourceValues.creationDate,
                isDirectory: resourceValues.isDirectory ?? false,
                contentType: contentType,
                parentID: destination.id
            )
        }
        
        // For file provider domains
        // Note: Moving items may not be supported by all file providers
        throw FileProviderError.operationNotSupported
    }
    
    public func renameItem(_ item: FileItem, to newName: String, provider: FileProviderModel) async throws -> FileItem {
        // For local file system
        if provider.isLocal {
            let fm = FileManager.default
            let oldURL = item.url
            let parentURL = oldURL.deletingLastPathComponent()
            let newURL = parentURL.appendingPathComponent(newName)
            
            // Check if file with new name already exists
            if fm.fileExists(atPath: newURL.path) {
                throw FileProviderError.fileAlreadyExists
            }
            
            // Rename the file
            try fm.moveItem(at: oldURL, to: newURL)
            
            // Get updated file attributes
            let resourceValues = try newURL.resourceValues(forKeys: [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
            ])
            
            let contentType = UTType(filenameExtension: newURL.pathExtension)
            
            return FileItem(
                id: newURL.path,
                name: newName,
                url: newURL,
                size: resourceValues.fileSize as? Int64,
                modificationDate: resourceValues.contentModificationDate,
                creationDate: resourceValues.creationDate,
                isDirectory: resourceValues.isDirectory ?? false,
                contentType: contentType,
                parentID: parentURL.path
            )
        }
        
        // For file provider domains
        // Note: Renaming items may not be supported by all file providers
        throw FileProviderError.operationNotSupported
    }
    
    public func copyItem(_ item: FileItem, to destination: FileItem, provider: FileProviderModel) async throws -> FileItem {
        // For local file system
        if provider.isLocal {
            let fm = FileManager.default
            let sourceURL = item.url
            let destinationURL = destination.url.appendingPathComponent(item.name)
            
            // Check if destination already exists
            if fm.fileExists(atPath: destinationURL.path) {
                throw FileProviderError.fileAlreadyExists
            }
            
            // Copy the file
            try fm.copyItem(at: sourceURL, to: destinationURL)
            
            // Get new file attributes
            let resourceValues = try destinationURL.resourceValues(forKeys: [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
            ])
            
            let contentType = UTType(filenameExtension: destinationURL.pathExtension)
            
            return FileItem(
                id: destinationURL.path,
                name: item.name,
                url: destinationURL,
                size: resourceValues.fileSize as? Int64,
                modificationDate: resourceValues.contentModificationDate,
                creationDate: resourceValues.creationDate,
                isDirectory: resourceValues.isDirectory ?? false,
                contentType: contentType,
                parentID: destination.id
            )
        }
        
        // For file provider domains
        // Note: Copying items may not be supported by all file providers
        throw FileProviderError.operationNotSupported
    }
    
    public func getLocalURL(for item: FileItem, provider: FileProviderModel) async throws -> URL {
        // For local file system
        if provider.isLocal {
            // If it's already local, just return the URL
            return item.url
        }
        
        // For file provider domains
        guard let domain = provider.domain else {
            throw FileProviderError.providerNotFound
        }
        
        guard let manager = NSFileProviderManager(for: domain) else {
            throw FileProviderError.providerUnavailable
        }
        
        guard let providerItemID = item.providerItemIdentifier else {
            throw FileProviderError.fileNotFound
        }
        
        let itemIdentifier = NSFileProviderItemIdentifier(providerItemID)
        
        do {
            // Get a URL that can be used to access the file locally
            let localURL = try await manager.getUserVisibleURL(for: itemIdentifier)
            
            // Check if file exists
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: localURL.path) {
                throw FileProviderError.fileNotFound
            }
            
            return localURL
        } catch {
            throw FileProviderError.fromNSError(error as NSError)
        }
    }
    
    public func startMonitoring(_ directory: FileItem, provider: FileProviderModel) -> AnyPublisher<[FileItem], Error> {
        let subject = PassthroughSubject<[FileItem], Error>()
        directoryMonitors[directory.id] = subject
        
        // Start a polling mechanism for changes
        // This is a simplified implementation - a more robust solution would use NSFileProviderManager's signal handler
        Task {
            do {
                while directoryMonitors[directory.id] != nil {
                    // Get the current contents
                    let contents = try await getContents(of: directory, from: provider)
                    
                    // Send the contents to subscribers
                    await MainActor.run {
                        directoryMonitors[directory.id]?.send(contents)
                    }
                    
                    // Wait for a while before checking again
                    try await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5 seconds
                }
            } catch {
                await MainActor.run {
                    directoryMonitors[directory.id]?.send(completion: .failure(error))
                    directoryMonitors[directory.id] = nil
                }
            }
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    public func stopMonitoring(_ directory: FileItem, provider: FileProviderModel) {
        directoryMonitors[directory.id] = nil
    }
    
    public func synchronize(_ provider: FileProviderModel) async throws {
        // For local file system, synchronization is not applicable
        if provider.isLocal {
            return
        }
        
        // For file provider domains
        guard let domain = provider.domain else {
            throw FileProviderError.providerNotFound
        }
        
        guard let manager = NSFileProviderManager(for: domain) else {
            throw FileProviderError.providerUnavailable
        }
        
        provider.updateSyncState(isSynchronizing: true)
        
        do {
            try await manager.signalEnumerator(for: .rootContainer)
            provider.updateStatus(.available)
        } catch {
            provider.setError(error)
            throw FileProviderError.fromNSError(error as NSError)
        } finally {
            provider.updateSyncState(isSynchronizing: false)
        }
    }
}
