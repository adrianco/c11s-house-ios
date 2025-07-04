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
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI
import UIKit

// This is a helper to create an app icon programmatically
// You can run this in a playground or temporary view to generate the icon

struct AppIconCreator {
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
            let configuration = UIImage.SymbolConfiguration(pointSize: size.width * 0.6, weight: .medium)
            
            // Draw house
            if let houseImage = UIImage(systemName: "house.fill", withConfiguration: configuration) {
                let houseRect = CGRect(
                    x: rect.width * 0.2,
                    y: rect.height * 0.2,
                    width: rect.width * 0.6,
                    height: rect.height * 0.6
                )
                houseImage.withTintColor(.white.withAlphaComponent(0.9)).draw(in: houseRect)
            }
            
            // Draw brain (centered in house)
            let brainConfig = UIImage.SymbolConfiguration(pointSize: size.width * 0.3, weight: .semibold)
            if let brainImage = UIImage(systemName: "brain.head.profile", withConfiguration: brainConfig) {
                let brainRect = CGRect(
                    x: rect.width * 0.35,
                    y: rect.height * 0.4,
                    width: rect.width * 0.3,
                    height: rect.height * 0.3
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
            Image(uiImage: AppIconCreator.createIcon(size: CGSize(width: 1024, height: 1024)))
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