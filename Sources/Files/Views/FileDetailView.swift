//
//  FileDetailView.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import SwiftUI
#if os(tvOS)
import UIKit
#endif
import AVKit

/// A view for displaying details about a file
public struct FileDetailView: View {
    let file: FileItem
    let fileSelectionViewModel: FileSelectionViewModel
    
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var previewURL: URL?
    @State private var previewPlayer: AVPlayer?
    @State private var fileInfo: [String: String] = [:]
    
    /// Initializes the view
    /// - Parameters:
    ///   - file: The file to display details for
    ///   - fileSelectionViewModel: The view model to use
    public init(file: FileItem, fileSelectionViewModel: FileSelectionViewModel) {
        self.file = file
        self.fileSelectionViewModel = fileSelectionViewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // File thumbnail or preview
                if let previewPlayer = previewPlayer, file.isVideo {
                    VideoPlayer(player: previewPlayer)
                        .frame(height: 200)
                        .cornerRadius(12)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color(FilesColor.secondaryBackground.color))
                            .frame(height: 200)
                            .cornerRadius(12)
                        
                        Image(systemName: iconName(for: file))
                            .font(.system(size: 50))
                            .foregroundColor(iconColor(for: file))
                    }
                }
                
                // File name and basic info
                VStack(alignment: .leading, spacing: 8) {
                    Text(file.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    if let contentType = file.contentType {
                        Text(contentType.localizedDescription ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let size = file.size {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: {
                        fileSelectionViewModel.addToPlaylist(file)
                    }) {
                        VStack {
                            Image(systemName: "plus.circle")
                                .font(.largeTitle)
                            Text("Add to Playlist")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        fileSelectionViewModel.setCurrentPlayingFile(file)
                    }) {
                        VStack {
                            Image(systemName: "play.circle")
                                .font(.largeTitle)
                            Text("Play Now")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        shareFile()
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.largeTitle)
                            Text("Share")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding()
                
                // Detailed file information
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Details")
                        .font(.headline)
                    
                    Divider()
                    
                    ForEach(fileInfo.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text(key)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(value)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("File Details")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground).opacity(0.8)))
                    .shadow(radius: 10)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadFileDetails()
        }
        .onDisappear {
            // Stop playback when view disappears
            previewPlayer?.pause()
            previewPlayer = nil
        }
    }
    
    /// Loads file details and preview
    private func loadFileDetails() {
        isLoading = true
        
        // Get file info
        fileInfo = fileSelectionViewModel.getFileInfo(file)
        
        // Load preview URL for media files
        if file.isVideo || file.isAudio {
            Task {
                do {
                    if let url = await fileSelectionViewModel.getLocalURL(for: file) {
                        // Create a preview player for the file
                        let player = AVPlayer(url: url)
                        
                        // Set the player's volume
                        player.volume = 0.5
                        
                        await MainActor.run {
                            self.previewURL = url
                            self.previewPlayer = player
                            
                            // Prepare player by preloading a short segment
                            player.automaticallyWaitsToMinimizeStalling = true
                            
                            // Don't autoplay the preview
                            player.pause()
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Could not load file preview: \(error.localizedDescription)"
                        showError = true
                    }
                }
                
                await MainActor.run {
                    isLoading = false
                }
            }
        } else {
            isLoading = false
        }
    }
    
    /// Shares the file
    private func shareFile() {
        #if os(tvOS)
        #else
        Task {
            do {
                if let url = await fileSelectionViewModel.getLocalURL(for: file) {
                    // Share the file using UIActivityViewController
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: [])
                    
                    // Present the activity view controller
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                } else {
                    errorMessage = "Could not access the file for sharing"
                    showError = true
                }
            }
        }
        #endif
    }
    
    /// Determines the icon name to use for a file item
    /// - Parameter item: The file item
    /// - Returns: The name of the system icon to use
    private func iconName(for item: FileItem) -> String {
        if item.isDirectory {
            return "folder"
        }
        
        if let contentType = item.contentType {
            if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
                return "play.rectangle.fill"
            }
            if contentType.conforms(to: .audio) {
                return "music.note.fill"
            }
            if contentType.conforms(to: .image) {
                return "photo.fill"
            }
            if contentType.conforms(to: .pdf) {
                return "doc.text.fill"
            }
        }
        
        return "doc.fill"
    }
    
    /// Determines the icon color to use for a file item
    /// - Parameter item: The file item
    /// - Returns: The color to use for the icon
    private func iconColor(for item: FileItem) -> Color {
        if item.isDirectory {
            return .blue
        }
        
        if let contentType = item.contentType {
            if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
                return .purple
            }
            if contentType.conforms(to: .audio) {
                return .pink
            }
            if contentType.conforms(to: .image) {
                return .green
            }
        }
        
        return .gray
    }
}

#Preview {
    NavigationStack {
        // Create a mock file item for preview
        let url = URL(fileURLWithPath: "/path/to/movie.mp4")
        let fileItem = FileItem(
            id: "123",
            name: "Sample Movie.mp4",
            url: url,
            size: 128_000_000,
            modificationDate: Date(),
            creationDate: Date().addingTimeInterval(-86400), // 1 day ago
            isDirectory: false,
            contentType: UTType.movie
        )
        
        FileDetailView(
            file: fileItem,
            fileSelectionViewModel: FileSelectionViewModel()
        )
    }
}
