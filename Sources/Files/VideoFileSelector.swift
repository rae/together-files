// VideoFileSelector.swift
// Files
//
// Created on 2025-03-30.
//

import SwiftUI
import UniformTypeIdentifiers
import AVKit
import OSLog

private let logger = Logger(subsystem: "tnir.ca.WatchTogether.Files", category: "VideoFileSelector")

/// A view model for the video file selector
@Observable public final class VideoFileSelectorViewModel {
    public private(set) var selectedURL: URL?
    public private(set) var videoTitle: String?
    public private(set) var videoDuration: TimeInterval?
    public private(set) var thumbnailImage: UIImage?
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?
    public var player: AVPlayer?
    
    private var fileBrowserViewModel = FileBrowserViewModel()
    
    /// Handle a selected video file URL
    /// - Parameter url: The URL of the selected video file
    @MainActor
    public func handleSelectedVideo(_ url: URL) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create asset for metadata extraction
            let asset = AVURLAsset(url: url)
            
            // Load duration
            self.videoDuration = try await asset.load(.duration).seconds
            
            // Extract title from metadata or use filename
            let metadata = try await asset.load(.commonMetadata)
            self.videoTitle = getVideoTitle(from: metadata) ?? url.deletingPathExtension().lastPathComponent
            
            // Generate thumbnail
            self.thumbnailImage = await generateThumbnail(for: asset)
            
            // Create player
            self.player = AVPlayer(url: url)
            self.selectedURL = url
            
            logger.info("Video loaded: \(url.lastPathComponent), duration: \(String(describing: self.videoDuration))")
        } catch {
            self.errorMessage = "Failed to load video: \(error.localizedDescription)"
            self.selectedURL = nil
            self.player = nil
            logger.error("Error loading video: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Clear the selected video
    public func clearSelection() {
        selectedURL = nil
        videoTitle = nil
        videoDuration = nil
        thumbnailImage = nil
        player = nil
    }
    
    /// Play the selected video
    public func play() {
        player?.play()
    }
    
    /// Pause the selected video
    public func pause() {
        player?.pause()
    }
    
    /// Get the title from metadata
    private func getVideoTitle(from metadata: [AVMetadataItem]) -> String? {
        let titleItems = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierTitle)
        return titleItems.first?.stringValue
    }
    
    /// Generate a thumbnail for the video
    private func generateThumbnail(for asset: AVURLAsset) async -> UIImage? {
        do {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            
            // Get thumbnail at 10% into the video
            let duration = try await asset.load(.duration)
            let time = CMTime(seconds: duration.seconds * 0.1, preferredTimescale: 600)
            
            let cgImage = try await generator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            logger.error("Failed to generate thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Format time interval as string
    public func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration = duration else { return "Unknown" }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        return formatter.string(from: duration) ?? "Unknown"
    }
}

/// A view that allows selection and preview of video files
public struct VideoFileSelector: View {
    @Binding private var selectedVideoURL: URL?
    @State private var viewModel = VideoFileSelectorViewModel()
    @State private var showingFileBrowser = false
    @State private var showingDocumentPicker = false
    
    private let onSelectionChanged: ((URL?) -> Void)?
    
    /// Initialize a video file selector
    /// - Parameters:
    ///   - selectedVideoURL: Binding to the selected video URL
    ///   - onSelectionChanged: Optional callback when selection changes
    public init(
        selectedVideoURL: Binding<URL?>,
        onSelectionChanged: ((URL?) -> Void)? = nil
    ) {
        self._selectedVideoURL = selectedVideoURL
        self.onSelectionChanged = onSelectionChanged
    }
    
    public var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading video...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let selectedURL = viewModel.selectedURL {
                videoPreviewView
            } else {
                emptyStateView
            }
        }
        .onChange(of: viewModel.selectedURL) { _, newURL in
            selectedVideoURL = newURL
            onSelectionChanged?(newURL)
        }
        .sheet(isPresented: $showingFileBrowser) {
            FileBrowserView { url in
                Task {
                    await viewModel.handleSelectedVideo(url)
                }
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "film")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Video Selected")
                .font(.headline)
            
            Text("Select a video file to watch")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button {
                    showingFileBrowser = true
                } label: {
                    Label("Browse Files", systemImage: "folder")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                
                DocumentPickerButton(
                    label: "Select Video",
                    systemImage: "film",
                    contentTypes: [.movie, .video, .audiovisualContent],
                    onPickedDocuments: { urls in
                        guard let firstURL = urls.first else { return }
                        Task {
                            await viewModel.handleSelectedVideo(firstURL)
                        }
                    }
                )
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 250)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var videoPreviewView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Video preview with thumbnail or player
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            } else if let thumbnail = viewModel.thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Video metadata
            VStack(alignment: .leading, spacing: 8) {
                if let title = viewModel.videoTitle {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                if let url = viewModel.selectedURL {
                    Text(url.lastPathComponent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let duration = viewModel.videoDuration {
                    Text("Duration: \(viewModel.formatDuration(duration))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Actions
            HStack {
                Button {
                    viewModel.clearSelection()
                } label: {
                    Label("Change", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if viewModel.player != nil {
                    Button {
                        viewModel.play()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        viewModel.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    @State var selectedURL: URL?
    
    return VStack {
        VideoFileSelector(selectedVideoURL: $selectedURL)
            .padding()
        
        if let url = selectedURL {
            Text("Selected: \(url.lastPathComponent)")
                .padding()
        }
    }
}
