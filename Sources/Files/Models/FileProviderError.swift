//
//  FileProviderError.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import FileProvider

/// Represents errors that can occur when working with file providers
public enum FileProviderError: Error {
    // Provider-level errors
    case providerNotFound
    case providerOffline
    case providerUnavailable
    case providerAuthenticationRequired
    case connectionError
    
    // File-level errors
    case fileNotFound
    case fileAccessDenied
    case fileAlreadyExists
    case fileCorrupted
    
    // Operation errors
    case operationFailed
    case operationNotSupported
    case operationCancelled
    case operationTimedOut
    
    // Content errors
    case unsupportedFileFormat
    case fileTooLarge
    
    // System errors
    case outOfDiskSpace
    case systemError(error: Error)
    case nsFileProviderError(code: Int, description: String)
    
    // Other
    case unknown(error: Error?)
    
    // MARK: - LocalizedError Implementation
    
    public var errorDescription: String? {
        switch self {
        case .providerNotFound: "The file provider was not found"
        case .providerOffline: "The file provider is currently offline"
        case .providerUnavailable: "The file provider is currently unavailable"
        case .providerAuthenticationRequired: "Authentication required for the file provider"
        case .connectionError: "Could not connect to the file provider"
            
        case .fileNotFound: "The requested file was not found"
        case .fileAccessDenied: "Access to the file was denied"
        case .fileAlreadyExists: "A file with this name already exists"
        case .fileCorrupted: "The file appears to be corrupted"
            
        case .operationFailed: "The operation failed to complete"
        case .operationNotSupported: "This operation is not supported by the file provider"
        case .operationCancelled: "The operation was cancelled"
        case .operationTimedOut: "The operation timed out"
            
        case .unsupportedFileFormat: "The file format is not supported"
        case .fileTooLarge: "The file is too large"
            
        case .outOfDiskSpace: "There is not enough disk space available"
        case .systemError(let error): "System error: \(error.localizedDescription)"
        case .nsFileProviderError(_, let description): description
            
        case .unknown(let error):
            if let error = error {
                "An unknown error occurred: \(error.localizedDescription)"
            } else {
                "An unknown error occurred"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Maps an NSFileProviderError code to a descriptive string
    private static func mapNSFileProviderErrorCode(_ code: Int) -> String {
        // Using the numeric codes since the enum cases seem to be unavailable
        switch code {
        case 0: "The requested item doesn't exist"                     // NSFileProviderError.noSuchItem
        case 1: "An item with this name already exists"                // NSFileProviderError.itemAlreadyExists
        case 2: "The file is too large to be handled by the provider"  // NSFileProviderError.fileTooLarge
        case 3: "The sync anchor has expired, please refresh"          // NSFileProviderError.syncAnchorExpired
        case 4: "You are not authenticated with this provider"         // NSFileProviderError.notAuthenticated
        case 5: "The requested provider could not be found"            // NSFileProviderError.providerNotFound
        case 6: "The provider has been moved from its original location" // NSFileProviderError.providerTranslocated
        case 7: "The server is currently unreachable"                  // NSFileProviderError.serverUnreachable
        default: "File provider error: Code \(code)"
        }
    }
    
    /// Converts an NSError to a FileProviderError
    /// - Parameter error: The NSError to convert
    /// - Returns: A FileProviderError
    public static func fromNSError(_ error: NSError) -> FileProviderError {
        // Check if it's an NSFileProviderError
        if error.domain == NSFileProviderErrorDomain {
            return .nsFileProviderError(
                code: error.code,
                description: mapNSFileProviderErrorCode(error.code)
            )
        }
        
        // Handle common NSErrors
        switch error.domain {
        case NSCocoaErrorDomain:
            switch error.code {
            case NSFileNoSuchFileError: return .fileNotFound
            case NSFileWriteOutOfSpaceError: return .outOfDiskSpace
            case NSFileWriteNoPermissionError: return .fileAccessDenied
            default: break
            }
        case NSURLErrorDomain:
            switch error.code {
            case NSURLErrorNotConnectedToInternet: return .providerOffline
            case NSURLErrorTimedOut: return .operationTimedOut
            case NSURLErrorCancelled: return .operationCancelled
            default: return .connectionError
            }
        default: break
        }
        
        // For other errors
        return .systemError(error: error)
    }
}
