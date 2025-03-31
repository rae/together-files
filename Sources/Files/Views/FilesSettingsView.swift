//
//  FilesSettingsView.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import SwiftUI
import UniformTypeIdentifiers

/// A view for configuring file-related settings
public struct FilesSettingsView: View {
    @AppStorage("defaultSortOrder") private var defaultSortOrder = 0
    @AppStorage("showHiddenFiles") private var showHiddenFiles = false
    @AppStorage("cacheEnabled") private var cacheEnabled = true
    @AppStorage("cacheSize") private var cacheSize = 500 // In MB
    @AppStorage("preferredFileProviders") private var preferredFileProviders = ""
    
    @State private var isResettingCache = false
    @State private var showClearCacheConfirmation = false
    @State private var showProviderSelection = false
    @State private var availableProviders: [FileProviderModel] = []
    @State private var selectedProviders: [String] = []
    
    // Available sort orders
    private let sortOrders = FileProviderViewModel.SortOrder.allCases
    
    public init() {
        // Load preferred providers on init
        if !preferredFileProviders.isEmpty {
            selectedProviders = preferredFileProviders.components(separatedBy: ",")
        }
    }
    
    public var body: some View {
        Form {
            Section(header: Text("Browsing")) {
                Picker("Default Sort Order", selection: $defaultSortOrder) {
                    ForEach(0..<sortOrders.count, id: \.self) { index in
                        Text(sortOrders[index].rawValue).tag(index)
                    }
                }
                
                Toggle("Show Hidden Files", isOn: $showHiddenFiles)
            }
            
            Section(header: Text("File Providers")) {
                Button("Configure Preferred Providers") {
                    showProviderSelection = true
                }
                
                if !selectedProviders.isEmpty {
                    ForEach(selectedProviders, id: \.self) { providerID in
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text(displayNameForProvider(providerID))
                        }
                    }
                } else {
                    Text("No preferred providers selected")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Section(header: Text("Cache Settings")) {
                Toggle("Enable File Caching", isOn: $cacheEnabled)
                
                if cacheEnabled {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text("\(cacheSize) MB")
                    }
                    
                    Slider(value: Binding(
                        get: { Double(cacheSize) },
                        set: { cacheSize = Int($0) }
                    ), in: 100...5000, step: 100)
                    .disabled(!cacheEnabled)
                    
                    Button("Clear Cache") {
                        showClearCacheConfirmation = true
                    }
                    .foregroundColor(.red)
                    .disabled(!cacheEnabled)
                }
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Files Package Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Files Settings")
        .overlay {
            if isResettingCache {
                ProgressView("Clearing cache...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)))
                    .shadow(radius: 10)
            }
        }
        .alert("Clear Cache", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("Are you sure you want to clear the file cache? This will remove all cached files.")
        }
        .sheet(isPresented: $showProviderSelection) {
            providerSelectionView()
        }
        .onAppear {
            loadAvailableProviders()
        }
    }
    
    /// Creates a view for selecting preferred providers
    private func providerSelectionView() -> some View {
        NavigationStack {
            List {
                ForEach(availableProviders) { provider in
                    Button(action: {
                        toggleProvider(provider)
                    }) {
                        HStack {
                            Image(systemName: provider.iconName)
                                .foregroundColor(.accentColor)
                            
                            Text(provider.displayName)
                            
                            Spacer()
                            
                            if isProviderSelected(provider) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Preferred Providers")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        saveSelectedProviders()
                        showProviderSelection = false
                    }
                }
            }
        }
    }
    
    /// Loads available file providers
    private func loadAvailableProviders() {
        Task {
            do {
                let service = FileProviderService.shared
                let providers = try await service.getProviders()
                
                await MainActor.run {
                    self.availableProviders = providers
                }
            } catch {
                print("Error loading providers: \(error)")
            }
        }
    }
    
    /// Toggles selection of a provider
    /// - Parameter provider: The provider to toggle
    private func toggleProvider(_ provider: FileProviderModel) {
        if isProviderSelected(provider) {
            selectedProviders.removeAll { $0 == provider.id }
        } else {
            selectedProviders.append(provider.id)
        }
    }
    
    /// Checks if a provider is selected
    /// - Parameter provider: The provider to check
    /// - Returns: True if the provider is selected
    private func isProviderSelected(_ provider: FileProviderModel) -> Bool {
        return selectedProviders.contains(provider.id)
    }
    
    /// Saves the selected providers
    private func saveSelectedProviders() {
        preferredFileProviders = selectedProviders.joined(separator: ",")
    }
    
    /// Gets the display name for a provider
    /// - Parameter providerID: The provider ID
    /// - Returns: The display name
    private func displayNameForProvider(_ providerID: String) -> String {
        if let provider = availableProviders.first(where: { $0.id == providerID }) {
            return provider.displayName
        }
        return providerID
    }
    
    /// Clears the file cache
    private func clearCache() {
        isResettingCache = true
        
        // Simulate cache clearing with a delay
        Task {
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // In a real implementation, we would clear actual cached files here
            // This would be handled by the FileSystemService
            
            await MainActor.run {
                isResettingCache = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        FilesSettingsView()
    }
}
