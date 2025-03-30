//
//  FileSystemService.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import Combine
import UniformTypeIdentifiers

/// Protocol for file system services
public protocol FileSystemServiceProtocol {
    /// Get a temporary URL for a file
    /// - Parameter originalURL: The original URL of the file
    /// - Returns: A temporary URL for the file
    func getTemporaryURL(for originalURL: URL) async throws -> URL
    
    /// Cache a file
    /// - Parameters:
    ///   - url: The URL of the file to cache
    ///   - identifier: A unique identifier for the file
    /// - Returns: The URL of the cached file
    func cacheFile(url: URL, identifier: String) async throws -> URL
    
    /// Check if a file is cached
    /// - Parameter identifier: The identifier of the file
    /// - Returns: True if the file is cached
    func isFileCached(identifier: String) -> Bool
    
    /// Get a cached file
    /// - Parameter identifier: The identifier of the file
    /// - Returns: The URL of the cached file, if it exists
    func getCachedFile(identifier: String) -> URL?
    
    /// Clear the file cache
    func clearCache() async throws
    
    /// Get the size of the cache
    /// - Returns: The size of the cache in bytes
    func getCacheSize() async throws -> Int64
    
    /// Set the maximum cache size
    /// - Parameter size: The maximum size in bytes
    func setMaxCacheSize(size: Int64)
    
    /// Create a directory
    /// - Parameters:
    ///   - directoryName: The name of the directory
    ///   - parentURL: The parent directory URL
    /// - Returns: The URL of the created directory
    func createDirectory(directoryName: String, parentURL: URL) async throws -> URL
    
    /// Copy a file
    /// - Parameters:
    ///   - sourceURL: The source URL
    ///   - destinationURL: The destination URL
    /// - Returns: The URL of the copied file
    func copyFile(sourceURL: URL, destinationURL: URL) async throws -> URL
    
    /// Move a file
    /// - Parameters:
    ///   - sourceURL: The source URL
    ///   - destinationURL: The destination URL
    /// - Returns: The URL of the moved file
    func moveFile(sourceURL: URL, destinationURL: URL) async throws -> URL
    
    /// Delete a file
    /// - Parameter url: The URL of the file to delete
    func deleteFile(url: URL) async throws
    
    /// Get file attributes
    /// - Parameter url: The URL of the file
    /// - Returns: The file attributes
    func getFileAttributes(url: URL) async throws -> [FileAttributeKey: Any]
    
    /// Check if a file exists
    /// - Parameter url: The URL of the file
    /// - Returns: True if the file exists
    func fileExists(url: URL) -> Bool
    
    /// Monitor a file for changes
    /// - Parameter url: The URL of the file to monitor
    /// - Returns: A publisher that emits when the file changes
    func monitorFile(url: URL) -> AnyPublisher<Void, Error>
}

/// Implementation of the FileSystemServiceProtocol
public class FileSystemService: FileSystemServiceProtocol {
    // MARK: - Properties
    
    /// Shared instance (singleton)
    public static let shared = FileSystemService()
    
    /// Maximum cache size in bytes
    private var maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB default
    
    /// File manager
    private let fileManager = FileManager.default
    
    /// Cache directory URL
    private lazy var cacheDirectoryURL: URL = {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDirectory = cachesDirectory.appendingPathComponent("com.tnir.ca.WatchTogether.FileCache")
        
        // Create the directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        return cacheDirectory
    }()
    
    /// Temporary directory URL
    private lazy var temporaryDirectoryURL: URL = {
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("com.tnir.ca.WatchTogether.TempFiles")
        
        // Create the directory if it doesn't exist
        if !fileManager.fileExists(atPath: tempDirectory.path) {
            try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        }
        
        return tempDirectory
    }()
    
    /// File monitors
    private var fileMonitors: [URL: PassthroughSubject<Void, Error>] = [:]
    
    // MARK: - Initialization
    
    /// Private initializer for singleton
    private init() {
        // Clean temporary directory on startup
        try? clearTemporaryDirectory()
        
        // Set up cache maintenance
        setupCacheMaintenance()
    }
    
    // MARK: - Public Methods
    
    public func getTemporaryURL(for originalURL: URL) async throws -> URL {
        // Create a temporary file with a unique name
        let fileName = originalURL.lastPathComponent
        let uniqueFileName = "\(UUID().uuidString)_\(fileName)"
        let temporaryURL = temporaryDirectoryURL.appendingPathComponent(uniqueFileName)
        
        // Copy the file to the temporary location
        try fileManager.copyItem(at: originalURL, to: temporaryURL)
        
        return temporaryURL
    }
    
    public func cacheFile(url: URL, identifier: String) async throws -> URL {
        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileProviderError.fileNotFound
        }
        
        // Create cache filename
        let fileExtension = url.pathExtension
        let cacheFileName = "\(identifier).\(fileExtension)"
        let cacheURL = cacheDirectoryURL.appendingPathComponent(cacheFileName)
        
        // If file is already in cache, return its URL
        if fileManager.fileExists(atPath: cacheURL.path) {
            return cacheURL
        }
        
        // Check if adding this file would exceed the cache size limit
        let fileSize = try fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let currentCacheSize = try await getCacheSize()
        
        if currentCacheSize + fileSize > maxCacheSize {
            // Need to free up space
            try await trimCache(neededSpace: fileSize)
        }
        
        // Copy file to cache
        try fileManager.copyItem(at: url, to: cacheURL)
        
        return cacheURL
    }
    
    public func isFileCached(identifier: String) -> Bool {
        // Check if any file with this identifier exists in the cache
        do {
            let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: nil)
            return cacheContents.contains { $0.lastPathComponent.hasPrefix(identifier) }
        } catch {
            return false
        }
    }
    
    public func getCachedFile(identifier: String) -> URL? {
        do {
            let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: nil)
            let matchingFiles = cacheContents.filter { $0.lastPathComponent.hasPrefix(identifier) }
            
            return matchingFiles.first
        } catch {
            return nil
        }
    }
    
    public func clearCache() async throws {
        // Get all files in the cache directory
        let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: nil)
        
        // Delete each file
        for fileURL in cacheContents {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    public func getCacheSize() async throws -> Int64 {
        // Get all files in the cache directory
        let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: [.fileSizeKey])
        
        // Sum up the file sizes
        var totalSize: Int64 = 0
        for fileURL in cacheContents {
            let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(attributes.fileSize ?? 0)
        }
        
        return totalSize
    }
    
    public func setMaxCacheSize(size: Int64) {
        maxCacheSize = size
        
        // Trim cache if necessary
        Task {
            try await trimCacheIfNeeded()
        }
    }
    
    public func createDirectory(directoryName: String, parentURL: URL) async throws -> URL {
        let directoryURL = parentURL.appendingPathComponent(directoryName, isDirectory: true)
        
        // Check if directory already exists
        if fileManager.fileExists(atPath: directoryURL.path) {
            throw FileProviderError.fileAlreadyExists
        }
        
        // Create the directory
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        
        return directoryURL
    }
    
    public func copyFile(sourceURL: URL, destinationURL: URL) async throws -> URL {
        // Check if source file exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw FileProviderError.fileNotFound
        }
        
        // Check if destination already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw FileProviderError.fileAlreadyExists
        }
        
        // Copy the file
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        return destinationURL
    }
    
    public func moveFile(sourceURL: URL, destinationURL: URL) async throws -> URL {
        // Check if source file exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw FileProviderError.fileNotFound
        }
        
        // Check if destination already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw FileProviderError.fileAlreadyExists
        }
        
        // Move the file
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        
        return destinationURL
    }
    
    public func deleteFile(url: URL) async throws {
        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileProviderError.fileNotFound
        }
        
        // Delete the file
        try fileManager.removeItem(at: url)
    }
    
    public func getFileAttributes(url: URL) async throws -> [FileAttributeKey: Any] {
        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileProviderError.fileNotFound
        }
        
        // Get file attributes
        return try fileManager.attributesOfItem(atPath: url.path)
    }
    
    public func fileExists(url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    public func monitorFile(url: URL) -> AnyPublisher<Void, Error> {
        // If already monitoring this file, return the existing publisher
        if let subject = fileMonitors[url] {
            return subject.eraseToAnyPublisher()
        }
        
        // Create a new subject
        let subject = PassthroughSubject<Void, Error>()
        fileMonitors[url] = subject
        
        // Start monitoring the file using a dispatch source
        do {
            let fileDescriptor = open(url.path, O_EVTONLY)
            if fileDescriptor < 0 {
                subject.send(completion: .failure(FileProviderError.fileNotFound))
                return subject.eraseToAnyPublisher()
            }
            
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .delete, .rename, .extend],
                queue: DispatchQueue.global()
            )
            
            source.setEventHandler {
                subject.send()
            }
            
            source.setCancelHandler {
                close(fileDescriptor)
            }
            
            source.resume()
        } catch {
            subject.send(completion: .failure(error))
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    /// Clears the temporary directory
    private func clearTemporaryDirectory() throws {
        let tempContents = try fileManager.contentsOfDirectory(at: temporaryDirectoryURL, includingPropertiesForKeys: nil)
        
        for fileURL in tempContents {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Sets up cache maintenance
    private func setupCacheMaintenance() {
        // Run cache maintenance every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task {
                try await self?.trimCacheIfNeeded()
            }
        }
    }
    
    /// Trims the cache if it exceeds the maximum size
    private func trimCacheIfNeeded() async throws {
        let currentSize = try await getCacheSize()
        
        if currentSize > maxCacheSize {
            try await trimCache(neededSpace: currentSize - maxCacheSize)
        }
    }
    
    /// Trims the cache to free up space
    /// - Parameter neededSpace: The amount of space to free up
    private func trimCache(neededSpace: Int64) async throws {
        // Get all files in the cache directory with their access time
        let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey])
        
        // Sort files by access time (oldest first)
        let sortedFiles = try cacheContents.map { url -> (URL, Date, Int64) in
            let attributes = try url.resourceValues(forKeys: [.contentAccessDateKey, .fileSizeKey])
            let accessDate = attributes.contentAccessDate ?? Date.distantPast
            let fileSize = Int64(attributes.fileSize ?? 0)
            return (url, accessDate, fileSize)
        }.sorted { $0.1 < $1.1 }
        
        // Remove files until we've freed up enough space
        var freedSpace: Int64 = 0
        for (url, _, fileSize) in sortedFiles {
            if freedSpace >= neededSpace {
                break
            }
            
            try fileManager.removeItem(at: url)
            freedSpace += fileSize
        }
    }
}
