/*
 * CONTEXT & PURPOSE:
 * AppIconCreator generates the app icon programmatically, creating a consistent
 * visual identity that represents the "conscious house" concept. It's used in
 * both the main app and onboarding flow.
 *
 * DECISION HISTORY:
 * - 2025-07-04: Initial implementation
 *   - House + brain symbols to represent consciousness
 *   - Gradient background for modern look
 *   - Programmatic generation for flexibility
 * - 2025-07-10: Made public for onboarding use
 *   - Changed from extension to standalone struct
 *   - Added customization options
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import UIKit
import SwiftUI

public struct AppIconCreator {
    
    /// Creates the app icon with the specified size
    public static func createIcon(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Create gradient background
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.systemBlue.cgColor,
                    UIColor.systemPurple.cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            )!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: rect.width, y: rect.height),
                options: []
            )
            
            // Configure symbols
            let symbolConfig = UIImage.SymbolConfiguration(
                pointSize: min(size.width, size.height) * 0.4,
                weight: .medium
            )
            
            // Draw house symbol
            if let houseImage = UIImage(systemName: "house.fill", withConfiguration: symbolConfig) {
                let houseSize = houseImage.size
                let houseRect = CGRect(
                    x: (rect.width - houseSize.width) / 2,
                    y: rect.height * 0.3 - houseSize.height / 2,
                    width: houseSize.width,
                    height: houseSize.height
                )
                
                UIColor.white.withAlphaComponent(0.9).setFill()
                houseImage.draw(in: houseRect)
            }
            
            // Draw brain symbol
            if let brainImage = UIImage(systemName: "brain", withConfiguration: symbolConfig.applying(
                UIImage.SymbolConfiguration(pointSize: min(size.width, size.height) * 0.25)
            )) {
                let brainSize = brainImage.size
                let brainRect = CGRect(
                    x: (rect.width - brainSize.width) / 2,
                    y: rect.height * 0.65 - brainSize.height / 2,
                    width: brainSize.width,
                    height: brainSize.height
                )
                
                UIColor.white.withAlphaComponent(0.8).setFill()
                brainImage.draw(in: brainRect)
            }
        }
    }
    
    /// Creates an alternate version with custom colors
    public static func createIcon(size: CGSize, primaryColor: UIColor, secondaryColor: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Create gradient background with custom colors
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    primaryColor.cgColor,
                    secondaryColor.cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            )!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: rect.width, y: rect.height),
                options: []
            )
            
            // Configure symbols
            let symbolConfig = UIImage.SymbolConfiguration(
                pointSize: min(size.width, size.height) * 0.4,
                weight: .medium
            )
            
            // Draw house symbol
            if let houseImage = UIImage(systemName: "house.fill", withConfiguration: symbolConfig) {
                let houseSize = houseImage.size
                let houseRect = CGRect(
                    x: (rect.width - houseSize.width) / 2,
                    y: rect.height * 0.3 - houseSize.height / 2,
                    width: houseSize.width,
                    height: houseSize.height
                )
                
                UIColor.white.withAlphaComponent(0.9).setFill()
                houseImage.draw(in: houseRect)
            }
            
            // Draw brain symbol
            if let brainImage = UIImage(systemName: "brain", withConfiguration: symbolConfig.applying(
                UIImage.SymbolConfiguration(pointSize: min(size.width, size.height) * 0.25)
            )) {
                let brainSize = brainImage.size
                let brainRect = CGRect(
                    x: (rect.width - brainSize.width) / 2,
                    y: rect.height * 0.65 - brainSize.height / 2,
                    width: brainSize.width,
                    height: brainSize.height
                )
                
                UIColor.white.withAlphaComponent(0.8).setFill()
                brainImage.draw(in: brainRect)
            }
        }
    }
}