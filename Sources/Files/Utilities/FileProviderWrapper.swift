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
    
    /// Cache for file provider items to avoid repeated fetches
    private var itemCache: [NSFileProviderItemIdentifier: NSFileProviderItem] = [:]
    
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
    
    /// Gets the root container of the file provider
    /// - Returns: The root container item
    public func getRootContainer() async throws -> NSFileProviderItem {
        return try await getItem(for: .rootContainer)
    }
    
    /// Gets an item by its identifier
    /// - Parameter identifier: The item identifier
    /// - Returns: The item
    public func getItem(for identifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
        // Check cache first
        if let cachedItem = itemCache[identifier] {
            return cachedItem
        }
        
        // Fetch the item
        do {
            let item = try await manager.item(for: identifier)
            
            // Cache the item for future use
            itemCache[identifier] = item
            
            return item
        } catch {
            throw FileProviderError.fromNSError(error as NSError)
        }
    }
    
    /// Gets the contents of a directory
    /// - Parameter identifier: The identifier of the directory
    /// - Returns: The contents of the directory
    public func getContents(of identifier: NSFileProviderItemIdentifier) async throws -> [NSFileProviderItem] {
        let enumerator = try await manager.enumerator(for: identifier)
        return try await enumerator.items()
    }
    
    /// Gets a URL for an item
    /// - Parameter identifier: The identifier of the item
    /// - Returns: The URL
    public func getURL(for identifier: NSFileProviderItemIdentifier) async throws -> URL {
        do {
            return try await manager.getUserVisibleURL(for: identifier)
        } catch {
            throw FileProviderError.fromNSError(error as NSError)
        }
    }
    
    /// Gets the working set of the file provider
    /// - Returns: The working set items
    public func getWorkingSet() async throws -> [NSFileProviderItem] {
        let enumerator = try await manager.enumerator(for: .workingSet)
        return try await enumerator.items()
    }
    
    /// Gets recently accessed items
    /// - Returns: The recently accessed items
    public func getRecentItems() async throws -> [NSFileProviderItem] {
        let workingSet = try await getWorkingSet()
        
        // Sort the working set by access date
        return workingSet.sorted { item1, item2 in
            let date1 = item1.contentModificationDate ?? Date.distantPast
            let date2 = item2.contentModificationDate ?? Date.distantPast
            return date1 > date2
        }
    }
    
    /// Gets favorite items
    /// - Returns: The favorite items
    public func getFavoriteItems() async throws -> [NSFileProviderItem] {
        let enumerator = try await manager.enumerator(for: .favorites)
        return try await enumerator.items()
    }
    
    /// Gets shared items
    /// - Returns: The shared items
    public func getSharedItems() async throws -> [NSFileProviderItem] {
        let enumerator = try await manager.enumerator(for: .shared)
        return try await enumerator.items()
    }
    
    /// Searches for items matching a query
    /// - Parameter query: The search query
    /// - Returns: The matching items
    public func search(query: String) async throws -> [NSFileProviderItem] {
        // This is a simplified implementation since not all providers support search
        // In a real app, you'd want to use the FileProvider search APIs
        
        let allItems = try await searchRecursively(from: .rootContainer, query: query.lowercased())
        return allItems
    }
    
    /// Synchronizes the provider
    public func synchronize() async throws {
        do {
            try await manager.signalEnumerator(for: .rootContainer)
        } catch {
            throw FileProviderError.fromNSError(error as NSError)
        }
    }
    
    /// Creates a file item from an NSFileProviderItem
    /// - Parameter item: The NSFileProviderItem
    /// - Returns: A FileItem
    public func createFileItem(from item: NSFileProviderItem) async throws -> FileItem {
        let url: URL
        
        do {
            url = try await manager.getUserVisibleURL(for: item.itemIdentifier)
        } catch {
            // If we can't get a real URL, create a placeholder
            url = URL(fileURLWithPath: item.filename)
        }
        
        // Get content type based on filename
        let contentType = UTType(filenameExtension: url.pathExtension)
        
        return FileItem(
            id: item.itemIdentifier.rawValue as? String ?? UUID().uuidString,
            name: item.filename.lastPathComponent,
            url: url,
            size: item.documentSize as? Int64,
            modificationDate: item.contentModificationDate,
            creationDate: item.creationDate,
            isDirectory: item.capabilities.contains(.allowsContentEnumerating),
            contentType: contentType,
            providerDomainName: domain.identifier.rawValue,
            providerItemIdentifier: item.itemIdentifier.rawValue as? String,
            parentID: item.parentItemIdentifier.rawValue as? String
        )
    }
    
    /// Converts a list of NSFileProviderItems to FileItems
    /// - Parameter items: The NSFileProviderItems to convert
    /// - Returns: An array of FileItems
    public func createFileItems(from items: [NSFileProviderItem]) async throws -> [FileItem] {
        var fileItems: [FileItem] = []
        
        for item in items {
            do {
                let fileItem = try await createFileItem(from: item)
                fileItems.append(fileItem)
            } catch {
                // Skip items that can't be converted
                continue
            }
        }
        
        return fileItems
    }
    
    // MARK: - Private Methods
    
    /// Searches recursively for items matching a query
    /// - Parameters:
    ///   - parentIdentifier: The parent identifier to start searching from
    ///   - query: The search query
    /// - Returns: The matching items
    private func searchRecursively(from parentIdentifier: NSFileProviderItemIdentifier, query: String) async throws -> [NSFileProviderItem] {
        var results: [NSFileProviderItem] = []
        
        // Get items in the current directory
        let items = try await getContents(of: parentIdentifier)
        
        for item in items {
            // Check if this item matches the query
            if item.filename.lowercased().contains(query) {
                results.append(item)
            }
            
            // If this is a directory, search it too
            if item.capabilities.contains(.allowsContentEnumerating) {
                let subResults = try await searchRecursively(from: item.itemIdentifier, query: query)
                results.append(contentsOf: subResults)
            }
        }
        
        return results
    }
}
