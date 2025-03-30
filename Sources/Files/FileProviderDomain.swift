// FileProviderDomain.swift
// Files
//
// Created on 2025-03-30.
//

import Foundation
import FileProvider
import Observation

/// Represents a file provider domain in the system
@Observable public final class FileProviderDomain: Identifiable, Hashable {
    public let id: UUID
    public let domain: NSFileProviderDomain
    public let displayName: String
    public let identifier: NSFileProviderDomainIdentifier
    public private(set) var isActive: Bool
    public private(set) var icon: Data?
    
    public init(
        id: UUID = UUID(),
        domain: NSFileProviderDomain,
        isActive: Bool = true,
        icon: Data? = nil
    ) {
        self.id = id
        self.domain = domain
        self.displayName = domain.displayName
        self.identifier = domain.identifier
        self.isActive = isActive
        self.icon = icon
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: FileProviderDomain, rhs: FileProviderDomain) -> Bool {
        lhs.id == rhs.id
    }
    
    public func activate() {
        self.isActive = true
    }
    
    public func deactivate() {
        self.isActive = false
    }
    
    public func setIcon(_ iconData: Data?) {
        self.icon = iconData
    }
}

/// Represents a file provider error with enhanced user-friendly context
public struct FileProviderError: Error, LocalizedError {
    public let underlyingError: Error
    public let domain: String
    public let code: Int
    public let affectedItem: NSFileProviderItemIdentifier?
    public let userInfo: [String: Any]?
    
    public init(error: Error) {
        self.underlyingError = error
        
        if let fileProviderError = error as? NSFileProviderError {
            self.domain = NSFileProviderErrorDomain
            self.code = fileProviderError.errorCode.rawValue
            self.affectedItem = fileProviderError.userInfo[NSFileProviderErrorItemKey] as? NSFileProviderItemIdentifier
            self.userInfo = fileProviderError.userInfo
        } else if let nsError = error as NSError {
            self.domain = nsError.domain
            self.code = nsError.code
            self.affectedItem = nsError.userInfo[NSFileProviderErrorItemKey] as? NSFileProviderItemIdentifier
            self.userInfo = nsError.userInfo
        } else {
            self.domain = "unknown"
            self.code = -1
            self.affectedItem = nil
            self.userInfo = nil
        }
    }
    
    public var errorDescription: String? {
        // Provide more user-friendly error messages based on the error code
        if domain == NSFileProviderErrorDomain {
            switch NSFileProviderError.Code(rawValue: code) {
            case .noSuchItem:
                return "The requested file or folder could not be found."
            case .itemAlreadyExists:
                return "A file or folder with this name already exists."
            case .notAuthenticated:
                return "You need to authenticate with this file provider."
            case .insufficientQuota:
                return "There is not enough storage space available."
            case .serverUnreachable:
                return "The server is currently unreachable. Please check your connection."
            case .syncAnchorExpired:
                return "Your cached data is out of date. Please refresh and try again."
            default:
                return underlyingError.localizedDescription
            }
        }
        
        return underlyingError.localizedDescription
    }
    
    public var recoverySuggestion: String? {
        if domain == NSFileProviderErrorDomain {
            switch NSFileProviderError.Code(rawValue: code) {
            case .notAuthenticated:
                return "Please sign in to your account and try again."
            case .serverUnreachable:
                return "Check your internet connection and try again."
            case .insufficientQuota:
                return "Try freeing up space or upgrading your storage plan."
            default:
                return nil
            }
        }
        
        return nil
    }
}
