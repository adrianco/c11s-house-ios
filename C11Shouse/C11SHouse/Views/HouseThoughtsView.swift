/*
 * CONTEXT & PURPOSE:
 * HouseThoughtsView displays the house consciousness's thoughts in an engaging, animated interface.
 * It provides visual feedback through emotions, categories, and a speak button for TTS functionality,
 * creating a personality-driven interaction between the user and their intelligent home.
 *
 * DECISION HISTORY:
 * - 2025-07-07: Initial implementation
 *   - Card-based design with gradient background for visual appeal
 *   - Emotion emoji display for personality expression
 *   - Category icon and label for thought classification
 *   - Animated appearance with scale and opacity effects
 *   - Speak button for TTS integration
 *   - Confidence indicator as subtle opacity on thought text
 *   - Suggestion display with distinct styling
 *   - Smooth transitions between different thoughts
 *   - Typewriter effect for thought text appearance
 *   - Adaptive layout for different screen sizes
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct HouseThoughtsView: View {
    let thought: HouseThought?
    let onSpeak: () -> Void
    
    @State private var isAnimating = false
    @State private var typewriterText = ""
    @State private var typewriterIndex = 0
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    var body: some View {
        if let thought = thought {
            VStack(alignment: .leading, spacing: 12) {
                // Header with emotion and category
                HStack {
                    // Emotion emoji
                    Text(thought.emotion.emoji)
                        .font(.largeTitle)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("House is feeling \(thought.emotion.displayName.lowercased())")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: thought.category.icon)
                                .font(.caption)
                            Text(thought.category.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Speak button
                    Button(action: onSpeak) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(radius: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                
                // Thought content with typewriter effect
                Text(typewriterText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .opacity(0.8 + (thought.confidence * 0.2))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: thought.thought) { oldValue, newValue in
                        startTypewriterEffect(text: newValue)
                    }
                    .onAppear {
                        startTypewriterEffect(text: thought.thought)
                    }
                
                // Suggestion if available
                if let suggestion = thought.suggestion {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text(suggestion)
                            .font(.callout)
                            .italic()
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.1))
                    )
                }
                
                // Context (shown subtly)
                if let context = thought.context {
                    Text(context)
                        .font(.caption2)
                        .foregroundColor(.tertiary)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.systemBackground),
                                Color(UIColor.secondarySystemBackground)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .scaleEffect(isAnimating ? 1.0 : 0.95)
            .opacity(isAnimating ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isAnimating = true
                }
            }
            .onDisappear {
                isAnimating = false
                typewriterText = ""
                typewriterIndex = 0
            }
        }
    }
    
    private func startTypewriterEffect(text: String) {
        typewriterText = ""
        typewriterIndex = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if typewriterIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: typewriterIndex)
                typewriterText.append(text[index])
                typewriterIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// Custom button style for scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct HouseThoughtsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HouseThoughtsView(
                thought: HouseThought.samples[0],
                onSpeak: { print("Speaking thought") }
            )
            
            HouseThoughtsView(
                thought: HouseThought.samples[1],
                onSpeak: { print("Speaking thought") }
            )
            
            HouseThoughtsView(
                thought: HouseThought.samples[2],
                onSpeak: { print("Speaking thought") }
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .environmentObject(ServiceContainer.shared)
    }
}