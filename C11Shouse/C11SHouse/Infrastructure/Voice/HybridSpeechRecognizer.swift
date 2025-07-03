//
//  HybridSpeechRecognizer.swift
//  C11SHouse
//
//  Hybrid approach that uses file-based recording with near real-time transcription
//

import Foundation
import Speech
import AVFoundation
import Combine

/// Speech recognizer that uses file-based recording for reliability
@MainActor
final class HybridSpeechRecognizer: ObservableObject {
    
    // MARK: - Published Properties
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var isAvailable = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var error: SpeechRecognitionError?
    @Published var confidence: Float = 0.0
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var currentRecordingURL: URL?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // For chunked recording
    private var chunkIndex = 0
    private var fullTranscript = ""
    private let chunkDuration: TimeInterval = 5.0 // Process chunks every 5 seconds
    
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
                return "Audio recording error"
            case .recognitionError(let message):
                return "Recognition error: \(message)"
            case .microphoneAccessDenied:
                return "Microphone access denied"
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkAuthorization()
        setupSpeechRecognizer()
    }
    
    // MARK: - Setup
    private func setupSpeechRecognizer() {
        isAvailable = speechRecognizer?.isAvailable ?? false
    }
    
    // MARK: - Authorization
    private func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                if status != .authorized {
                    self?.error = .notAuthorized
                }
            }
        }
        
        // Also check microphone
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
        // Reset state
        error = nil
        fullTranscript = ""
        transcript = ""
        chunkIndex = 0
        
        // Check permissions
        guard authorizationStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        
        guard speechRecognizer?.isAvailable ?? false else {
            throw SpeechRecognitionError.notAvailable
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
        
        // Start recording first chunk
        try startNewChunk()
        
        isRecording = true
    }
    
    private func startNewChunk() throws {
        // Stop current recording if any
        audioRecorder?.stop()
        
        // Create new recording URL
        let tempDir = FileManager.default.temporaryDirectory
        currentRecordingURL = tempDir.appendingPathComponent("chunk_\(chunkIndex)_\(Date().timeIntervalSince1970).m4a")
        
        // Configure recorder
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: currentRecordingURL!, settings: settings)
        audioRecorder?.record()
        
        // Schedule processing of this chunk
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.processCurrentChunk()
            }
        }
    }
    
    private func processCurrentChunk() {
        guard let url = currentRecordingURL else { return }
        
        // Transcribe the chunk
        transcribeChunk(url: url)
        
        // Start next chunk if still recording
        if isRecording {
            chunkIndex += 1
            do {
                try startNewChunk()
            } catch {
                self.error = .audioEngineError
                stopRecording()
            }
        }
    }
    
    private func transcribeChunk(url: URL) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = false
        request.shouldReportPartialResults = false
        
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    // Append to full transcript
                    if !self.fullTranscript.isEmpty {
                        self.fullTranscript += " "
                    }
                    self.fullTranscript += result.bestTranscription.formattedString
                    self.transcript = self.fullTranscript
                    
                    // Update confidence
                    let segments = result.bestTranscription.segments
                    if !segments.isEmpty {
                        let totalConfidence = segments.reduce(0) { $0 + $1.confidence }
                        self.confidence = totalConfidence / Float(segments.count)
                    }
                }
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: url)
            }
            
            if let error = error {
                print("Chunk transcription error: \(error)")
                // Don't stop recording on chunk errors, just continue
            }
        }
    }
    
    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        // Process final chunk
        if let url = currentRecordingURL {
            processCurrentChunk()
        }
        
        isRecording = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    // MARK: - Utility Methods
    func reset() {
        stopRecording()
        transcript = ""
        fullTranscript = ""
        confidence = 0.0
        error = nil
        chunkIndex = 0
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
}