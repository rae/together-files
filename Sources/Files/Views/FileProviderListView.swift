//
//  FileProviderListView.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import SwiftUI
import UniformTypeIdentifiers

/// A view that displays a list of file providers
public struct FileProviderListView: View {
    @State private var viewModel: FileProviderViewModel
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    /// Initializes the view
    /// - Parameter viewModel: The view model to use
    public init(viewModel: FileProviderViewModel = FileProviderViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    public var body: some View {
        VStack {
            if viewModel.providers.isEmpty && !isLoading {
                ContentUnavailableView {
                    Label("No File Providers", systemImage: "folder.badge.questionmark")
                } description: {
                    Text("No file providers found. Please check your device permissions.")
                } actions: {
                    Button("Refresh") {
                        Task {
                            await loadProviders()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                List(viewModel.providers) { provider in
                    Button(action: {
                        Task {
                            await viewModel.selectProvider(provider)
                        }
                    }) {
                        HStack {
                            Image(systemName: provider.iconName)
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading) {
                                Text(provider.displayName)
                                    .font(.headline)
                                
                                Text(provider.status.rawValue)
                                    .font(.caption)
                                    .foregroundColor(statusColor(for: provider.status))
                            }
                            
                            Spacer()
                            
                            if provider == viewModel.selectedProvider {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await loadProviders()
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground).opacity(0.8)))
                    .shadow(radius: 10)
            }
        }
        .navigationTitle("File Providers")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await loadProviders()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadProviders()
        }
    }
    
    /// Determines the color to use for the status text
    /// - Parameter status: The provider status
    /// - Returns: The color to use
    private func statusColor(for status: FileProviderModel.ProviderStatus) -> Color {
        switch status {
        case .available:
            return .green
        case .connecting:
            return .orange
        case .offline:
            return .gray
        case .error:
            return .red
        case .unauthorized:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    /// Loads the list of providers
    private func loadProviders() async {
        isLoading = true
        defer { isLoading = false }
        
        await viewModel.loadProviders()
        
        if let error = viewModel.lastError {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        FileProviderListView()
    }
}
