// DocumentPickerView.swift
// Files
//
// Created on 2025-03-30.
//

import SwiftUI
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "tnir.ca.WatchTogether.Files", category: "DocumentPickerView")

/// A SwiftUI wrapper for the document picker to select files from the system
public struct DocumentPickerView: UIViewControllerRepresentable {
    private let contentTypes: [UTType]
    private let allowsMultipleSelection: Bool
    private let onPickedDocuments: ([URL]) -> Void
    
    /// Initialize a document picker view
    /// - Parameters:
    ///   - contentTypes: The content types to filter by
    ///   - allowsMultipleSelection: Whether to allow selecting multiple files
    ///   - onPickedDocuments: Callback with the selected document URLs
    public init(
        contentTypes: [UTType] = [.movie, .video, .audiovisualContent],
        allowsMultipleSelection: Bool = false,
        onPickedDocuments: @escaping ([URL]) -> Void
    ) {
        self.contentTypes = contentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onPickedDocuments = onPickedDocuments
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            logger.debug("Selected \(urls.count) documents")
            
            // Ensure we have permission to access these files
            let securedURLs = urls.map { url -> URL in
                // Start accessing the security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    logger.debug("Successfully accessed security-scoped resource: \(url.lastPathComponent)")
                    return url
                } else {
                    logger.warning("Failed to access security-scoped resource: \(url.lastPathComponent)")
                    return url
                }
            }
            
            parent.onPickedDocuments(securedURLs)
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            logger.debug("Document picker was cancelled")
            parent.onPickedDocuments([])
        }
    }
}

/// A view that presents a document picker button
public struct DocumentPickerButton: View {
    private let label: String
    private let systemImage: String
    private let contentTypes: [UTType]
    private let allowsMultipleSelection: Bool
    private let onPickedDocuments: ([URL]) -> Void
    
    @State private var isShowingPicker = false
    
    /// Initialize a document picker button
    /// - Parameters:
    ///   - label: The button label
    ///   - systemImage: The system image name
    ///   - contentTypes: The content types to filter by
    ///   - allowsMultipleSelection: Whether to allow selecting multiple files
    ///   - onPickedDocuments: Callback with the selected document URLs
    public init(
        label: String = "Select File",
        systemImage: String = "doc",
        contentTypes: [UTType] = [.movie, .video, .audiovisualContent],
        allowsMultipleSelection: Bool = false,
        onPickedDocuments: @escaping ([URL]) -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.contentTypes = contentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onPickedDocuments = onPickedDocuments
    }
    
    public var body: some View {
        Button {
            isShowingPicker = true
        } label: {
            Label(label, systemImage: systemImage)
        }
        .sheet(isPresented: $isShowingPicker) {
            DocumentPickerView(
                contentTypes: contentTypes,
                allowsMultipleSelection: allowsMultipleSelection,
                onPickedDocuments: { urls in
                    isShowingPicker = false
                    onPickedDocuments(urls)
                }
            )
            .edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview {
    VStack {
        DocumentPickerButton(
            label: "Select Video",
            systemImage: "film",
            onPickedDocuments: { urls in
                print("Selected URLs: \(urls)")
            }
        )
        .padding()
        .buttonStyle(.borderedProminent)
        
        DocumentPickerButton(
            label: "Select Multiple Videos",
            systemImage: "film.stack",
            allowsMultipleSelection: true,
            onPickedDocuments: { urls in
                print("Selected URLs: \(urls)")
            }
        )
        .padding()
        .buttonStyle(.bordered)
    }
}
