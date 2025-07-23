/*
 * CONTEXT & PURPOSE:
 * SplashView provides an animated splash screen for the C11S House app launch experience.
 * It animates the app icon components by flying the brain+circle into the house, creating
 * a delightful and meaningful transition that represents the concept of house consciousness.
 *
 * DECISION HISTORY:
 * - 2025-07-23: Initial implementation
 *   - Animated splash screen with brain+circle flying into house
 *   - Uses existing AppIconCreatorLegacy for consistent icon components
 *   - Split animation: house stays in place, brain+circle flies in
 *   - Smooth easeInOut animation for natural movement
 *   - Scale and opacity effects for engaging entrance
 *   - Completion handler for transitioning to main app
 *   - Background gradient matches app icon for cohesive branding
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct SplashView: View {
    @State private var brainOffset: CGSize = CGSize(width: -200, height: -200)
    @State private var brainScale: CGFloat = 0.3
    @State private var brainOpacity: Double = 0
    @State private var houseScale: CGFloat = 0.8
    @State private var houseOpacity: Double = 0
    @State private var isAnimationComplete = false
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient matching app icon
            LinearGradient(
                gradient: Gradient(colors: [.blue, .purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Container for animated elements
            ZStack {
                // House symbol (stays in place, fades in and scales)
                Image(systemName: "house.fill")
                    .font(.system(size: 150, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .scaleEffect(houseScale)
                    .opacity(houseOpacity)
                
                // Brain with gradient circle background (flies into house)
                ZStack {
                    // Gradient circle background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    // Brain symbol
                    Image(systemName: "brain")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(brainOffset)
                .scaleEffect(brainScale)
                .opacity(brainOpacity)
            }
        }
        .onAppear {
            performAnimation()
        }
    }
    
    private func performAnimation() {
        // Phase 1: Fade in house (0.3s)
        withAnimation(.easeOut(duration: 0.3)) {
            houseScale = 1.0
            houseOpacity = 1.0
        }
        
        // Phase 2: Start brain animation after slight delay (0.2s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Show brain at starting position
            withAnimation(.easeOut(duration: 0.2)) {
                brainOpacity = 1.0
                brainScale = 0.5
            }
            
            // Phase 3: Fly brain into house (0.8s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    brainOffset = .zero
                    brainScale = 0.7  // Final size inside house
                }
                
                // Phase 4: Brief pause, then complete (0.3s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        isAnimationComplete = true
                    }
                    
                    // Trigger completion after fade
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete()
                    }
                }
            }
        }
    }
}

// Preview
struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView {
            print("Animation complete")
        }
    }
}