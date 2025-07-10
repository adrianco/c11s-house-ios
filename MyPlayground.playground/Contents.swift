import SwiftUI
import UIKit
import PlaygroundSupport

// This is a helper to create an app icon programmatically
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
}

// Full screen view to show actual 1024x1024 image
struct FullScreenIconView: View {
    let iconImage = AppIconCreator.createIcon(size: CGSize(width: 1024, height: 1024))
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                // Display at actual 1024x1024 size
                Image(uiImage: iconImage)
                    .resizable()
                    .frame(width: 1024, height: 1024)
                    .clipped()
                
                Text("1024 x 1024 pixels")
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

// Set up the live view to show full size
let hostingController = UIHostingController(rootView: FullScreenIconView())
hostingController.preferredContentSize = CGSize(width: 1200, height: 1200)
PlaygroundPage.current.setLiveView(hostingController)
