/*
 * CONTEXT & PURPOSE:
 * VoiceTestView provides a testing interface for voice synthesis with different house emotions
 * and contexts. This helps verify that the TTS implementation works correctly across various
 * scenarios and emotional states that the house consciousness can express.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Initial implementation
 *   - Grid layout for emotion selection
 *   - Sample thoughts for each emotion
 *   - Direct TTS testing without HouseThoughtsView
 *   - Visual feedback for speaking state
 *   - Emotion-specific voice modulation suggestions
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct VoiceTestView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var selectedEmotion: HouseEmotion = .neutral
    @State private var isSpeaking = false
    @State private var customText = ""
    
    private var ttsService: TTSService {
        serviceContainer.ttsService
    }
    
    // Sample thoughts for each emotion
    private func sampleThought(for emotion: HouseEmotion) -> String {
        switch emotion {
        case .happy:
            return "I'm delighted to help you today! Your home is running smoothly and efficiently."
        case .curious:
            return "I've noticed an interesting pattern in your daily routines. Would you like to explore it together?"
        case .concerned:
            return "I've detected that the front door has been open for 10 minutes. Is everything alright?"
        case .excited:
            return "Great news! The solar panels are generating 20% more energy than usual today!"
        case .neutral:
            return "The house systems are operating normally. All sensors are functioning within expected parameters."
        case .confused:
            return "I'm having trouble understanding that request. Could you please clarify what you need?"
        case .proud:
            return "Together, we've reduced energy consumption by 15% this month. Excellent work!"
        case .thoughtful:
            return "Based on the weather forecast, I'm considering adjusting the heating schedule. What do you think?"
        case .worried:
            return "The smoke detector battery in the kitchen is running low. I recommend replacing it soon."
        case .content:
            return "Everything is peaceful and balanced in your home right now. It's a perfect evening."
        case .tired:
            return "I've been monitoring systems all day. Running a quick diagnostic before entering rest mode."
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Emotion Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Emotion")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(HouseEmotion.allCases, id: \.self) { emotion in
                                Button(action: {
                                    selectedEmotion = emotion
                                    if customText.isEmpty {
                                        testEmotion(emotion)
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Text(emotion.emoji)
                                            .font(.largeTitle)
                                        Text(emotion.displayName)
                                            .font(.caption)
                                            .fontWeight(selectedEmotion == emotion ? .bold : .regular)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedEmotion == emotion ? 
                                                Color.blue.opacity(0.2) : 
                                                Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedEmotion == emotion ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    
                    // Current Thought Display
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Current Thought")
                                .font(.headline)
                            Spacer()
                            if isSpeaking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        Text(customText.isEmpty ? sampleThought(for: selectedEmotion) : customText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.05))
                            )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    
                    // Custom Text Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Text (Optional)")
                            .font(.headline)
                        
                        TextField("Enter custom text to speak...", text: $customText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...5)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    
                    // Test Button
                    Button(action: {
                        testEmotion(selectedEmotion)
                    }) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                            Text("Test Voice")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                    .disabled(isSpeaking)
                    
                    // Stop Button
                    if isSpeaking {
                        Button(action: {
                            ttsService.stopSpeaking()
                            isSpeaking = false
                        }) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop Speaking")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.red)
                            .cornerRadius(25)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Voice Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onReceive(ttsService.isSpeakingPublisher) { speaking in
            isSpeaking = speaking
        }
    }
    
    private func testEmotion(_ emotion: HouseEmotion) {
        let text = customText.isEmpty ? sampleThought(for: emotion) : customText
        
        Task {
            isSpeaking = true
            do {
                // Could potentially adjust voice parameters based on emotion
                // For now, just speak with current settings
                try await ttsService.speak(text, language: nil)
            } catch {
                print("Error testing voice: \(error)")
            }
            isSpeaking = false
        }
    }
}

// MARK: - Preview

struct VoiceTestView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceTestView()
            .environmentObject(ServiceContainer.shared)
    }
}