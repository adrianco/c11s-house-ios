//
//  SpeechRecognizer.swift
//  C11SHouse
//
//  Created on 2025-07-03.
//

import Foundation
import Speech
import AVFoundation
import Combine

/// Core speech recognition infrastructure using Apple's Speech framework
@MainActor
final class SpeechRecognizer: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""
    @Published private(set) var confidence: Float = 0.0
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published private(set) var isAvailable = false
    @Published private(set) var error: SpeechRecognitionError?
    
    // MARK: - Private Properties
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode {
        audioEngine.inputNode
    }
    
    // Configuration
    private let defaultLanguage = "en-US"
    private let requiresOnDeviceRecognition: Bool
    
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
    override init() {
        // Try to initialize with on-device recognition if available
        if #available(iOS 13.0, *) {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: defaultLanguage))
            self.requiresOnDeviceRecognition = true
            
            // Configure for on-device recognition
            self.speechRecognizer?.supportsOnDeviceRecognition = true
        } else {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: defaultLanguage))
            self.requiresOnDeviceRecognition = false
        }
        
        super.init()
        
        setupSpeechRecognizer()
        checkAuthorization()
    }
    
    // MARK: - Setup
    private func setupSpeechRecognizer() {
        speechRecognizer?.delegate = self
        
        // Check initial availability
        isAvailable = speechRecognizer?.isAvailable ?? false
        
        // Set up audio session
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = .audioEngineError
        }
    }
    
    // MARK: - Authorization
    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                
                switch status {
                case .authorized:
                    self?.checkMicrophonePermission()
                case .denied, .restricted:
                    self?.error = .notAuthorized
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func checkMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.error = .microphoneAccessDenied
                }
            }
        }
    }
    
    // MARK: - Recording Control
    func startRecording() throws {
        guard authorizationStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        
        guard speechRecognizer?.isAvailable ?? false else {
            throw SpeechRecognitionError.notAvailable
        }
        
        // Cancel any ongoing task
        stopRecording()
        
        // Configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.recognitionError("Unable to create recognition request")
        }
        
        // Configure request for real-time results
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = requiresOnDeviceRecognition && speechRecognizer?.supportsOnDeviceRecognition ?? false
        
        // Configure audio input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                    
                    // Calculate average confidence
                    let segments = result.bestTranscription.segments
                    if !segments.isEmpty {
                        let totalConfidence = segments.reduce(0) { $0 + $1.confidence }
                        self.confidence = totalConfidence / Float(segments.count)
                    }
                }
                
                if result.isFinal {
                    self.stopRecording()
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.error = .recognitionError(error.localizedDescription)
                }
                self.stopRecording()
            }
        }
        
        isRecording = true
        error = nil
    }
    
    func stopRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        
        isRecording = false
    }
    
    // MARK: - Utility Methods
    func reset() {
        stopRecording()
        transcript = ""
        confidence = 0.0
        error = nil
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            do {
                try startRecording()
            } catch {
                self.error = .recognitionError(error.localizedDescription)
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechRecognizer: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            self.isAvailable = available
            if !available {
                self.error = .notAvailable
            }
        }
    }
}

// MARK: - Transcription Result
struct TranscriptionResult {
    let text: String
    let confidence: Float
    let segments: [TranscriptionSegment]
    let isFinal: Bool
    let timestamp: Date
}

struct TranscriptionSegment {
    let text: String
    let confidence: Float
    let timestamp: TimeInterval
    let duration: TimeInterval
}