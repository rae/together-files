//
//  FileProviderModel.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import FileProvider
import Observation

/// A model representing a file provider domain or service
@Observable public class FileProviderModel: Identifiable {
    /// Unique identifier for the provider
    public let id: String
    
    /// Name of the file provider
    public let name: String
    
    /// Display name for the provider
    public let displayName: String
    
    /// Icon or image name for the provider
    public let iconName: String
    
    /// Indicates if this is a local file system provider
    public let isLocal: Bool
    
    /// The associated file provider domain, if available
    public let domain: NSFileProviderDomain?
    
    /// Current status of the provider
    public private(set) var status: ProviderStatus = .unknown
    
    /// Last encountered error
    public private(set) var lastError: Error?
    
    /// Date of last synchronization
    public private(set) var lastSyncDate: Date?
    
    /// Indicates if the provider is currently synchronizing
    public private(set) var isSynchronizing: Bool = false
    
    /// Initializes a new FileProviderModel
    /// - Parameters:
    ///   - id: Unique identifier for the provider
    ///   - name: Name of the file provider
    ///   - displayName: Display name for the provider
    ///   - iconName: Icon or image name
    ///   - isLocal: Indicates if this is a local file system provider
    ///   - domain: The associated file provider domain, if available
    public init(
        id: String,
        name: String,
        displayName: String,
        iconName: String,
        isLocal: Bool = false,
        domain: NSFileProviderDomain? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.iconName = iconName
        self.isLocal = isLocal
        self.domain = domain
    }
    
    /// Updates the provider status
    /// - Parameter newStatus: The new status
    public func updateStatus(_ newStatus: ProviderStatus) {
        self.status = newStatus
    }
    
    /// Sets the last error that occurred
    /// - Parameter error: The error that occurred
    public func setError(_ error: Error) {
        self.lastError = error
        self.status = .error
    }
    
    /// Updates the sync state
    /// - Parameter isSynchronizing: Whether the provider is currently synchronizing
    public func updateSyncState(isSynchronizing: Bool) {
        self.isSynchronizing = isSynchronizing
        if !isSynchronizing {
            self.lastSyncDate = Date()
        }
    }
    
    /// Represents the status of a file provider
    public enum ProviderStatus: String {
        case available = "Available"
        case connecting = "Connecting"
        case offline = "Offline"
        case error = "Error"
        case unauthorized = "Unauthorized"
        case unknown = "Unknown"
    }
}

// MARK: - FileProviderModel Extension for Equatable
extension FileProviderModel: Equatable {
    public static func == (lhs: FileProviderModel, rhs: FileProviderModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FileProviderModel Extension for Hashable
extension FileProviderModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
