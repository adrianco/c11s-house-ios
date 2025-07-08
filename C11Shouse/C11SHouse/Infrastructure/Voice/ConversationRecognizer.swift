/*
 * CONTEXT & PURPOSE:
 * ConversationRecognizer provides real-time speech recognition functionality for natural
 * conversations with the house consciousness. It uses Apple's Speech framework with
 * careful configuration to ensure stable operation, thread safety, and proper resource cleanup.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation to fix speech recognition errors
 *   - Addressed error 1101 (speech recording error) by proper audio session configuration
 *   - Used playAndRecord category with measurement mode for accurate speech recognition
 *   - Disabled requiresOnDeviceRecognition to avoid device limitations
 *   - Thread-safe audio engine operations using dedicated dispatch queue
 *   - Proper state management to prevent race conditions during stop/start
 *   - Comprehensive error handling with specific error codes filtering
 *   - Ignored benign errors (1110: no speech, 1101: recording error) during normal operation
 *   - Used device's native audio format (48kHz) to avoid format mismatch
 *   - Buffer size: 4096 frames for balance between latency and stability
 *   - Graceful shutdown sequence: cancel task → end audio → stop engine → remove tap
 *   - Delayed audio session deactivation to prevent conflicts
 *   - Confidence calculation from speech segments
 *   - Thread safety with isTerminating flag to prevent concurrent stops
 * - 2025-07-04: Renamed from FixedSpeechRecognizer to ConversationRecognizer
 *   - Updated class name to reflect purpose as conversation handler
 *   - Maintained all error handling and stability improvements
 *   - Updated logging prefixes for clarity
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  ConversationRecognizer.swift
//  C11SHouse
//
//  Speech recognition engine for house consciousness conversations
//

import Foundation
import Speech
import AVFoundation

/// Speech recognizer optimized for conversational interactions
@MainActor
final class ConversationRecognizer: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var confidence: Float = 0.0
    @Published var isAvailable = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var error: SpeechRecognitionError?
    @Published var currentHouseThought: HouseThought?
    
    // MARK: - Private Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Audio setup matching the working SimpleSpeechRecognizer
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode { audioEngine.inputNode }
    
    // Thread safety
    private var isTerminating = false
    private var audioTapInstalled = false
    private let audioEngineQueue = DispatchQueue(label: "com.c11s.audioEngine")
    
    // MARK: - Error Types
    enum SpeechRecognitionError: LocalizedError {
        case notAuthorized
        case notAvailable
        case audioEngineError
        case recognitionError(String)
        case microphoneAccessDenied
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition not authorized"
            case .notAvailable:
                return "Speech recognition not available"
            case .audioEngineError:
                return "Audio engine error"
            case .recognitionError(let message):
                return "Recognition error: \(message)"
            case .microphoneAccessDenied:
                return "Microphone access denied"
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        setupSpeechRecognizer()
        checkAuthorization()
    }
    
    // MARK: - Setup
    private func setupSpeechRecognizer() {
        isAvailable = speechRecognizer?.isAvailable ?? false
        print("Conversation recognizer available: \(isAvailable)")
        print("Conversation recognizer locale: \(speechRecognizer?.locale.identifier ?? "none")")
    }
    
    // MARK: - Authorization
    private func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                print("Conversation authorization status: \(status)")
                
                if status != .authorized {
                    self?.error = .notAuthorized
                }
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                print("Conversation microphone permission granted: \(granted)")
                if !granted {
                    self?.error = .microphoneAccessDenied
                }
            }
        }
    }
    
    // MARK: - Recording Control
    func startRecording() throws {
        print("=== Starting Conversation Recording ===")
        
        // Reset state
        error = nil
        transcript = ""
        confidence = 0.0
        
        // Check permissions
        guard authorizationStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        
        guard speechRecognizer?.isAvailable ?? false else {
            throw SpeechRecognitionError.notAvailable
        }
        
        // Clean up any previous state without going through full stopRecording
        if audioEngine.isRunning {
            audioEngine.stop()
            if audioTapInstalled {
                inputNode.removeTap(onBus: 0)
                audioTapInstalled = false
            }
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        
        // Configure audio session to match working implementation
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use SAME configuration as working SimpleSpeechRecognizer
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [])
            try audioSession.setActive(true, options: [])
            print("Conversation audio session configured successfully")
        } catch {
            print("Conversation audio session error: \(error)")
            throw SpeechRecognitionError.audioEngineError
        }
        
        // Create recognition request - with EXPLICIT settings to avoid on-device
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.recognitionError("Unable to create recognition request")
        }
        
        // CRITICAL: Configure request to match working approach
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false  // NEVER use on-device
        
        // Only add punctuation if iOS 16+ and it won't cause issues
        if #available(iOS 16.0, *) {
            do {
                recognitionRequest.addsPunctuation = false  // Start without punctuation to avoid issues
            }
        }
        
        print("Conversation recognition request configured")
        
        // Configure audio engine
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("Conversation audio format: \(recordingFormat)")
        print("Sample rate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)")
        
        // Use the device's native format to avoid format mismatch errors
        // The hardware expects its native format (48000 Hz in this case)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        audioTapInstalled = true
        
        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        print("Conversation audio engine started successfully")
        
        // Set recording flag early to prevent race conditions
        isRecording = true
        
        // Start recognition task with detailed error handling
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    let newTranscript = result.bestTranscription.formattedString
                    // Don't clear transcript if we're terminating and new transcript is empty
                    if !newTranscript.isEmpty || (!self.isTerminating && self.isRecording) {
                        self.transcript = newTranscript
                        print("Conversation transcript update: '\(self.transcript)'")
                    }
                    
                    // Calculate confidence
                    let segments = result.bestTranscription.segments
                    if !segments.isEmpty {
                        let totalConfidence = segments.reduce(0) { $0 + $1.confidence }
                        self.confidence = totalConfidence / Float(segments.count)
                    }
                }
                
                // Don't auto-stop on final results for continuous recognition
            }
            
            if let error = error {
                let nsError = error as NSError
                
                // Filter out cancellation errors and "no speech detected" during normal operation
                let cancellationCodes = [203, 216, 301] // Cancellation codes
                let ignorableCodes = [1110, 1101] // "No speech detected", "Speech recording error"
                
                if !cancellationCodes.contains(nsError.code) && !ignorableCodes.contains(nsError.code) {
                    DispatchQueue.main.async {
                        self.error = .recognitionError(error.localizedDescription)
                        if self.isRecording && !self.isTerminating {
                            self.stopRecording()
                        }
                    }
                } else if nsError.code == 1110 {
                    print("Conversation: No speech detected yet, continuing...")
                } else if nsError.code == 1101 {
                    // Silently ignore error 1101 - it's a known issue that doesn't affect operation
                } else {
                    print("Conversation recognition cancelled (code: \(nsError.code))")
                }
            }
        }
        
        print("Conversation recording started successfully")
    }
    
    func stopRecording() {
        // Prevent multiple simultaneous stop calls
        guard !isTerminating else {
            print("[ConversationRecognizer] Already terminating, skipping...")
            return
        }
        
        
        isTerminating = true
        defer { isTerminating = false }
        
        print("=== Stopping Conversation Recording ===")
        
        // Step 1: Cancel recognition task first
        if let task = recognitionTask {
            print("[ConversationRecognizer] Cancelling recognition task...")
            task.cancel()
            recognitionTask = nil
        }
        
        // Step 2: End audio gracefully
        if let request = recognitionRequest {
            print("[ConversationRecognizer] Ending audio request...")
            request.endAudio()
            recognitionRequest = nil
        }
        
        // Step 3: Stop audio engine on audio queue
        audioEngineQueue.sync {
            if audioEngine.isRunning {
                print("[ConversationRecognizer] Stopping audio engine...")
                audioEngine.stop()
            }
            
            // Step 4: Remove tap only if installed
            if audioTapInstalled {
                print("[ConversationRecognizer] Removing audio tap...")
                inputNode.removeTap(onBus: 0)
                audioTapInstalled = false
            }
        }
        
        // Step 5: Update recording state (already on main thread due to @MainActor)
        isRecording = false
        
        // Step 6: Deactivate audio session with proper error handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Only deactivate if not immediately starting a new recording
            if !self.isRecording {
                do {
                    print("[ConversationRecognizer] Deactivating audio session...")
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    print("[ConversationRecognizer] Audio session deactivated")
                } catch {
                    print("[ConversationRecognizer] Error deactivating audio session: \(error)")
                    // Non-fatal error, continue
                }
            }
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            do {
                try startRecording()
            } catch {
                self.error = error as? SpeechRecognitionError ?? .audioEngineError
            }
        }
    }
    
    func reset() {
        print("[ConversationRecognizer] Resetting...")
        
        // Stop recording if active
        if isRecording {
            stopRecording()
        }
        
        // Clear state after a small delay to ensure cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.transcript = ""
            self?.confidence = 0.0
            self?.error = nil
            self?.currentHouseThought = nil
            print("[ConversationRecognizer] Reset complete")
        }
    }
    
    // MARK: - House Thoughts Generation
    
    /// Generate a house thought based on the current transcript
    func generateHouseThought(from transcript: String) {
        // Simple rule-based generation for now
        // In a real implementation, this could call an AI service
        
        let lowercasedTranscript = transcript.lowercased()
        
        // Determine emotion and category based on content
        var emotion: HouseEmotion = .neutral
        var category: ThoughtCategory = .observation
        var thought = ""
        var suggestion: String? = nil
        
        // Greetings
        if lowercasedTranscript.contains("hello") || lowercasedTranscript.contains("hi") || 
           lowercasedTranscript.contains("good morning") || lowercasedTranscript.contains("good evening") {
            emotion = .happy
            category = .greeting
            thought = "Hello! I'm glad you're here. How can I help you manage your home today?"
        }
        // Temperature related
        else if lowercasedTranscript.contains("temperature") || lowercasedTranscript.contains("cold") || 
                lowercasedTranscript.contains("hot") || lowercasedTranscript.contains("warm") {
            emotion = .thoughtful
            category = .suggestion
            thought = "I can help you adjust the temperature for optimal comfort."
            suggestion = "Would you like me to check the current temperature settings?"
        }
        // Lights
        else if lowercasedTranscript.contains("light") || lowercasedTranscript.contains("dark") ||
                lowercasedTranscript.contains("bright") {
            emotion = .curious
            category = .question
            thought = "I notice you mentioned lighting. Are you looking to adjust the ambiance?"
        }
        // Questions
        else if lowercasedTranscript.contains("?") || lowercasedTranscript.contains("what") ||
                lowercasedTranscript.contains("how") || lowercasedTranscript.contains("when") {
            emotion = .curious
            category = .observation
            thought = "That's an interesting question. Let me think about how I can help with that."
        }
        // Learning
        else if lowercasedTranscript.contains("remember") || lowercasedTranscript.contains("note") ||
                lowercasedTranscript.contains("remind") {
            emotion = .thoughtful
            category = .memory
            thought = "I'll make note of that for future reference."
        }
        // Default
        else {
            emotion = .neutral
            category = .observation
            thought = "I'm listening and learning from our conversation."
        }
        
        // Create and publish the house thought
        currentHouseThought = HouseThought(
            thought: thought,
            emotion: emotion,
            category: category,
            confidence: Double(confidence),
            context: "User said: \"\(transcript)\"",
            suggestion: suggestion
        )
    }
    
    /// Set a house thought for displaying a question
    func setQuestionThought(_ question: String) {
        currentHouseThought = HouseThought(
            thought: question,
            emotion: .curious,
            category: .question,
            confidence: 1.0,
            context: "House Question",
            suggestion: nil
        )
    }
    
    /// Clear the current house thought
    func clearHouseThought() {
        currentHouseThought = nil
    }
    
    /// Set a thank you thought when all questions are reviewed
    func setThankYouThought() {
        currentHouseThought = HouseThought(
            thought: "Thank you! All your information is up to date. How else can I help you?",
            emotion: .happy,
            category: .greeting,
            confidence: 1.0,
            context: "Questions Complete",
            suggestion: nil
        )
    }
}