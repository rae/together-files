//
//  FileTypeUtility.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import UniformTypeIdentifiers

/// Utility for working with file types
public struct FileTypeUtility {
    /// Get a list of common video file types
    public static var videoTypes: [UTType] {
        return [.movie, .video, .mpeg, .mpeg2Video, .mpeg4Movie, .quickTimeMovie, .appleProtectedMPEG4Video]
    }
    
    /// Get a list of common audio file types
    public static var audioTypes: [UTType] {
        return [.audio, .mp3, .aiff, .wav, .midi]
    }
    
    /// Get a list of common media file types (audio and video)
    public static var mediaTypes: [UTType] {
        return videoTypes + audioTypes
    }
    
    /// Get a list of common image file types
    public static var imageTypes: [UTType] {
        return [.image, .jpeg, .png, .gif, .tiff, .bmp, .heic]
    }
    
    /// Get a list of common document file types
    public static var documentTypes: [UTType] {
        return [.pdf, .text, .rtf, .html]
    }
    
    /// Get a UTType for a file extension
    /// - Parameter extension: The file extension
    /// - Returns: The corresponding UTType, or nil if not found
    public static func type(forExtension ext: String) -> UTType? {
        return UTType(filenameExtension: ext)
    }
    
    /// Get a UTType for a MIME type
    /// - Parameter mimeType: The MIME type
    /// - Returns: The corresponding UTType, or nil if not found
    public static func type(forMIMEType mimeType: String) -> UTType? {
        return UTType(mimeType: mimeType)
    }
    
    /// Check if a file is a video
    /// - Parameter contentType: The content type to check
    /// - Returns: True if the file is a video
    public static func isVideo(_ contentType: UTType?) -> Bool {
        guard let contentType = contentType else { return false }
        return videoTypes.contains { contentType.conforms(to: $0) }
    }
    
    /// Check if a file is audio
    /// - Parameter contentType: The content type to check
    /// - Returns: True if the file is audio
    public static func isAudio(_ contentType: UTType?) -> Bool {
        guard let contentType = contentType else { return false }
        return audioTypes.contains { contentType.conforms(to: $0) }
    }
    
    /// Check if a file is media (audio or video)
    /// - Parameter contentType: The content type to check
    /// - Returns: True if the file is media
    public static func isMedia(_ contentType: UTType?) -> Bool {
        guard let contentType = contentType else { return false }
        return isVideo(contentType) || isAudio(contentType)
    }
    
    /// Check if a file is an image
    /// - Parameter contentType: The content type to check
    /// - Returns: True if the file is an image
    public static func isImage(_ contentType: UTType?) -> Bool {
        guard let contentType = contentType else { return false }
        return imageTypes.contains { contentType.conforms(to: $0) }
    }
    
    /// Get a user-friendly description for a content type
    /// - Parameter contentType: The content type
    /// - Returns: A user-friendly description
    public static func friendlyDescription(for contentType: UTType?) -> String {
        guard let contentType = contentType else { return "Unknown" }
        
        if isVideo(contentType) {
            return "Video"
        } else if isAudio(contentType) {
            return "Audio"
        } else if isImage(contentType) {
            return "Image"
        } else if contentType.conforms(to: .pdf) {
            return "PDF Document"
        } else if contentType.conforms(to: .text) {
            return "Text Document"
        } else {
            return contentType.localizedDescription ?? contentType.identifier
        }
    }
    
    /// Get the appropriate system icon name for a content type
    /// - Parameter contentType: The content type
    /// - Returns: A system icon name
    public static func iconName(for contentType: UTType?) -> String {
        guard let contentType = contentType else { return "doc" }
        
        if isVideo(contentType) {
            return "play.rectangle"
        } else if isAudio(contentType) {
            return "music.note"
        } else if isImage(contentType) {
            return "photo"
        } else if contentType.conforms(to: .pdf) {
            return "doc.text"
        } else if contentType.conforms(to: .text) {
            return "doc.plaintext"
        } else {
            return "doc"
        }
    }
}
