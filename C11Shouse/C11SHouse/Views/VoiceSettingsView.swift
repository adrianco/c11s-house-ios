/*
 * CONTEXT & PURPOSE:
 * VoiceSettingsView provides user interface for customizing text-to-speech settings.
 * Users can adjust speech rate, pitch, volume, and select their preferred voice,
 * enabling personalization of how the house consciousness speaks to them.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Initial implementation
 *   - SwiftUI-based settings interface
 *   - Sliders for rate, pitch, and volume control
 *   - Voice picker with system voices
 *   - Preview button to test settings
 *   - Persistence using @AppStorage
 *   - Real-time updates to TTS service
 *   - Accessibility support
 *   - Default values matching TTSConfiguration
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI
import AVFoundation

struct VoiceSettingsView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    // Persisted settings
    @AppStorage("tts_rate") private var speechRate: Double = 0.5
    @AppStorage("tts_pitch") private var speechPitch: Double = 1.0
    @AppStorage("tts_volume") private var speechVolume: Double = 1.0
    @AppStorage("tts_voice_identifier") private var selectedVoiceIdentifier: String = ""
    
    // Local state
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var isTestingSpeech = false
    @State private var selectedLanguage = "en-US"
    
    private var ttsService: TTSService {
        serviceContainer.ttsService
    }
    
    // Sample text for testing
    private let sampleTexts = [
        "Hello! I'm your house consciousness. How can I assist you today?",
        "The temperature is currently 72 degrees. Would you like me to adjust it?",
        "Good morning! I've prepared your daily briefing.",
        "I notice you're starting a conversation. I'm here to help!"
    ]
    
    var body: some View {
        Form {
                // Voice Selection Section
                Section(header: Text("Voice Selection")) {
                    Picker("Language", selection: $selectedLanguage) {
                        Text("English (US)").tag("en-US")
                        Text("English (UK)").tag("en-GB")
                        Text("English (AU)").tag("en-AU")
                        Text("English (IN)").tag("en-IN")
                    }
                    .onChange(of: selectedLanguage) { _, newValue in
                        loadVoices(for: newValue)
                    }
                    
                    if !availableVoices.isEmpty {
                        Picker("Voice", selection: $selectedVoiceIdentifier) {
                            ForEach(availableVoices, id: \.identifier) { voice in
                                HStack {
                                    Text(voiceName(for: voice))
                                    if voice.quality == .enhanced {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                    }
                                }
                                .tag(voice.identifier)
                            }
                        }
                        .onChange(of: selectedVoiceIdentifier) { _, newValue in
                            ttsService.setVoice(newValue.isEmpty ? nil : newValue)
                        }
                    }
                }
                
                // Speech Parameters Section
                Section(header: Text("Speech Parameters")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Rate")
                            Spacer()
                            Text(String(format: "%.1fx", speechRate))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $speechRate, in: 0.0...1.0, step: 0.1)
                            .onChange(of: speechRate) { _, newValue in
                                ttsService.setRate(Float(newValue))
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Pitch")
                            Spacer()
                            Text(String(format: "%.1f", speechPitch))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $speechPitch, in: 0.5...2.0, step: 0.1)
                            .onChange(of: speechPitch) { _, newValue in
                                ttsService.setPitch(Float(newValue))
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text(String(format: "%.0f%%", speechVolume * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $speechVolume, in: 0.0...1.0, step: 0.05)
                            .onChange(of: speechVolume) { _, newValue in
                                ttsService.setVolume(Float(newValue))
                            }
                    }
                }
                
                // Preview Section
                Section(header: Text("Preview")) {
                    ForEach(sampleTexts, id: \.self) { text in
                        Button(action: {
                            testSpeech(with: text)
                        }) {
                            HStack {
                                Text(text)
                                    .font(.callout)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if isTestingSpeech {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(isTestingSpeech)
                    }
                }
                
            }
        .navigationTitle("Voice Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: resetToDefaults) {
                    Text("Reset")
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            loadVoices(for: selectedLanguage)
            applyCurrentSettings()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadVoices(for language: String) {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language) }
            .sorted { voice1, voice2 in
                // Sort enhanced voices first
                if voice1.quality == .enhanced && voice2.quality != .enhanced {
                    return true
                } else if voice1.quality != .enhanced && voice2.quality == .enhanced {
                    return false
                }
                // Then sort by name
                return voiceName(for: voice1) < voiceName(for: voice2)
            }
        
        // Select first voice if current selection is invalid
        if !availableVoices.contains(where: { $0.identifier == selectedVoiceIdentifier }) {
            selectedVoiceIdentifier = availableVoices.first?.identifier ?? ""
        }
    }
    
    private func voiceName(for voice: AVSpeechSynthesisVoice) -> String {
        // Extract a friendly name from the voice
        let components = voice.identifier.split(separator: ".")
        if let nameComponent = components.last {
            return String(nameComponent).replacingOccurrences(of: "-", with: " ")
        }
        return voice.name
    }
    
    private func testSpeech(with text: String) {
        guard !isTestingSpeech else { return }
        
        Task {
            isTestingSpeech = true
            defer { isTestingSpeech = false }
            
            do {
                // Stop any current speech
                ttsService.stopSpeaking()
                
                // Apply current settings including voice
                applyCurrentSettings()
                
                // Speak the test text
                try await ttsService.speak(text, language: selectedLanguage)
            } catch {
                print("Error testing speech: \(error)")
            }
        }
    }
    
    private func applyCurrentSettings() {
        ttsService.setRate(Float(speechRate))
        ttsService.setPitch(Float(speechPitch))
        ttsService.setVolume(Float(speechVolume))
        ttsService.setVoice(selectedVoiceIdentifier.isEmpty ? nil : selectedVoiceIdentifier)
    }
    
    private func resetToDefaults() {
        speechRate = 0.5
        speechPitch = 1.0
        speechVolume = 1.0
        selectedVoiceIdentifier = ""
        
        applyCurrentSettings()
    }
}

// MARK: - Preview

struct VoiceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceSettingsView()
            .environmentObject(ServiceContainer.shared)
    }
}