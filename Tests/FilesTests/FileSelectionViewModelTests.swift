//
//  FileSelectionViewModelTests.swift
//  FilesTests
//
//  Created by Claude on 2025-03-30.
//

import XCTest
import Combine
import UniformTypeIdentifiers
@testable import Files

final class FileSelectionViewModelTests: XCTestCase {
    // The view model to test
    var viewModel: FileSelectionViewModel!
    
    // Mock file provider view model for testing
    var mockFileProviderViewModel: MockFileProviderViewModel!
    
    // Test file items
    var videoFile1: FileItem!
    var videoFile2: FileItem!
    var audioFile: FileItem!
    var documentFile: FileItem!
    
    // Cancellables for async tests
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        // Create mock file items for testing
        videoFile1 = FileItem(
            id: "video1",
            name: "test_video1.mp4",
            url: URL(fileURLWithPath: "/test/videos/test_video1.mp4"),
            size: 1024 * 1024 * 100, // 100 MB
            modificationDate: Date().addingTimeInterval(-3600), // 1 hour ago
            creationDate: Date().addingTimeInterval(-86400), // 1 day ago
            isDirectory: false,
            contentType: .movie,
            parentID: "/test/videos"
        )
        
        videoFile2 = FileItem(
            id: "video2",
            name: "test_video2.mp4",
            url: URL(fileURLWithPath: "/test/videos/test_video2.mp4"),
            size: 1024 * 1024 * 200, // 200 MB
            modificationDate: Date().addingTimeInterval(-7200), // 2 hours ago
            creationDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
            isDirectory: false,
            contentType: .movie,
            parentID: "/test/videos"
        )
        
        audioFile = FileItem(
            id: "audio1",
            name: "test_audio.mp3",
            url: URL(fileURLWithPath: "/test/audio/test_audio.mp3"),
            size: 1024 * 1024 * 5, // 5 MB
            modificationDate: Date(),
            creationDate: Date().addingTimeInterval(-3600), // 1 hour ago
            isDirectory: false,
            contentType: .audio,
            parentID: "/test/audio"
        )
        
        documentFile = FileItem(
            id: "doc1",
            name: "test_document.pdf",
            url: URL(fileURLWithPath: "/test/documents/test_document.pdf"),
            size: 1024 * 1024, // 1 MB
            modificationDate: Date(),
            creationDate: Date(),
            isDirectory: false,
            contentType: .pdf,
            parentID: "/test/documents"
        )
        
        // Set up the mock file provider view model
        mockFileProviderViewModel = MockFileProviderViewModel()
        
        // Create the view model with the mock
        viewModel = FileSelectionViewModel(fileProviderViewModel: mockFileProviderViewModel)
    }
    
    override func tearDown() {
        viewModel = nil
        mockFileProviderViewModel = nil
        videoFile1 = nil
        videoFile2 = nil
        audioFile = nil
        documentFile = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testAddToPlaylist() {
        // Start with empty playlist
        XCTAssertEqual(viewModel.selectedFiles.count, 0)
        
        // Add a video file
        viewModel.addToPlaylist(videoFile1)
        XCTAssertEqual(viewModel.selectedFiles.count, 1)
        XCTAssertEqual(viewModel.selectedFiles[0].id, videoFile1.id)
        
        // Add another video file
        viewModel.addToPlaylist(videoFile2)
        XCTAssertEqual(viewModel.selectedFiles.count, 2)
        XCTAssertEqual(viewModel.selectedFiles[1].id, videoFile2.id)
        
        // Add an audio file
        viewModel.addToPlaylist(audioFile)
        XCTAssertEqual(viewModel.selectedFiles.count, 3)
        XCTAssertEqual(viewModel.selectedFiles[2].id, audioFile.id)
        
        // Try adding a document file (should work since we don't restrict by type in addToPlaylist)
        viewModel.addToPlaylist(documentFile)
        XCTAssertEqual(viewModel.selectedFiles.count, 4)
        
        // Try adding a duplicate file (should not add)
        viewModel.addToPlaylist(videoFile1)
        XCTAssertEqual(viewModel.selectedFiles.count, 4)
    }
    
    func testRemoveFromPlaylist() {
        // Add files to the playlist
        viewModel.addToPlaylist(videoFile1)
        viewModel.addToPlaylist(videoFile2)
        viewModel.addToPlaylist(audioFile)
        XCTAssertEqual(viewModel.selectedFiles.count, 3)
        
        // Remove the first video file
        viewModel.removeFromPlaylist(videoFile1)
        XCTAssertEqual(viewModel.selectedFiles.count, 2)
        XCTAssertFalse(viewModel.selectedFiles.contains { $0.id == videoFile1.id })
        
        // Remove the audio file
        viewModel.removeFromPlaylist(audioFile)
        XCTAssertEqual(viewModel.selectedFiles.count, 1)
        XCTAssertFalse(viewModel.selectedFiles.contains { $0.id == audioFile.id })
        
        // Try removing a file that's not in the playlist
        viewModel.removeFromPlaylist(documentFile)
        XCTAssertEqual(viewModel.selectedFiles.count, 1)
    }
    
    func testClearPlaylist() {
        // Add files to the playlist
        viewModel.addToPlaylist(videoFile1)
        viewModel.addToPlaylist(videoFile2)
        viewModel.addToPlaylist(audioFile)
        XCTAssertEqual(viewModel.selectedFiles.count, 3)
        
        // Clear the playlist
        viewModel.clearPlaylist()
        XCTAssertEqual(viewModel.selectedFiles.count, 0)
    }
    
    func testSetCurrentPlayingFile() {
        // Start with no current playing file
        XCTAssertNil(viewModel.currentPlayingFile)
        
        // Add files to the playlist
        viewModel.addToPlaylist(videoFile1)
        viewModel.addToPlaylist(videoFile2)
        
        // Set the first video as playing
        viewModel.setCurrentPlayingFile(videoFile1)
        XCTAssertEqual(viewModel.currentPlayingFile?.id, videoFile1.id)
        
        // Change to the second video
        viewModel.setCurrentPlayingFile(videoFile2)
        XCTAssertEqual(viewModel.currentPlayingFile?.id, videoFile2.id)
        
        // Set a file that's not in the playlist
        viewModel.setCurrentPlayingFile(audioFile)
        XCTAssertEqual(viewModel.currentPlayingFile?.id, audioFile.id)
    }
    
    func testGetNextFile() {
        // Add files to the playlist
        viewModel.addToPlaylist(videoFile1)
        viewModel.addToPlaylist(videoFile2)
        viewModel.addToPlaylist(audioFile)
        
        // With no current file, should return the first file
        XCTAssertNil(viewModel.currentPlayingFile)
        XCTAssertEqual(viewModel.getNextFile()?.id, videoFile1.id)
        
        // Set current file to the first video
        viewModel.setCurrentPlayingFile(videoFile1)
        XCTAssertEqual(viewModel.getNextFile()?.id, videoFile2.id)
        
        // Set current file to the second video
        viewModel.setCurrentPlayingFile(videoFile2)
        XCTAssertEqual(viewModel.getNextFile()?.id, audioFile.id)
        
        // Set current file to the audio file (should wrap around to first video)
        viewModel.setCurrentPlayingFile(audioFile)
        XCTAssertEqual(viewModel.getNextFile()?.id, videoFile1.id)
        
        // Test with a file not in the playlist
        viewModel.setCurrentPlayingFile(documentFile)
        XCTAssertEqual(viewModel.getNextFile()?.id, videoFile1.id)
        
        // Test with empty playlist
        viewModel.clearPlaylist()
        XCTAssertNil(viewModel.getNextFile())
    }
    
    func testGetPreviousFile() {
        // Add files to the playlist
        viewModel.addToPlaylist(videoFile1)
        viewModel.addToPlaylist(videoFile2)
        viewModel.addToPlaylist(audioFile)
        
        // With no current file, should return the last file
        XCTAssertNil(viewModel.currentPlayingFile)
        XCTAssertEqual(viewModel.getPreviousFile()?.id, audioFile.id)
        
        // Set current file to the first video
        viewModel.setCurrentPlayingFile(videoFile1)
        XCTAssertEqual(viewModel.getPreviousFile()?.id, audioFile.id)
        
        // Set current file to the second video
        viewModel.setCurrentPlayingFile(videoFile2)
        XCTAssertEqual(viewModel.getPreviousFile()?.id, videoFile1.id)
        
        // Set current file to the audio file
        viewModel.setCurrentPlayingFile(audioFile)
        XCTAssertEqual(viewModel.getPreviousFile()?.id, videoFile2.id)
        
        // Test with a file not in the playlist
        viewModel.setCurrentPlayingFile(documentFile)
        XCTAssertEqual(viewModel.getPreviousFile()?.id, audioFile.id)
        
        // Test with empty playlist
        viewModel.clearPlaylist()
        XCTAssertNil(viewModel.getPreviousFile())
    }
    
    func testGetFileInfo() {
        // Get info for a video file
        let videoInfo = viewModel.getFileInfo(videoFile1)
        XCTAssertEqual(videoInfo["Name"], "test_video1.mp4")
        XCTAssertNotNil(videoInfo["Size"])
        XCTAssertNotNil(videoInfo["Type"])
        XCTAssertNotNil(videoInfo["Modified"])
        XCTAssertNotNil(videoInfo["Created"])
        
        // Get info for an audio file
        let audioInfo = viewModel.getFileInfo(audioFile)
        XCTAssertEqual(audioInfo["Name"], "test_audio.mp3")
        XCTAssertNotNil(audioInfo["Size"])
        XCTAssertNotNil(audioInfo["Type"])
    }
    
    func testMovePlaylistItem() {
        // Add files to the playlist
        viewModel.addToPlaylist(videoFile1)
        viewModel.addToPlaylist(videoFile2)
        viewModel.addToPlaylist(audioFile)
        
        // Initial order: video1, video2, audio
        XCTAssertEqual(viewModel.selectedFiles[0].id, videoFile1.id)
        XCTAssertEqual(viewModel.selectedFiles[1].id, videoFile2.id)
        XCTAssertEqual(viewModel.selectedFiles[2].id, audioFile.id)
        
        // Move video1 to position 2 (after video2)
        viewModel.movePlaylistItem(fromIndex: 0, toIndex: 1)
        
        // New order: video2, video1, audio
        XCTAssertEqual(viewModel.selectedFiles[0].id, videoFile2.id)
        XCTAssertEqual(viewModel.selectedFiles[1].id, videoFile1.id)
        XCTAssertEqual(viewModel.selectedFiles[2].id, audioFile.id)
        
        // Move audio to position 0 (first)
        viewModel.movePlaylistItem(fromIndex: 2, toIndex: 0)
        
        // New order: audio, video2, video1
        XCTAssertEqual(viewModel.selectedFiles[0].id, audioFile.id)
        XCTAssertEqual(viewModel.selectedFiles[1].id, videoFile2.id)
        XCTAssertEqual(viewModel.selectedFiles[2].id, videoFile1.id)
    }
}

// MARK: - Mock Classes for Testing

class MockFileProviderViewModel: FileProviderViewModel {
    // Override to return a fake URL
    override func getLocalURL(for item: FileItem) async -> URL? {
        return item.url
    }
}
