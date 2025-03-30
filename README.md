# Files

A Swift Package for accessing, browsing, and managing files across different file providers, with a specific focus on media files for playback.

## Features

- Browse local and cloud file providers
- Access files through the FileProvider framework
- Select files for playback in a shared environment
- Manage playlists of media files
- Support for various media formats
- Cross-platform support for iOS, macOS, tvOS, and visionOS

##

This implementation ensures:

 - Cross-platform compatibility (iOS, macOS, tvOS, visionOS)
 - Support for local and cloud file providers through the FileProvider framework
 - Proper error handling for file access
 - Flexible UI components that fit the SwiftUI paradigm
 - Modularity that allows for easy maintenance and extension

This structure follows the MVVM architecture pattern and provides a clean separation of concerns, making the code more maintainable and testable.

## Requirements

- iOS 16.0+
- macOS 13.0+
- tvOS 16.0+
- visionOS 1.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Files.git", from: "1.0.0")
]
```

## Usage

### Browsing Files

```swift
import Files
import SwiftUI

struct ContentView: View {
    @State private var fileSelectionViewModel = Files.createFileSelectionViewModel()
    
    var body: some View {
        NavigationStack {
            Files.fileSelectionView(
                onSelectFile: { file in
                    // Handle file selection
                    print("Selected file: \(file.name)")
                },
                onAddToPlaylist: { file in
                    // Add to playlist
                    fileSelectionViewModel.addToPlaylist(file)
                },
                allowMultipleSelection: true,
                contentTypes: FileTypeUtility.mediaTypes
            )
        }
    }
}
```

### Managing a Playlist

```swift
import Files
import SwiftUI

struct PlaylistView: View {
    @StateObject private var viewModel = Files.createFileSelectionViewModel()
    
    var body: some View {
        NavigationStack {
            Files.playlistView(viewModel: viewModel)
        }
    }
}
```

### Playing Media

```swift
import Files
import SwiftUI
import AVKit

struct PlayerView: View {
    @StateObject private var viewModel = Files.createFileSelectionViewModel()
    @State private var player: AVPlayer?
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
            } else {
                Text("No video selected")
            }
            
            Files.playlistView(viewModel: viewModel)
        }
        .onChange(of: viewModel.currentPlayingFile) { _, newFile in
            if let file = newFile {
                Task {
                    if let url = await viewModel.getLocalURL(for: file) {
                        player = AVPlayer(url: url)
                        player?.play()
                    }
                }
            }
        }
    }
}
```

## Architecture

The Files package follows the MVVM (Model-View-ViewModel) architecture:

- **Models**: `FileItem`, `FileProviderModel`, etc.
- **ViewModels**: `FileProviderViewModel`, `FileSelectionViewModel`
- **Views**: `FileSelectionView`, `FileProviderListView`, `FileDetailView`, etc.
- **Services**: `FileProviderService` for interacting with file providers

## License

This library is available under the MIT license.
