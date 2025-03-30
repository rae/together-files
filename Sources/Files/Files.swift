// Files.swift
// Files
//
// Created on 2025-03-30.
//

import Foundation
import SwiftUI
import AVKit
import UniformTypeIdentifiers

/// Main entry point for the Files package
public enum Files {
    /// Create a video file selector view
    /// - Parameters:
    ///   - selectedVideoURL: Binding to the selected video URL
    ///   - onSelectionChanged: Optional callback when selection changes
    /// - Returns: A VideoFileSelector view
    public static func videoSelector(
        selectedVideoURL: Binding<URL?>,
        onSelectionChanged: ((URL?) -> Void)? = nil
    ) -> some View {
        VideoFileSelector(
            selectedVideoURL: selectedVideoURL,
            onSelectionChanged: onSelectionChanged
        )
    }
    
    /// Create a document picker button
    /// - Parameters:
    ///   - label: The button label
    ///   - systemImage: The system image name
    ///   - contentTypes: The content types to filter by
    ///   - allowsMultipleSelection: Whether to allow selecting multiple files
    ///   - onPickedDocuments: Callback with the selected document URLs
    /// - Returns: A DocumentPickerButton view
    public static func documentPickerButton(
        label: String = "Select File",
        systemImage: String = "doc",
        contentTypes: [UTType] = [.movie, .video, .audiovisualContent],
        allowsMultipleSelection: Bool = false,
        onPickedDocuments: @escaping ([URL]) -> Void
    ) -> some View {
        DocumentPickerButton(
            label: label,
            systemImage: systemImage,
            contentTypes: contentTypes,
            allowsMultipleSelection: allowsMultipleSelection,
            onPickedDocuments: onPickedDocuments
        )
    }
    
    /// Create a file browser view
    /// - Parameters:
    ///   - onFileSelected: Callback when a file is selected
    ///   - allowDirectorySelection: Whether directories can be selected
    /// - Returns: A FileBrowserView
    public static func fileBrowser(
        onFileSelected: @escaping (URL) -> Void,
        allowDirectorySelection: Bool = false
    ) -> some View {
        FileBrowserView(
            viewModel: FileBrowserViewModel(),
            onFileSelected: onFileSelected,
            allowDirectorySelection: allowDirectorySelection
        )
    }
    
    /// Create a player for a video URL
    /// - Parameter url: The video URL
    /// - Returns: An AVPlayer instance
    public static func createPlayer(for url: URL) -> AVPlayer {
        AVPlayer(url: url)
    }
    
    /// Check if a URL is a valid video file
    /// - Parameter url: The URL to check
    /// - Returns: Whether the URL points to a valid video file
    public static func isValidVideoFile(_ url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        
        do {
            // Try to load the tracks
            let tracks = try await asset.loadTracks(withMediaType: .video)
            return !tracks.isEmpty
        } catch {
            return false
        }
    }
    
    /// Get video metadata
    /// - Parameter url: The video URL
    /// - Returns: A tuple containing title, duration, and dimensions
    public static func getVideoMetadata(_ url: URL) async -> (title: String?, duration: TimeInterval?, dimensions: CGSize?) {
        let asset = AVURLAsset(url: url)
        
        do {
            // Get duration
            let duration = try await asset.load(.duration).seconds
            
            // Get title from metadata
            let metadata = try await asset.load(.commonMetadata)
            let titleItems = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierTitle)
            let title = titleItems.first?.stringValue ?? url.deletingPathExtension().lastPathComponent
            
            // Get dimensions
            let tracks = try await asset.loadTracks(withMediaType: .video)
            var dimensions: CGSize?
            if let videoTrack = tracks.first {
                let trackDimensions = try await videoTrack.load(.naturalSize)
                let trackTransform = try await videoTrack.load(.preferredTransform)
                dimensions = trackDimensions.applying(trackTransform)
            }
            
            return (title, duration, dimensions)
        } catch {
            return (url.deletingPathExtension().lastPathComponent, nil, nil)
        }
    }
    
    /// Create a thumbnail image for a video
    /// - Parameters:
    ///   - url: The video URL
    ///   - time: The time position for the thumbnail (default: 10% into the video)
    /// - Returns: A UIImage thumbnail
    public static func createVideoThumbnail(for url: URL, at time: CMTime? = nil) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        do {
            // Determine time for thumbnail
            let thumbnailTime: CMTime
            if let specifiedTime = time {
                thumbnailTime = specifiedTime
            } else {
                // Default to 10% into the video
                let duration = try await asset.load(.duration)
                thumbnailTime = CMTime(seconds: duration.seconds * 0.1, preferredTimescale: 600)
            }
            
            let cgImage = try await generator.image(at: thumbnailTime).image
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}
