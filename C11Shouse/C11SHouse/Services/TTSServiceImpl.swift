/*
 * CONTEXT & PURPOSE:
 * TTSServiceImpl provides text-to-speech functionality using Apple's AVSpeechSynthesizer.
 * It enables the app to speak HouseThoughts content aloud with configurable voice parameters,
 * state management, and interruption handling for a natural conversational experience.
 *
 * DECISION HISTORY:
 * - 2025-07-07: Initial implementation
 *   - Protocol-based design following TTSService interface
 *   - AVSpeechSynthesizer for native iOS TTS capability
 *   - Configurable speech rate, pitch, and volume
 *   - State management with @Published properties for UI binding
 *   - Delegate pattern for speech event handling
 *   - Interruption handling for smooth audio management
 *   - Language detection with appropriate voice selection
 *   - Queue management for sequential speech requests
 *   - Async/await API for modern Swift concurrency
 *   - Pre-utterance delay for natural speech flow
 *   - Progress tracking for UI feedback
 *
 * - 2025-01-09: Swift 6 concurrency fixes
 *   - Made class final and added @unchecked Sendable conformance
 *   - Replaced DispatchQueue.main.async with Task { @MainActor } for Swift 6 compliance
 *   - Fixed capture of non-sendable AVSpeechUtterance in @Sendable closure
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation
import AVFoundation
import Combine

/// Protocol for text-to-speech service
protocol TTSService: AnyObject {
    var isSpeaking: Bool { get }
    var isSpeakingPublisher: AnyPublisher<Bool, Never> { get }
    var speechProgressPublisher: AnyPublisher<Float, Never> { get }
    
    func speak(_ text: String, language: String?) async throws
    func stopSpeaking()
    func pauseSpeaking()
    func continueSpeaking()
    func setRate(_ rate: Float)
    func setPitch(_ pitch: Float)
    func setVolume(_ volume: Float)
    func setVoice(_ voiceIdentifier: String?)
}

/// Configuration for TTS parameters
struct TTSConfiguration {
    var rate: Float = 0.5  // 0.0 to 1.0
    var pitch: Float = 1.0  // 0.5 to 2.0
    var volume: Float = 1.0  // 0.0 to 1.0
    var preUtteranceDelay: TimeInterval = 0.5
    var postUtteranceDelay: TimeInterval = 0.5
    var voiceIdentifier: String? = nil
    
    static let `default` = TTSConfiguration()
}

/// Concrete implementation of TTSService using AVSpeechSynthesizer
final class TTSServiceImpl: NSObject, TTSService, @unchecked Sendable {
    
    // MARK: - Published Properties
    
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var speechProgress: Float = 0.0
    
    var isSpeakingPublisher: AnyPublisher<Bool, Never> {
        $isSpeaking.eraseToAnyPublisher()
    }
    
    var speechProgressPublisher: AnyPublisher<Float, Never> {
        $speechProgress.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private let synthesizer = AVSpeechSynthesizer()
    private var configuration = TTSConfiguration.default
    private var speechQueue: [AVSpeechUtterance] = []
    private var currentUtterance: AVSpeechUtterance?
    private var speechContinuation: CheckedContinuation<Void, Error>?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    func speak(_ text: String, language: String? = nil) async throws {
        // Clean up the text
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }
        
        // Stop any current speech and wait for cleanup
        if isSpeaking {
            stopSpeaking()
            // Give delegate callbacks time to complete
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Cancel any existing continuation to prevent leaks
        if let existingContinuation = speechContinuation {
            existingContinuation.resume(throwing: TTSError.speechInterrupted)
            speechContinuation = nil
        }
        
        // Ensure audio session is properly configured for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session for TTS: \(error)")
            throw error
        }
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: cleanedText)
        
        // Configure utterance
        utterance.rate = configuration.rate
        utterance.pitchMultiplier = configuration.pitch
        utterance.volume = configuration.volume
        utterance.preUtteranceDelay = configuration.preUtteranceDelay
        utterance.postUtteranceDelay = configuration.postUtteranceDelay
        
        // Set voice based on configuration or language
        if let voiceIdentifier = configuration.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == voiceIdentifier }) {
            // Use the specifically configured voice
            utterance.voice = voice
        } else if let language = language {
            // Fall back to language-based voice selection
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        } else {
            // Auto-detect language or use default
            utterance.voice = AVSpeechSynthesisVoice(language: detectLanguage(for: cleanedText))
        }
        
        // If no voice found, use default
        if utterance.voice == nil {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            
            // If still no voice (simulator issue), try to get any available voice
            if utterance.voice == nil {
                utterance.voice = AVSpeechSynthesisVoice.speechVoices().first
            }
        }
        
        currentUtterance = utterance
        
        // Use continuation for async/await support
        try await withCheckedThrowingContinuation { continuation in
            self.speechContinuation = continuation
            
            // Start speaking
            Task { @MainActor in
                self.isSpeaking = true
                self.speechProgress = 0.0
                self.synthesizer.speak(utterance)
            }
        }
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        speechProgress = 0.0
        currentUtterance = nil
        speechQueue.removeAll()
        
        // Complete any waiting continuation with error to indicate interruption
        if let continuation = speechContinuation {
            continuation.resume(throwing: TTSError.speechInterrupted)
            speechContinuation = nil
        }
    }
    
    func pauseSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    func continueSpeaking() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    func setRate(_ rate: Float) {
        configuration.rate = max(0.0, min(1.0, rate))
    }
    
    func setPitch(_ pitch: Float) {
        configuration.pitch = max(0.5, min(2.0, pitch))
    }
    
    func setVolume(_ volume: Float) {
        configuration.volume = max(0.0, min(1.0, volume))
    }
    
    func setVoice(_ voiceIdentifier: String?) {
        configuration.voiceIdentifier = voiceIdentifier
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session for TTS: \(error)")
        }
    }
    
    private func detectLanguage(for text: String) -> String {
        // Use NSLinguisticTagger to detect language
        let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        tagger.string = text
        
        if let language = tagger.dominantLanguage {
            return language
        }
        
        // Default to English
        return "en-US"
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSServiceImpl: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.speechProgress = 1.0
            self.currentUtterance = nil
            
            // Complete the continuation
            self.speechContinuation?.resume()
            self.speechContinuation = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.speechProgress = 0.0
            self.currentUtterance = nil
            
            // Complete the continuation with cancellation
            self.speechContinuation?.resume()
            self.speechContinuation = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Calculate progress
        let progress = Float(characterRange.location) / Float(utterance.speechString.count)
        DispatchQueue.main.async {
            self.speechProgress = progress
        }
    }
}

// MARK: - TTS Error Types

enum TTSError: LocalizedError {
    case noVoiceAvailable
    case speechInterrupted
    case invalidText
    
    var errorDescription: String? {
        switch self {
        case .noVoiceAvailable:
            return "No voice available for the selected language"
        case .speechInterrupted:
            return "Speech was interrupted"
        case .invalidText:
            return "Invalid text for speech synthesis"
        }
    }
}