# Files

A Swift Package for accessing, browsing, and managing files across iOS, macOS, tvOS, and visionOS platforms through the File Provider framework.

## Features

- Browse file provider domains (iCloud Drive, local files, third-party providers)
- View and select files and directories with rich metadata
- Document picker integration for straightforward file selection
- Video-specific utilities for media playback
- Full SwiftUI integration with MVVM architecture
- Multi-platform support (iOS, macOS, tvOS, visionOS)
- Support for Swift 6 Language Mode features for data-race safety

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Files.git", from: "1.0.0")
]
```

Or add it directly through Xcode:
1. Go to File > Add Package Dependencies
2. Enter the repository URL: `https://github.com/yourusername/Files.git`
3. Select the version you want to use

## Usage

### Basic Usage

Import the package and use the provided components:

```swift
import Files
import SwiftUI

struct ContentView: View {
    @State private var selectedVideoURL: URL?
    
    var body: some View {
        VStack {
            // Use the video selector component
            Files.videoSelector(selectedVideoURL: $selectedVideoURL) { url in
                print("Selected video: \(url?.lastPathComponent ?? "none")")
            }
            .padding()
            
            // Use the document picker button
            Files.documentPickerButton(
                label: "Select Video",
                systemImage: "film"
            ) { urls in
                if let url = urls.first {
                    selectedVideoURL = url
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}
```

### File Browser

To browse all available file providers:

```swift
import Files
import SwiftUI

struct MyView: View {
    @State private var showFileBrowser = false
    @State private var selectedFile: URL?
    
    var body: some View {
        VStack {
            Button("Browse Files") {
                showFileBrowser = true
            }
            .sheet(isPresented: $showFileBrowser) {
                Files.fileBrowser { url in
                    selectedFile = url
                    print("Selected file: \(url.lastPathComponent)")
                }
            }
            
            if let url = selectedFile {
                Text("Selected: \(url.lastPathComponent)")
            }
        }
    }
}
```

### Video Utilities

Working with video files:

```swift
import Files
import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @State private var selectedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var videoTitle: String?
    @State private var videoDuration: TimeInterval?
    
    var body: some View {
        VStack {
            // Video player
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
            }
            
            // Video selector
            Files.videoSelector(selectedVideoURL: $selectedVideoURL) { url in
                if let url = url {
                    Task {
                        player = Files.createPlayer(for: url)
                        
                        // Get metadata
                        let (title, duration, _) = await Files.getVideoMetadata(url)
                        videoTitle = title
                        videoDuration = duration
                    }
                } else {
                    player = nil
                }
            }
            .padding()
            
            // Metadata display
            if let title = videoTitle {
                Text("Title: \(title)")
            }
            
            if let duration = videoDuration {
                Text("Duration: \(formatDuration(duration))")
            }
        }
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        return formatter.string(from: duration) ?? "Unknown"
    }
}
```

## Advanced Usage

### Working with File Providers

For more advanced usage, you can work directly with the underlying models and services:

```swift
import Files
import SwiftUI

class MyViewModel {
    private let fileProviderService = FileProviderService.shared
    
    func loadFileDomains() async throws -> [FileProviderDomain] {
        return try await fileProviderService.getDomains()
    }
    
    func listFilesInRoot(domain: FileProviderDomain) async throws -> [FileItem] {
        return try await fileProviderService.listItems(domain: domain)
    }
    
    func getFileURL(item: FileItem) async throws -> URL {
        return try await fileProviderService.getURL(for: item)
    }
}
```

## Requirements

- iOS 17.0+
- macOS 14.0+
- tvOS 17.0+
- visionOS 1.0+
- Swift 6.0+

## License

This package is released under the MIT license. See [LICENSE](LICENSE) for details.
