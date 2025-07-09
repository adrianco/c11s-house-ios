/*
 * CONTEXT & PURPOSE:
 * TranscriptionView displays transcribed text from voice recordings with visual enhancements.
 * It provides a polished interface with typewriter animation effects, listening indicators,
 * empty states, and word/character count statistics to enhance the transcription experience.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Typewriter effect for new text (0.02s per character) for engaging display
 *   - Animated listening indicator with 3 pulsing dots
 *   - Empty state graphics for both listening and idle states
 *   - Word and character count footer for quick statistics
 *   - Rounded card design with shadow for depth
 *   - ScrollView for long transcriptions
 *   - Gray background for transcribed text to improve readability
 *   - onChange and onAppear triggers for typewriter effect
 *   - Timer-based character-by-character text reveal
 *   - Pulse animation on microphone icon when listening
 *   - Staggered dot animation with 0.2s delay between dots
 *   - Preview provider with multiple states for development
 *
 * - 2025-01-09: iOS 18+ migration
 *   - Updated onChange modifier to use new two-parameter closure syntax
 *   - Fixed deprecation warning for onChange(of:perform:)
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct TranscriptionView: View {
    let transcription: String
    let isListening: Bool
    
    @State private var animationOpacity: Double = 0.0
    @State private var typewriterText: String = ""
    @State private var typewriterIndex: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Transcription")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Listening indicator
                if isListening {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                                .opacity(animationOpacity)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: animationOpacity
                                )
                        }
                    }
                    .onAppear {
                        animationOpacity = 1.0
                    }
                    .onDisappear {
                        animationOpacity = 0.0
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Transcription content
            ScrollView {
                if transcription.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.3))
                            .symbolEffect(.pulse, value: isListening)
                        
                        Text(isListening ? "Listening..." : "Tap the microphone to start")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                } else {
                    // Transcribed text with typewriter effect
                    Text(typewriterText)
                        .font(.body)
                        .lineSpacing(8)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .onChange(of: transcription) { _, newValue in
                            startTypewriterEffect(text: newValue)
                        }
                        .onAppear {
                            startTypewriterEffect(text: transcription)
                        }
                }
            }
            .frame(maxHeight: .infinity)
            
            // Word count footer
            if !transcription.isEmpty {
                HStack {
                    Label("\(wordCount) words", systemImage: "text.word.spacing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label("\(characterCount) characters", systemImage: "character")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var wordCount: Int {
        transcription.split(separator: " ").count
    }
    
    private var characterCount: Int {
        transcription.count
    }
    
    private func startTypewriterEffect(text: String) {
        typewriterText = ""
        typewriterIndex = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
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

// Preview for development
struct TranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Empty state - not listening
            TranscriptionView(
                transcription: "",
                isListening: false
            )
            .frame(height: 300)
            
            // Empty state - listening
            TranscriptionView(
                transcription: "",
                isListening: true
            )
            .frame(height: 300)
            
            // With transcription
            TranscriptionView(
                transcription: "This is a sample transcription text that demonstrates how the voice recording will be displayed in the app.",
                isListening: false
            )
            .frame(height: 300)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}