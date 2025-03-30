// FileProviderService.swift
// Files
//
// Created on 2025-03-30.
//

import Foundation
import FileProvider
import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "tnir.ca.WatchTogether.Files", category: "FileProviderService")

/// Service to interact with the file provider system
public actor FileProviderService {
    public static let shared = FileProviderService()
    
    private var domainNotificationToken: NSObjectProtocol?
    private var materializedSetToken: NSObjectProtocol?
    private var pendingSetToken: NSObjectProtocol?
    
    private var activeDomainManagers: [NSFileProviderDomainIdentifier: NSFileProviderManager] = [:]
    private let defaultManager = NSFileProviderManager.default
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        removeNotifications()
    }
    
    private func setupNotifications() {
        domainNotificationToken = NotificationCenter.default.addObserver(forName: NSFileProviderDomainDidChange, object: nil, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            Task {
                await self.handleDomainChange(notification)
            }
        }
        
        materializedSetToken = NotificationCenter.default.addObserver(forName: NSFileProviderMaterializedSetDidChange, object: nil, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            Task {
                await self.handleMaterializedSetChange(notification)
            }
        }
        
        pendingSetToken = NotificationCenter.default.addObserver(forName: NSFileProviderPendingSetDidChange, object: nil, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            Task {
                await self.handlePendingSetChange(notification)
            }
        }
    }
    
    private func removeNotifications() {
        if let token = domainNotificationToken {
            NotificationCenter.default.removeObserver(token)
        }
        
        if let token = materializedSetToken {
            NotificationCenter.default.removeObserver(token)
        }
        
        if let token = pendingSetToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    private func handleDomainChange(_ notification: Notification) {
        // Clear cached managers when domains change
        activeDomainManagers.removeAll()
        logger.info("File provider domains changed")
    }
    
    private func handleMaterializedSetChange(_ notification: Notification) {
        logger.debug("File provider materialized set changed")
    }
    
    private func handlePendingSetChange(_ notification: Notification) {
        logger.debug("File provider pending set changed")
    }
    
    // MARK: - Domain Management
    
    /// Get all available file provider domains in the system
    public func getDomains() async throws -> [FileProviderDomain] {
        do {
            let domains = try await NSFileProviderManager.domains()
            
            return domains.map { domain in
                FileProviderDomain(domain: domain)
            }
        } catch {
            logger.error("Failed to retrieve file provider domains: \(error.localizedDescription)")
            throw FileProviderError(error: error)
        }
    }
    
    /// Get a manager for the specified domain
    private func getManager(for domain: FileProviderDomain) throws -> NSFileProviderManager {
        if let existingManager = activeDomainManagers[domain.identifier] {
            return existingManager
        }
        
        do {
            let manager = NSFileProviderManager(for: domain.domain) ?? defaultManager
            activeDomainManagers[domain.identifier] = manager
            return manager
        } catch {
            logger.error("Failed to create manager for domain \(domain.displayName): \(error.localizedDescription)")
            throw FileProviderError(error: error)
        }
    }
    
    // MARK: - Item Retrieval
    
    /// List items in a directory
    public func listItems(in parentItem: FileItem? = nil, domain: FileProviderDomain) async throws -> [FileItem] {
        do {
            let manager = try getManager(for: domain)
            
            // Determine the parent identifier
            let parentIdentifier = parentItem?.itemIdentifier ?? .rootContainer
            
            let itemIdentifiers = try await withCheckedThrowingContinuation { continuation in
                manager.enumerator(for: parentIdentifier) { enumerator in
                    var identifiers = [NSFileProviderItemIdentifier]()
                    
                    func getNext() {
                        enumerator.enumerateItems { items, error in
                            if let error = error {
                                continuation.resume(throwing: FileProviderError(error: error))
                                return
                            }
                            
                            if items.isEmpty {
                                // Enumeration complete
                                continuation.resume(returning: identifiers)
                                return
                            }
                            
                            identifiers.append(contentsOf: items.map { $0.itemIdentifier })
                            getNext()
                        }
                    }
                    
                    getNext()
                }
            }
            
            // Get item details for each identifier
            var fileItems = [FileItem]()
            
            for identifier in itemIdentifiers {
                do {
                    let item = try await manager.item(for: identifier)
                    let parentPath = parentItem?.path ?? ""
                    let fileItem = FileItem(providerItem: item, domainIdentifier: domain.identifier, parentPath: parentPath)
                    fileItems.append(fileItem)
                } catch {
                    logger.warning("Skipping item \(identifier.rawValue): \(error.localizedDescription)")
                    // Continue with the next item instead of failing the entire operation
                    continue
                }
            }
            
            return fileItems
        } catch {
            logger.error("Failed to list items: \(error.localizedDescription)")
            throw FileProviderError(error: error)
        }
    }
    
    /// Get a URL for a file that can be used to access its contents
    public func getURL(for item: FileItem) async throws -> URL {
        do {
            let manager = try getManager(for: FileProviderDomain(domain: NSFileProviderDomain(identifier: item.domainIdentifier, displayName: "")))
            
            let url = try await manager.urlForItem(withPersistentIdentifier: item.itemIdentifier)
            // Start coordinated access
            try await startAccessing(url: url)
            
            // Update the item's URL
            item.url = url
            return url
        } catch {
            logger.error("Failed to get URL for item \(item.filename): \(error.localizedDescription)")
            throw FileProviderError(error: error)
        }
    }
    
    /// Start coordinated file access for a URL
    private func startAccessing(url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // Use file coordination for reliable file access
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinatorError: NSError?
            
            coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinatorError) { accessURL in
                do {
                    // Start accessing security-scoped resource if needed
                    let granted = accessURL.startAccessingSecurityScopedResource()
                    if granted {
                        logger.debug("Successfully started accessing security-scoped resource at \(accessURL.path)")
                    }
                    continuation.resume(returning: ())
                } catch {
                    logger.error("Failed to start accessing URL \(url.path): \(error.localizedDescription)")
                    continuation.resume(throwing: FileProviderError(error: error))
                }
            }
            
            if let error = coordinatorError {
                logger.error("Coordination error accessing \(url.path): \(error.localizedDescription)")
                continuation.resume(throwing: FileProviderError(error: error))
            }
        }
    }
    
    /// Stop accessing a file URL when done
    public func stopAccessing(url: URL) {
        url.stopAccessingSecurityScopedResource()
        logger.debug("Stopped accessing security-scoped resource at \(url.path)")
    }
    
    // MARK: - Thumbnails
    
    /// Get a thumbnail for a file item if available
    public func getThumbnail(for item: FileItem, size: CGSize = CGSize(width: 300, height: 300)) async throws -> URL? {
        do {
            let manager = try getManager(for: FileProviderDomain(domain: NSFileProviderDomain(identifier: item.domainIdentifier, displayName: "")))
            
            // Check if we can generate a thumbnail
            guard !item.isDirectory, item.fileType?.conforms(to: .image) == true || item.fileType?.conforms(to: .audiovisualContent) == true else {
                return nil
            }
            
            let thumbnailURL = try await manager.thumbnailURL(for: item.itemIdentifier, size: size)
            item.thumbnailURL = thumbnailURL
            return thumbnailURL
        } catch {
            logger.warning("Failed to get thumbnail for \(item.filename): \(error.localizedDescription)")
            // Not returning an error since thumbnails are optional
            return nil
        }
    }
}
