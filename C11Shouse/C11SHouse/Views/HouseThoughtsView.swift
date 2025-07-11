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
import Combine
import UIKit

struct HouseThoughtsView: View {
    let thought: HouseThought
    @Binding var isMuted: Bool
    let onToggleMute: () -> Void
    
    @State private var isAnimating = false
    @State private var typewriterText = ""
    @State private var typewriterIndex = 0
    @State private var typewriterTimer: Timer?
    @State private var isSpeaking = false
    @State private var isPaused = false
    @State private var hasSpoken = false
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    private var ttsService: TTSService {
        serviceContainer.ttsService
    }
    
    var body: some View {
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
                    
                    // Voice control buttons
                    HStack(spacing: 12) {
                        // Play/Pause/Replay button
                        Button(action: handlePlayPauseAction) {
                            Image(systemName: playPauseIcon)
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.green, .mint]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .shadow(radius: 3)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isMuted)
                        .accessibilityLabel(playPauseAccessibilityLabel)
                        .accessibilityHint(playPauseAccessibilityHint)
                        
                        // Mute/Unmute button
                        Button(action: onToggleMute) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
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
                        .accessibilityLabel(isMuted ? "Unmute voice" : "Mute voice")
                        .accessibilityHint(isMuted ? "Double tap to enable voice synthesis" : "Double tap to disable voice synthesis")
                    }
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
                    .accessibilityLabel("House thought")
                    .accessibilityValue(thought.thought)
                
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
                        .foregroundColor(Color(UIColor.tertiaryLabel))
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
                observeTTSState()
                // Auto-play when not muted
                if !isMuted && !hasSpoken {
                    speakThought()
                }
                
                // Post accessibility notification for new thought
                UIAccessibility.post(notification: .announcement, argument: "New house thought: \(thought.thought)")
            }
            .onDisappear {
                isAnimating = false
                typewriterText = ""
                typewriterIndex = 0
                typewriterTimer?.invalidate()
                typewriterTimer = nil
                // Stop speaking when view disappears
                ttsService.stopSpeaking()
            }
            .onChange(of: thought.thought) { oldValue, newValue in
                // Reset speech state when thought changes
                hasSpoken = false
                isSpeaking = false
                isPaused = false
                // Auto-play new thought if not muted
                if !isMuted {
                    speakThought()
                }
            }
    }
    
    private func startTypewriterEffect(text: String) {
        // Clean up any existing timer
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        
        // Reset state
        typewriterText = ""
        typewriterIndex = 0
        
        // Start new timer
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if typewriterIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: typewriterIndex)
                typewriterText.append(text[index])
                typewriterIndex += 1
            } else {
                timer.invalidate()
                typewriterTimer = nil
            }
        }
    }
    
    // MARK: - Voice Control
    
    private var playPauseIcon: String {
        if isSpeaking && !isPaused {
            return "pause.fill"
        } else if isPaused {
            return "play.fill"
        } else if hasSpoken {
            return "arrow.clockwise"
        } else {
            return "play.fill"
        }
    }
    
    private func handlePlayPauseAction() {
        if isSpeaking && !isPaused {
            // Pause
            ttsService.pauseSpeaking()
            isPaused = true
        } else if isPaused {
            // Resume
            ttsService.continueSpeaking()
            isPaused = false
        } else {
            // Play or replay
            speakThought()
        }
    }
    
    private func speakThought() {
        guard !isMuted else { return }
        
        // Don't auto-speak if VoiceOver is running to avoid conflicts
        guard !UIAccessibility.isVoiceOverRunning else { return }
        
        // Respect reduce motion preference for auto-play
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        
        Task {
            do {
                hasSpoken = true
                isSpeaking = true
                isPaused = false
                
                // Speak the main thought
                try await ttsService.speak(thought.thought, language: nil)
                
                // If there's a suggestion, speak it too
                if let suggestion = thought.suggestion {
                    try await ttsService.speak(suggestion, language: nil)
                }
                
                isSpeaking = false
                isPaused = false
            } catch {
                // Handle speech error silently
                isSpeaking = false
                isPaused = false
                
                // Only log non-interruption errors
                if case TTSError.speechInterrupted = error {
                    // Expected when stopped manually
                } else {
                    print("Error speaking house thought: \(error)")
                }
            }
        }
    }
    
    private func observeTTSState() {
        // Subscribe to TTS state changes
        ttsService.isSpeakingPublisher
            .receive(on: DispatchQueue.main)
            .sink { speaking in
                isSpeaking = speaking
                if !speaking {
                    isPaused = false
                }
            }
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Accessibility
    
    private var playPauseAccessibilityLabel: String {
        if isSpeaking && !isPaused {
            return "Pause speech"
        } else if isPaused {
            return "Resume speech"
        } else if hasSpoken {
            return "Replay speech"
        } else {
            return "Play speech"
        }
    }
    
    private var playPauseAccessibilityHint: String {
        if isSpeaking && !isPaused {
            return "Double tap to pause the current speech"
        } else if isPaused {
            return "Double tap to resume the paused speech"
        } else if hasSpoken {
            return "Double tap to replay the house thought"
        } else {
            return "Double tap to hear the house thought"
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
    @State static var isMuted = false
    
    static var previews: some View {
        VStack(spacing: 20) {
            HouseThoughtsView(
                thought: HouseThought.samples[0],
                isMuted: $isMuted,
                onToggleMute: { isMuted.toggle() }
            )
            
            HouseThoughtsView(
                thought: HouseThought.samples[1], 
                isMuted: $isMuted,
                onToggleMute: { isMuted.toggle() }
            )
            
            HouseThoughtsView(
                thought: HouseThought.samples[2],
                isMuted: $isMuted,
                onToggleMute: { isMuted.toggle() }
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .environmentObject(ServiceContainer.shared)
    }
}