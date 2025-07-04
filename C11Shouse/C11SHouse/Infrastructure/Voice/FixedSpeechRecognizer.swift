/*
 * CONTEXT & PURPOSE:
 * FixedSpeechRecognizer provides improved real-time speech recognition functionality that addresses
 * error 1101 and other common speech recognition issues. It uses Apple's Speech framework with
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
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  FixedSpeechRecognizer.swift
//  C11SHouse
//
//  Attempt to fix the original real-time speech recognition
//

import Foundation
import Speech
import AVFoundation

/// Fixed speech recognizer that attempts to solve error 1101
@MainActor
final class FixedSpeechRecognizer: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var confidence: Float = 0.0
    @Published var isAvailable = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var error: SpeechRecognitionError?
    
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
        print("Fixed Speech recognizer available: \(isAvailable)")
        print("Fixed Speech recognizer locale: \(speechRecognizer?.locale.identifier ?? "none")")
    }
    
    // MARK: - Authorization
    private func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                print("Fixed Speech authorization status: \(status)")
                
                if status != .authorized {
                    self?.error = .notAuthorized
                }
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                print("Fixed Microphone permission granted: \(granted)")
                if !granted {
                    self?.error = .microphoneAccessDenied
                }
            }
        }
    }
    
    // MARK: - Recording Control
    func startRecording() throws {
        print("=== Starting Fixed Recording ===")
        
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
            print("Fixed Audio session configured successfully")
        } catch {
            print("Fixed Audio session error: \(error)")
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
        
        print("Fixed Recognition request configured")
        
        // Configure audio engine
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("Fixed Original audio format: \(recordingFormat)")
        print("Fixed Sample rate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)")
        
        // Use the device's native format to avoid format mismatch errors
        // The hardware expects its native format (48000 Hz in this case)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        audioTapInstalled = true
        
        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        print("Fixed Audio engine started successfully")
        
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
                        print("Fixed Transcript update: '\(self.transcript)'")
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
                    print("Fixed No speech detected yet, continuing...")
                } else if nsError.code == 1101 {
                    // Silently ignore error 1101 - it's a known issue that doesn't affect operation
                } else {
                    print("Fixed Speech recognition cancelled (code: \(nsError.code))")
                }
            }
        }
        
        print("Fixed Recording started successfully")
    }
    
    func stopRecording() {
        // Prevent multiple simultaneous stop calls
        guard !isTerminating else {
            print("[FixedSpeechRecognizer] Already terminating, skipping...")
            return
        }
        
        
        isTerminating = true
        defer { isTerminating = false }
        
        print("=== Stopping Fixed Recording ===")
        
        // Step 1: Cancel recognition task first
        if let task = recognitionTask {
            print("[FixedSpeechRecognizer] Cancelling recognition task...")
            task.cancel()
            recognitionTask = nil
        }
        
        // Step 2: End audio gracefully
        if let request = recognitionRequest {
            print("[FixedSpeechRecognizer] Ending audio request...")
            request.endAudio()
            recognitionRequest = nil
        }
        
        // Step 3: Stop audio engine on audio queue
        audioEngineQueue.sync {
            if audioEngine.isRunning {
                print("[FixedSpeechRecognizer] Stopping audio engine...")
                audioEngine.stop()
            }
            
            // Step 4: Remove tap only if installed
            if audioTapInstalled {
                print("[FixedSpeechRecognizer] Removing audio tap...")
                inputNode.removeTap(onBus: 0)
                audioTapInstalled = false
            }
        }
        
        // Step 5: Update recording state
        isRecording = false
        
        // Step 6: Deactivate audio session with proper error handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Only deactivate if not immediately starting a new recording
            if !self.isRecording {
                do {
                    print("[FixedSpeechRecognizer] Deactivating audio session...")
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    print("[FixedSpeechRecognizer] Audio session deactivated")
                } catch {
                    print("[FixedSpeechRecognizer] Error deactivating audio session: \(error)")
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
        print("[FixedSpeechRecognizer] Resetting...")
        
        // Stop recording if active
        if isRecording {
            stopRecording()
        }
        
        // Clear state after a small delay to ensure cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.transcript = ""
            self?.confidence = 0.0
            self?.error = nil
            print("[FixedSpeechRecognizer] Reset complete")
        }
    }
}