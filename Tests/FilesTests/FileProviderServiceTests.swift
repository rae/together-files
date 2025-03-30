//
//  FileProviderServiceTests.swift
//  FilesTests
//
//  Created by Claude on 2025-03-30.
//

import XCTest
import FileProvider
import Combine
import UniformTypeIdentifiers
@testable import Files

final class FileProviderServiceTests: XCTestCase {
    // The service to test
    var service: FileProviderService!
    
    // A mock file manager for testing
    var mockFileManager: MockFileManager!
    
    // Test URLs
    let testDirectoryURL = URL(fileURLWithPath: "/test/directory")
    let testFileURL = URL(fileURLWithPath: "/test/directory/test_file.mp4")
    
    // Test file provider models
    var localProvider: FileProviderModel!
    var cloudProvider: FileProviderModel!
    
    // Test file items
    var directoryItem: FileItem!
    var fileItem: FileItem!
    
    // Cancellables for async tests
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        // Set up a mock service for testing
        service = FileProviderService.shared
        
        // Set up test providers
        localProvider = FileProviderModel(
            id: "test.local",
            name: "TestLocal",
            displayName: "Test Local Provider",
            iconName: "folder",
            isLocal: true
        )
        
        // Create a mock domain for testing
        let mockDomain = MockFileProviderDomain(
            identifier: NSFileProviderDomainIdentifier("test.cloud"),
            displayName: "Test Cloud Provider"
        )
        
        cloudProvider = FileProviderModel(
            id: "test.cloud",
            name: "TestCloud",
            displayName: "Test Cloud Provider",
            iconName: "cloud",
            isLocal: false,
            domain: mockDomain
        )
        
        // Set up test file items
        directoryItem = FileItem(
            id: "/test/directory",
            name: "directory",
            url: testDirectoryURL,
            size: nil,
            modificationDate: Date(),
            creationDate: Date(),
            isDirectory: true,
            contentType: nil,
            parentID: "/test"
        )
        
        fileItem = FileItem(
            id: "/test/directory/test_file.mp4",
            name: "test_file.mp4",
            url: testFileURL,
            size: 1024 * 1024, // 1 MB
            modificationDate: Date(),
            creationDate: Date(),
            isDirectory: false,
            contentType: .movie,
            parentID: "/test/directory"
        )
    }
    
    override func tearDown() {
        service = nil
        localProvider = nil
        cloudProvider = nil
        directoryItem = nil
        fileItem = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testGetProviders() async throws {
        // Test getting providers
        let providers = try await service.getProviders()
        
        // Should at least have a local provider
        XCTAssertFalse(providers.isEmpty)
        XCTAssertTrue(providers.contains { $0.isLocal })
    }
    
    func testGetContentsOfDirectoryForLocalProvider() async throws {
        // Create a temporary directory for testing
        let tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("FileProviderServiceTests", isDirectory: true)
        
        // Clean up from previous runs
        if FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        
        // Create the directory and test files
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        
        let testFile1 = tempDirectoryURL.appendingPathComponent("testfile1.txt")
        let testFile2 = tempDirectoryURL.appendingPathComponent("testfile2.mp4")
        
        try "Test content 1".write(to: testFile1, atomically: true, encoding: .utf8)
        try "Test content 2".write(to: testFile2, atomically: true, encoding: .utf8)
        
        // Create a directory item for the temp directory
        let tempDirItem = FileItem(
            id: tempDirectoryURL.path,
            name: tempDirectoryURL.lastPathComponent,
            url: tempDirectoryURL,
            isDirectory: true
        )
        
        // Get directory contents
        let contents = try await service.getContents(of: tempDirItem, from: localProvider)
        
        // Clean up
        try FileManager.default.removeItem(at: tempDirectoryURL)
        
        // Assertions
        XCTAssertEqual(contents.count, 2)
        XCTAssertTrue(contents.contains { $0.name == "testfile1.txt" })
        XCTAssertTrue(contents.contains { $0.name == "testfile2.mp4" })
    }
    
    func testSearchFiles() async throws {
        // Create a temporary directory for testing
        let tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("FileProviderServiceTests", isDirectory: true)
        
        // Clean up from previous runs
        if FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        
        // Create the directory and test files
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        
        let testFile1 = tempDirectoryURL.appendingPathComponent("searchable.txt")
        let testFile2 = tempDirectoryURL.appendingPathComponent("not_matching.mp4")
        
        try "Test content 1".write(to: testFile1, atomically: true, encoding: .utf8)
        try "Test content 2".write(to: testFile2, atomically: true, encoding: .utf8)
        
        // Search for files matching "search"
        let results = try await service.searchFiles(query: "search", in: localProvider, contentTypes: nil)
        
        // Clean up
        try FileManager.default.removeItem(at: tempDirectoryURL)
        
        // Assertions - this will find all files in the system with "search" in the name,
        // but should at least include our test file
        XCTAssertTrue(results.contains { $0.name == "searchable.txt" })
        XCTAssertFalse(results.contains { $0.name == "not_matching.mp4" })
    }
}

// MARK: - Mock Classes for Testing

class MockFileProviderDomain: NSFileProviderDomain {
    convenience init(identifier: NSFileProviderDomainIdentifier, displayName: String) {
        self.init()
        setValue(identifier, forKey: "identifier")
        setValue(displayName, forKey: "displayName")
    }
}

class MockFileManager: FileManager {
    var existsFiles: [String: Bool] = [:]
    var contents: [URL: [URL]] = [:]
    var attributes: [String: [FileAttributeKey: Any]] = [:]
    
    override func fileExists(atPath path: String) -> Bool {
        return existsFiles[path] ?? false
    }
    
    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        if let exists = existsFiles[path] {
            // Look up if this is a directory in our attributes
            if let attrs = attributes[path], let isDir = attrs[.type] as? FileAttributeType, isDir == .typeDirectory {
                isDirectory?.pointee = ObjCBool(true)
            } else {
                isDirectory?.pointee = ObjCBool(false)
            }
            return exists
        }
        return false
    }
    
    override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?) throws -> [URL] {
        if let dirContents = contents[url] {
            return dirContents
        }
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
    }
    
    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        if let attrs = attributes[path] {
            return attrs
        }
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
    }
}

// Helper extensions for testing
extension FileItem: Equatable {
    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.id == rhs.id
    }
}
