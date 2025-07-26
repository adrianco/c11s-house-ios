/*
 * CONTEXT & PURPOSE:
 * CreateAppIcon.swift provides a programmatic way to generate the C11S House app icon using
 * Core Graphics and SF Symbols. It creates a gradient background with a house symbol containing
 * a brain symbol, representing the concept of "house consciousness" or intelligent home.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Programmatic icon generation for consistency and easy updates
 *   - Blue to purple gradient representing technology and innovation
 *   - House symbol as primary element (60% of icon size)
 *   - Brain symbol nested inside house (30% size) for consciousness concept
 *   - White symbols with transparency for visual hierarchy
 *   - UIGraphicsImageRenderer for high-quality rendering
 *   - 1024x1024 base size for App Store requirements
 *   - Preview component for development visualization
 *   - SF Symbols for crisp, scalable icons
 *   - Linear gradient from top-left to bottom-right
 * - 2025-07-04: Improved brain symbol visibility
 *   - Changed from brain.head.profile to standalone brain symbol
 *   - Added contrasting background circle for brain
 *   - Removed transparency for better visibility
 *   - Adjusted positioning for better visual balance
 * - 2025-07-04: Icon refinements
 *   - Increased house size to fill more of the icon (60% -> 85%)
 *   - Removed grey circle background from brain
 *   - Moved brain lower and made it larger (25% -> 40%)
 *   - Better visual balance with larger elements
 * - 2025-07-04: Added blue background circle for brain
 *   - Blue circle background matching icon's blue gradient color
 *   - Provides contrast for white brain symbol
 *   - Creates visual cohesion with overall design
 * - 2025-07-04: Gradient circle and positioning update
 *   - Changed circle to use matching blue-to-purple gradient
 *   - Moved brain and circle up for better visual balance
 *   - Gradient flows diagonally like main background
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI
import UIKit

// This is a helper to create an app icon programmatically
// You can run this in a playground or temporary view to generate the icon

// Note: AppIconCreator is now defined in Models/AppIconCreator.swift
// This file is kept for reference and the preview

struct AppIconCreatorLegacy {
    static func createIcon(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Background gradient
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.systemBlue.cgColor,
                    UIColor.systemPurple.cgColor
                ] as CFArray,
                locations: [0, 1]
            )!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: rect.width, y: rect.height),
                options: []
            )
            
            // Configure for drawing
            let configuration = UIImage.SymbolConfiguration(pointSize: size.width * 0.85, weight: .medium)
            
            // Draw house (larger to fill icon)
            if let houseImage = UIImage(systemName: "house.fill", withConfiguration: configuration) {
                let houseRect = CGRect(
                    x: rect.width * 0.075,
                    y: rect.height * 0.075,
                    width: rect.width * 0.85,
                    height: rect.height * 0.85
                )
                houseImage.withTintColor(.white.withAlphaComponent(0.9)).draw(in: houseRect)
            }
            
            // Draw brain with gradient background circle
            // First draw gradient circle background
            let brainBackgroundRect = CGRect(
                x: rect.width * 0.275,
                y: rect.height * 0.375,
                width: rect.width * 0.45,
                height: rect.width * 0.45
            )
            
            // Save current context state
            context.cgContext.saveGState()
            
            // Create circular clipping path
            let circlePath = UIBezierPath(ovalIn: brainBackgroundRect)
            circlePath.addClip()
            
            // Draw gradient within the circle
            let circleGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.systemBlue.cgColor,
                    UIColor.systemPurple.cgColor
                ] as CFArray,
                locations: [0, 1]
            )!
            
            context.cgContext.drawLinearGradient(
                circleGradient,
                start: CGPoint(x: brainBackgroundRect.minX, y: brainBackgroundRect.minY),
                end: CGPoint(x: brainBackgroundRect.maxX, y: brainBackgroundRect.maxY),
                options: []
            )
            
            // Restore context state
            context.cgContext.restoreGState()
            
            // Draw brain symbol on top
            let brainConfig = UIImage.SymbolConfiguration(pointSize: size.width * 0.4, weight: .bold)
            if let brainImage = UIImage(systemName: "brain", withConfiguration: brainConfig) {
                let brainRect = CGRect(
                    x: rect.width * 0.3,
                    y: rect.height * 0.4,
                    width: rect.width * 0.4,
                    height: rect.width * 0.4
                )
                brainImage.withTintColor(.white).draw(in: brainRect)
            }
        }
    }
    
    /// Create house icon without brain
    static func createHouseOnly(size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Background gradient
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = rect
            gradientLayer.colors = [
                UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).cgColor,
                UIColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1.0).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            
            UIGraphicsBeginImageContext(size)
            if let currentContext = UIGraphicsGetCurrentContext() {
                gradientLayer.render(in: currentContext)
            }
            let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            gradientImage?.draw(in: rect)
            
            // Draw house shape
            let housePath = UIBezierPath()
            let houseWidth = size.width * 0.6
            let houseHeight = size.height * 0.5
            let houseX = (size.width - houseWidth) / 2
            let houseY = size.height * 0.35
            
            // House body
            housePath.move(to: CGPoint(x: houseX, y: houseY + houseHeight * 0.4))
            housePath.addLine(to: CGPoint(x: houseX, y: houseY + houseHeight))
            housePath.addLine(to: CGPoint(x: houseX + houseWidth, y: houseY + houseHeight))
            housePath.addLine(to: CGPoint(x: houseX + houseWidth, y: houseY + houseHeight * 0.4))
            
            // Roof
            housePath.move(to: CGPoint(x: houseX - houseWidth * 0.1, y: houseY + houseHeight * 0.4))
            housePath.addLine(to: CGPoint(x: houseX + houseWidth / 2, y: houseY))
            housePath.addLine(to: CGPoint(x: houseX + houseWidth * 1.1, y: houseY + houseHeight * 0.4))
            housePath.close()
            
            UIColor.white.setFill()
            housePath.fill()
            
            // Add subtle inner shadow
            context.cgContext.saveGState()
            context.cgContext.addPath(housePath.cgPath)
            context.cgContext.clip()
            
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 10,
                color: UIColor.black.withAlphaComponent(0.3).cgColor
            )
            
            UIColor.clear.setFill()
            housePath.fill()
            
            context.cgContext.restoreGState()
        }
    }
    
    /// Create brain with circle background
    static func createBrainCircle(size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Draw circle background
            let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            
            // Gradient for circle
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = rect
            gradientLayer.colors = [
                UIColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0).cgColor,
                UIColor(red: 0.3, green: 0.1, blue: 0.6, alpha: 1.0).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            
            UIGraphicsBeginImageContext(size)
            if let currentContext = UIGraphicsGetCurrentContext() {
                currentContext.addPath(circlePath.cgPath)
                currentContext.clip()
                gradientLayer.render(in: currentContext)
            }
            let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            gradientImage?.draw(in: rect)
            
            // Draw brain symbol
            let brainConfig = UIImage.SymbolConfiguration(pointSize: size.width * 0.6, weight: .bold)
            if let brainImage = UIImage(systemName: "brain", withConfiguration: brainConfig) {
                let brainRect = CGRect(
                    x: rect.width * 0.2,
                    y: rect.height * 0.2,
                    width: rect.width * 0.6,
                    height: rect.width * 0.6
                )
                brainImage.withTintColor(.white).draw(in: brainRect)
            }
        }
    }
}

// Preview in SwiftUI
struct AppIconPreview: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: AppIconCreatorLegacy.createIcon(size: CGSize(width: 1024, height: 1024)))
                .resizable()
                .frame(width: 200, height: 200)
                .cornerRadius(40)
                .shadow(radius: 10)
            
            Text("C11S House App Icon")
                .font(.title2)
        }
        .padding()
    }
}