//
//  FilesColor.swift
//  Files
//
//  Created by Claude on 2025-03-30.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A wrapper around platform-specific color types to provide a unified interface
/// for working with colors in both SwiftUI and UIKit/AppKit
public struct FilesColor {
    // MARK: - Properties
    
    /// The SwiftUI Color representation
    public let color: Color
    
    /// The platform-specific UIColor or NSColor representation
    #if canImport(UIKit)
    public let platformColor: UIColor
    #elseif canImport(AppKit)
    public let platformColor: NSColor
    #endif
    
    // MARK: - Initialization
    
    /// Create a FilesColor from a SwiftUI Color
    /// - Parameter color: The SwiftUI Color
    public init(_ color: Color) {
        self.color = color
        
        #if canImport(UIKit)
        self.platformColor = UIColor(color)
        #elseif canImport(AppKit)
        self.platformColor = NSColor(color)
        #endif
    }
    
    /// Create a FilesColor from a platform-specific color
    /// - Parameter platformColor: The UIColor or NSColor
    #if canImport(UIKit)
    public init(_ platformColor: UIColor) {
        self.platformColor = platformColor
        self.color = Color(platformColor)
    }
    #elseif canImport(AppKit)
    public init(_ platformColor: NSColor) {
        self.platformColor = platformColor
        self.color = Color(platformColor)
    }
    #endif
    
    /// Create a FilesColor from RGB values
    /// - Parameters:
    ///   - red: Red component (0-1)
    ///   - green: Green component (0-1)
    ///   - blue: Blue component (0-1)
    ///   - opacity: Alpha component (0-1)
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.color = Color(red: red, green: green, blue: blue, opacity: opacity)
        
        #if canImport(UIKit)
        self.platformColor = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(opacity))
        #elseif canImport(AppKit)
        self.platformColor = NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(opacity))
        #endif
    }
    
    /// Create a FilesColor from a hex string
    /// - Parameter hex: The hex string (e.g., "#FF5500" or "FF5500")
    public init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        
        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
    
    // MARK: - Standard Colors
    
    /// Primary accent color
    public static var accent: FilesColor {
        #if canImport(UIKit)
        return FilesColor(Color.accentColor)
        #elseif canImport(AppKit)
        return FilesColor(Color.accentColor)
        #endif
    }
    
    /// Standard black color
    public static var black: FilesColor {
        return FilesColor(Color.black)
    }
    
    /// Standard blue color
    public static var blue: FilesColor {
        return FilesColor(Color.blue)
    }
    
    /// Standard gray color
    public static var gray: FilesColor {
        return FilesColor(Color.gray)
    }
    
    /// Standard green color
    public static var green: FilesColor {
        return FilesColor(Color.green)
    }
    
    /// Standard orange color
    public static var orange: FilesColor {
        return FilesColor(Color.orange)
    }
    
    /// Standard pink color
    public static var pink: FilesColor {
        return FilesColor(Color.pink)
    }
    
    /// Standard purple color
    public static var purple: FilesColor {
        return FilesColor(Color.purple)
    }
    
    /// Standard red color
    public static var red: FilesColor {
        return FilesColor(Color.red)
    }
    
    /// Standard white color
    public static var white: FilesColor {
        return FilesColor(Color.white)
    }
    
    /// Standard yellow color
    public static var yellow: FilesColor {
        return FilesColor(Color.yellow)
    }
    
    /// Clear (transparent) color
    public static var clear: FilesColor {
        return FilesColor(Color.clear)
    }
    
    /// Primary text color
    public static var primaryText: FilesColor {
        #if canImport(UIKit)
        if #available(iOS 15.0, tvOS 15.0, *) {
            return FilesColor(Color.primary)
        } else {
            return FilesColor(UIColor.label)
        }
        #elseif canImport(AppKit)
        if #available(macOS 12.0, *) {
            return FilesColor(Color.primary)
        } else {
            return FilesColor(NSColor.labelColor)
        }
        #endif
    }
    
    /// Secondary text color
    public static var secondaryText: FilesColor {
        #if canImport(UIKit)
        if #available(iOS 15.0, tvOS 15.0, *) {
            return FilesColor(Color.secondary)
        } else {
            return FilesColor(UIColor.secondaryLabel)
        }
        #elseif canImport(AppKit)
        if #available(macOS 12.0, *) {
            return FilesColor(Color.secondary)
        } else {
            return FilesColor(NSColor.secondaryLabelColor)
        }
        #endif
    }
    
    /// Primary background color
    public static var background: FilesColor {
        #if canImport(UIKit)
        return FilesColor(UIColor.systemBackground)
        #elseif canImport(AppKit)
        return FilesColor(NSColor.windowBackgroundColor)
        #endif
    }
    
    /// Secondary background color
    public static var secondaryBackground: FilesColor {
        #if canImport(UIKit)
        return FilesColor(UIColor.secondarySystemBackground)
        #elseif canImport(AppKit)
        return FilesColor(NSColor.controlBackgroundColor)
        #endif
    }
    
    // MARK: - Helper Methods
    
    /// Returns a color with modified opacity
    /// - Parameter opacity: The new opacity value (0-1)
    /// - Returns: A new FilesColor with the modified opacity
    public func opacity(_ opacity: Double) -> FilesColor {
        let newSwiftUIColor = self.color.opacity(opacity)
        return FilesColor(newSwiftUIColor)
    }
    
    /// Returns a lighter version of the color
    /// - Parameter amount: How much to lighten (0-1)
    /// - Returns: A new FilesColor that's lighter
    public func lighter(by amount: CGFloat = 0.2) -> FilesColor {
        #if canImport(UIKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return FilesColor(UIColor(
            red: min(red + amount, 1.0),
            green: min(green + amount, 1.0),
            blue: min(blue + amount, 1.0),
            alpha: alpha
        ))
        #elseif canImport(AppKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return FilesColor(NSColor(
            red: min(red + amount, 1.0),
            green: min(green + amount, 1.0),
            blue: min(blue + amount, 1.0),
            alpha: alpha
        ))
        #endif
    }
    
    /// Returns a darker version of the color
    /// - Parameter amount: How much to darken (0-1)
    /// - Returns: A new FilesColor that's darker
    public func darker(by amount: CGFloat = 0.2) -> FilesColor {
        #if canImport(UIKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return FilesColor(UIColor(
            red: max(red - amount, 0.0),
            green: max(green - amount, 0.0),
            blue: max(blue - amount, 0.0),
            alpha: alpha
        ))
        #elseif canImport(AppKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return FilesColor(NSColor(
            red: max(red - amount, 0.0),
            green: max(green - amount, 0.0),
            blue: max(blue - amount, 0.0),
            alpha: alpha
        ))
        #endif
    }
}

// MARK: - SwiftUI View Extension
extension View {
    /// Apply a foreground color using FilesColor
    /// - Parameter color: The FilesColor to use
    /// - Returns: A view with the foreground color applied
    public func foregroundColor(_ filesColor: FilesColor) -> some View {
        self.foregroundColor(filesColor.color)
    }
    
    /// Apply a background color using FilesColor
    /// - Parameter color: The FilesColor to use
    /// - Returns: A view with the background color applied
    public func backgroundColor(_ filesColor: FilesColor) -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        return self.background(filesColor.color)
        #else
        return self.background(filesColor.color)
        #endif
    }
}

// MARK: - SwiftUI Color Conversion
#if canImport(UIKit)
extension UIColor {
    /// Convert a SwiftUI Color to a UIColor
    /// - Parameter color: The SwiftUI Color to convert
    convenience init(_ color: Color) {
        if #available(iOS 14.0, tvOS 14.0, *) {
            self.init(cgColor: color.cgColor ?? UIColor.clear.cgColor)
        } else {
            // Fallback for earlier versions
            let components = color.components
            self.init(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
        }
    }
}

// Extension to get color components
fileprivate extension Color {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        if let cgColor = self.cgColor {
            UIColor(cgColor: cgColor).getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        
        return (r, g, b, a)
    }
}
#elseif canImport(AppKit)
extension NSColor {
    /// Convert a SwiftUI Color to an NSColor
    /// - Parameter color: The SwiftUI Color to convert
    convenience init?(_ color: Color) {
        if #available(macOS 14.0, *) {
            let cg = color.cgColor ?? NSColor.clear.cgColor
            self.init(cgColor: cg)
        } else {
            // Fallback for earlier versions
            let components = color.components
            self.init(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
        }
    }
}

// Extension to get color components
fileprivate extension Color {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        if let cgColor = self.cgColor {
            NSColor(cgColor: cgColor)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        
        return (r, g, b, a)
    }
}
#endif
