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
    case nsFileProviderError(error: NSFileProviderError)
    
    // Other
    case unknown(error: Error?)
}

// MARK: - FileProviderError Extension for LocalizedError
extension FileProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .providerNotFound:
            return "The file provider was not found"
        case .providerOffline:
            return "The file provider is currently offline"
        case .providerUnavailable:
            return "The file provider is currently unavailable"
        case .providerAuthenticationRequired:
            return "Authentication required for the file provider"
        case .connectionError:
            return "Could not connect to the file provider"
            
        case .fileNotFound:
            return "The requested file was not found"
        case .fileAccessDenied:
            return "Access to the file was denied"
        case .fileAlreadyExists:
            return "A file with this name already exists"
        case .fileCorrupted:
            return "The file appears to be corrupted"
            
        case .operationFailed:
            return "The operation failed to complete"
        case .operationNotSupported:
            return "This operation is not supported by the file provider"
        case .operationCancelled:
            return "The operation was cancelled"
        case .operationTimedOut:
            return "The operation timed out"
            
        case .unsupportedFileFormat:
            return "The file format is not supported"
        case .fileTooLarge:
            return "The file is too large"
            
        case .outOfDiskSpace:
            return "There is not enough disk space available"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        case .nsFileProviderError(let error):
            return mapNSFileProviderError(error)
            
        case .unknown(let error):
            if let error = error {
                return "An unknown error occurred: \(error.localizedDescription)"
            } else {
                return "An unknown error occurred"
            }
        }
    }
    
    private func mapNSFileProviderError(_ error: NSFileProviderError) -> String {
        switch error.code {
        case NSFileProviderError.noSuchItem:
            return "The requested item doesn't exist"
        case NSFileProviderError.itemAlreadyExists:
            return "An item with this name already exists"
        case NSFileProviderError.fileTooLarge:
            return "The file is too large to be handled by the provider"
        case NSFileProviderError.syncAnchorExpired:
            return "The sync anchor has expired, please refresh"
        case NSFileProviderError.notAuthenticated:
            return "You are not authenticated with this provider"
        case NSFileProviderError.providerNotFound:
            return "The requested provider could not be found"
        case NSFileProviderError.providerTranslocated:
            return "The provider has been moved from its original location"
        case NSFileProviderError.serverUnreachable:
            return "The server is currently unreachable"
        default:
            return "File provider error: \(error.localizedDescription)"
        }
    }
}

// MARK: - FileProviderError Extension for Conversions
extension FileProviderError {
    /// Converts an NSError to a FileProviderError
    /// - Parameter error: The NSError to convert
    /// - Returns: A FileProviderError
    public static func fromNSError(_ error: NSError) -> FileProviderError {
        // Check if it's an NSFileProviderError
        if error.domain == NSFileProviderErrorDomain {
            return .nsFileProviderError(error: NSFileProviderError(_nsError: error))
        }
        
        // Handle common NSErrors
        switch error.domain {
        case NSCocoaErrorDomain:
            switch error.code {
            case NSFileNoSuchFileError:
                return .fileNotFound
            case NSFileWriteOutOfSpaceError:
                return .outOfDiskSpace
            case NSFileWriteNoPermissionError:
                return .fileAccessDenied
            default:
                break
            }
        case NSURLErrorDomain:
            switch error.code {
            case NSURLErrorNotConnectedToInternet:
                return .providerOffline
            case NSURLErrorTimedOut:
                return .operationTimedOut
            case NSURLErrorCancelled:
                return .operationCancelled
            default:
                return .connectionError
            }
        default:
            break
        }
        
        // For other errors
        return .systemError(error: error)
    }
}
