// FileItem.swift
// Files
//
// Created on 2025-03-30.
//

import Foundation
import FileProvider
import Observation
import UniformTypeIdentifiers

/// Represents a file or directory in the file system
@Observable public final class FileItem: Identifiable, Hashable {
    public let id: UUID
    public let itemIdentifier: NSFileProviderItemIdentifier
    public let filename: String
    public let path: String
    public let isDirectory: Bool
    public let fileType: UTType?
    public let size: Int64
    public let creationDate: Date?
    public let modificationDate: Date?
    public let domainIdentifier: NSFileProviderDomainIdentifier
    public var url: URL?
    public var thumbnailURL: URL?
    public private(set) var isLoading: Bool = false
    
    public init(
        id: UUID = UUID(),
        itemIdentifier: NSFileProviderItemIdentifier,
        filename: String,
        path: String,
        isDirectory: Bool,
        fileType: UTType?,
        size: Int64,
        creationDate: Date?,
        modificationDate: Date?,
        domainIdentifier: NSFileProviderDomainIdentifier,
        url: URL? = nil,
        thumbnailURL: URL? = nil
    ) {
        self.id = id
        self.itemIdentifier = itemIdentifier
        self.filename = filename
        self.path = path
        self.isDirectory = isDirectory
        self.fileType = fileType
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.domainIdentifier = domainIdentifier
        self.url = url
        self.thumbnailURL = thumbnailURL
    }
    
    // Create from NSFileProviderItem
    public convenience init(providerItem: NSFileProviderItem, domainIdentifier: NSFileProviderDomainIdentifier, parentPath: String) {
        let itemIdentifier = providerItem.itemIdentifier
        let filename = providerItem.filename
        let path = parentPath.isEmpty ? filename : "\(parentPath)/\(filename)"
        
        let contentType = providerItem.contentType ?? UTType.item
        let isDirectory = contentType.conforms(to: .folder) || contentType.conforms(to: .directory)
        
        self.init(
            itemIdentifier: itemIdentifier,
            filename: filename,
            path: path,
            isDirectory: isDirectory,
            fileType: contentType,
            size: providerItem.documentSize ?? 0,
            creationDate: providerItem.creationDate,
            modificationDate: providerItem.contentModificationDate,
            domainIdentifier: domainIdentifier
        )
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - File Operations
    
    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }
    
    // Format file size for display
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // Determine if file is a playable video
    public var isPlayableVideo: Bool {
        guard !isDirectory, let fileType = fileType else { return false }
        return fileType.conforms(to: .movie) ||
               fileType.conforms(to: .video) ||
               fileType.conforms(to: .audiovisualContent)
    }
}
