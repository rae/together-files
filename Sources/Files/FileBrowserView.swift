// FileBrowserView.swift
// Files
//
// Created on 2025-03-30.
//

import SwiftUI
import OSLog

private let logger = Logger(subsystem: "tnir.ca.WatchTogether.Files", category: "FileBrowserView")

/// A view to browse files from file providers
public struct FileBrowserView: View {
    @State private var viewModel: FileBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let onFileSelected: (URL) -> Void
    private let allowDirectorySelection: Bool
    
    /// Initialize a file browser view
    /// - Parameters:
    ///   - viewModel: The view model
    ///   - onFileSelected: Callback when a file is selected
    ///   - allowDirectorySelection: Whether directories can be selected
    public init(
        viewModel: FileBrowserViewModel = FileBrowserViewModel(),
        onFileSelected: @escaping (URL) -> Void,
        allowDirectorySelection: Bool = false
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.onFileSelected = onFileSelected
        self.allowDirectorySelection = allowDirectorySelection
    }
    
    public var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.files.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Files", systemImage: "doc")
                    } description: {
                        Text("No files found in this location")
                    }
                } else {
                    fileListView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    domainPicker
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.directoryStack.isEmpty {
                        Button {
                            Task {
                                await viewModel.navigateBack()
                            }
                        } label: {
                            Label("Back", systemImage: "chevron.backward")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
                
                ToolbarItem(placement: .bottomBar) {
                    if !viewModel.recentFiles.isEmpty {
                        Menu {
                            ForEach(viewModel.recentFiles) { file in
                                Button {
                                    Task {
                                        if let url = await viewModel.getFileURL(file) {
                                            onFileSelected(url)
                                            dismiss()
                                        }
                                    }
                                } label: {
                                    Text(file.filename)
                                }
                            }
                        } label: {
                            Label("Recent", systemImage: "clock")
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search files")
            .onSubmit(of: .search) {
                Task {
                    await viewModel.search()
                }
            }
            .onChange(of: viewModel.searchText) {
                if viewModel.searchText.isEmpty {
                    viewModel.clearSearch()
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .task {
            await viewModel.loadDomains()
        }
    }
    
    private var navigationTitle: String {
        if let currentDir = viewModel.directoryStack.last {
            return currentDir.filename
        } else if let domain = viewModel.selectedDomain {
            return domain.displayName
        } else {
            return "Files"
        }
    }
    
    private var domainPicker: some View {
        Menu {
            ForEach(viewModel.availableDomains) { domain in
                Button {
                    Task {
                        await viewModel.selectDomain(domain)
                    }
                } label: {
                    HStack {
                        Text(domain.displayName)
                        
                        if domain.id == viewModel.selectedDomain?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "folder")
                Text(viewModel.selectedDomain?.displayName ?? "Select Provider")
                Image(systemName: "chevron.down")
            }
        }
        .disabled(viewModel.availableDomains.isEmpty)
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                if viewModel.directoryStack.isEmpty {
                    await viewModel.loadRootDirectory()
                } else if let currentDir = viewModel.directoryStack.last {
                    // Re-navigate to current directory to refresh
                    await viewModel.navigateToDirectory(currentDir)
                }
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }
    
    private var fileListView: some View {
        let filesToDisplay = viewModel.searchText.isEmpty ? viewModel.files : viewModel.searchResults
        
        return List(filesToDisplay) { file in
            FileItemRow(file: file)
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        if file.isDirectory {
                            await viewModel.navigateToDirectory(file)
                        } else {
                            if let url = await viewModel.getFileURL(file) {
                                onFileSelected(url)
                                dismiss()
                            }
                        }
                    }
                }
        }
        .listStyle(.plain)
    }
}

/// A row in the file list
struct FileItemRow: View {
    let file: FileItem
    
    var body: some View {
        HStack {
            // Icon
            fileIcon
                .font(.title2)
                .frame(width: 30)
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.filename)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(file.isDirectory ? "Folder" : file.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let date = file.modificationDate {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if file.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if !file.isDirectory {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 6)
    }
    
    private var fileIcon: some View {
        Group {
            if file.isDirectory {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
            } else if let fileType = file.fileType {
                if fileType.conforms(to: .movie) || fileType.conforms(to: .video) {
                    Image(systemName: "film.fill")
                        .foregroundColor(.purple)
                } else if fileType.conforms(to: .audio) {
                    Image(systemName: "music.note")
                        .foregroundColor(.pink)
                } else if fileType.conforms(to: .image) {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.green)
                } else if fileType.conforms(to: .text) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "doc.fill")
                    .foregroundColor(.gray)
            }
        }
    }
}
