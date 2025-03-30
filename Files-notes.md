For selecting videos for playback:

```swift
let fileSelectionViewModel = Files.createFileSelectionViewModel()

NavigationLink(destination: Files.fileSelectionView(
    onSelectFile: { file in
        // Handle direct file selection (play immediately)
        Task {
            if let url = await fileSelectionViewModel.getLocalURL(for: file) {
                coordinator.setupPlayer(with: url)
            }
        }
    },
    onAddToPlaylist: { file in
        // Add to playlist for later
        fileSelectionViewModel.addToPlaylist(file)
    },
    allowMultipleSelection: true,
    contentTypes: FileTypeUtility.videoTypes
)) {
    Label("Select Video", systemImage: "film")
}
```

For playlist management:

```swift
NavigationLink(destination: Files.playlistView(viewModel: fileSelectionViewModel)) {
    Label("Playlist", systemImage: "list.bullet")
}
```
