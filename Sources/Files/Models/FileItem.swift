//
//  FileItem.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import UniformTypeIdentifiers

/// A model representing a file or directory in the file system
public struct FileItem: Identifiable, Hashable {
    /// Unique identifier for the file
    public let id: String
    
    /// Display name of the file
    public let name: String
    
    /// Full URL to the file
    public let url: URL
    
    /// File size in bytes
    public let size: Int64?
    
    /// Date when the file was last modified
    public let modificationDate: Date?
    
    /// Date when the file was created
    public let creationDate: Date?
    
    /// Indicates if the item is a directory
    public let isDirectory: Bool
    
    /// UTType of the file
    public let contentType: UTType?
    
    /// File provider domain name, if applicable
    public let providerDomainName: String?
    
    /// File provider item identifier, if applicable
    public let providerItemIdentifier: String?
    
    /// Parent directory identifier
    public let parentID: String?
    
    /// Convenience property to check if the file is a video
    public var isVideo: Bool {
        guard let contentType = contentType else { return false }
        return contentType.conforms(to: .movie) || contentType.conforms(to: .video)
    }
    
    /// Convenience property to check if the file is an audio file
    public var isAudio: Bool {
        guard let contentType = contentType else { return false }
        return contentType.conforms(to: .audio)
    }
    
    /// Convenience property to check if the file is an image
    public var isImage: Bool {
        guard let contentType = contentType else { return false }
        return contentType.conforms(to: .image)
    }
    
    /// Formatted file size string (e.g., "1.2 MB")
    public var formattedSize: String {
        guard let size = size else { return "Unknown size" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Initializes a new FileItem
    /// - Parameters:
    ///   - id: Unique identifier for the file
    ///   - name: Display name of the file
    ///   - url: Full URL to the file
    ///   - size: File size in bytes
    ///   - modificationDate: Date when the file was last modified
    ///   - creationDate: Date when the file was created
    ///   - isDirectory: Indicates if the item is a directory
    ///   - contentType: UTType of the file
    ///   - providerDomainName: File provider domain name
    ///   - providerItemIdentifier: File provider item identifier
    ///   - parentID: Parent directory identifier
    public init(
        id: String,
        name: String,
        url: URL,
        size: Int64? = nil,
        modificationDate: Date? = nil,
        creationDate: Date? = nil,
        isDirectory: Bool = false,
        contentType: UTType? = nil,
        providerDomainName: String? = nil,
        providerItemIdentifier: String? = nil,
        parentID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.size = size
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.isDirectory = isDirectory
        self.contentType = contentType
        self.providerDomainName = providerDomainName
        self.providerItemIdentifier = providerItemIdentifier
        self.parentID = parentID
    }
    
    // Conformance to Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Conformance to Equatable
    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FileItem Extension for Codable
extension FileItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, url, size, modificationDate, creationDate, isDirectory
        case contentType, providerDomainName, providerItemIdentifier, parentID
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(URL.self, forKey: .url)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        modificationDate = try container.decodeIfPresent(Date.self, forKey: .modificationDate)
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        providerDomainName = try container.decodeIfPresent(String.self, forKey: .providerDomainName)
        providerItemIdentifier = try container.decodeIfPresent(String.self, forKey: .providerItemIdentifier)
        parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        
        // Decode UTType from string identifier
        if let typeString = try container.decodeIfPresent(String.self, forKey: .contentType) {
            contentType = UTType(typeString)
        } else {
            contentType = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(modificationDate, forKey: .modificationDate)
        try container.encodeIfPresent(creationDate, forKey: .creationDate)
        try container.encode(isDirectory, forKey: .isDirectory)
        try container.encodeIfPresent(providerDomainName, forKey: .providerDomainName)
        try container.encodeIfPresent(providerItemIdentifier, forKey: .providerItemIdentifier)
        try container.encodeIfPresent(parentID, forKey: .parentID)
        
        // Encode UTType as string identifier
        try container.encodeIfPresent(contentType?.identifier, forKey: .contentType)
    }
}
