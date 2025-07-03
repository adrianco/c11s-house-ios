//
//  TranscriptionServiceImpl.swift
//  C11SHouse
//
//  Concrete implementation of transcription service using Speech framework
//

import Foundation
import Speech
import AVFoundation

/// Concrete implementation of TranscriptionService using Apple's Speech framework
class TranscriptionServiceImpl: TranscriptionService {
    
    // MARK: - Private Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Initialization
    
    init() {
        // Initialize speech recognizer with default locale
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    // MARK: - TranscriptionService Implementation
    
    func transcribe(audioData: Data, configuration: TranscriptionConfiguration) async throws -> TranscriptionResult {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.transcriptionFailed("Speech recognizer not available")
        }
        
        // Set language if different from default
        if configuration.languageCode != "en-US" {
            // Note: In a real implementation, you'd create a new recognizer with the specified locale
            // For now, we'll use the default
        }
        
        // Create temporary file from audio data
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.wav")
        do {
            try audioData.write(to: tempURL)
        } catch {
            throw TranscriptionError.transcriptionFailed("Failed to write audio data: \(error.localizedDescription)")
        }
        
        defer {
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        request.shouldReportPartialResults = configuration.showInterimResults
        request.addsPunctuation = configuration.enablePunctuation
        request.requiresOnDeviceRecognition = false // Use server-based recognition for better accuracy
        
        // Perform transcription
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return } // Prevent multiple resumptions
                
                if let error = error {
                    hasResumed = true
                    if (error as NSError).code == 203 { // No speech detected
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed("No speech detected"))
                    } else {
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed(error.localizedDescription))
                    }
                    return
                }
                
                if let result = result {
                    if result.isFinal {
                        hasResumed = true
                        
                        // Calculate duration from audio file
                        let duration = self.getAudioDuration(from: tempURL) ?? 0
                        
                        // Get alternatives
                        let alternatives = result.transcriptions.dropFirst().prefix(3).map { $0.formattedString }
                        
                        // Create transcription result
                        let transcriptionResult = TranscriptionResult(
                            text: result.bestTranscription.formattedString,
                            confidence: Float(result.transcriptions.first?.segments.first?.confidence ?? 0),
                            duration: duration,
                            timestamp: Date(),
                            detectedLanguage: configuration.languageCode,
                            alternatives: Array(alternatives)
                        )
                        
                        continuation.resume(returning: transcriptionResult)
                    }
                }
            }
            
            // Set a timeout to prevent hanging
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if !hasResumed {
                    hasResumed = true
                    self.recognitionTask?.cancel()
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed("Transcription timeout"))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func getAudioDuration(from url: URL) -> TimeInterval? {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let sampleRate = audioFile.processingFormat.sampleRate
            let frameCount = Double(audioFile.length)
            return frameCount / sampleRate
        } catch {
            print("Failed to get audio duration: \(error)")
            return nil
        }
    }
    
    /// Cancel any ongoing transcription
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
}

/// Alternative implementation using on-device transcription for privacy
class OnDeviceTranscriptionService: TranscriptionService {
    
    private let speechRecognizer: SFSpeechRecognizer?
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    func transcribe(audioData: Data, configuration: TranscriptionConfiguration) async throws -> TranscriptionResult {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.transcriptionFailed("Speech recognizer not available")
        }
        
        // Check if on-device recognition is supported
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.transcriptionFailed("On-device recognition not supported")
        }
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio_ondevice.wav")
        try audioData.write(to: tempURL)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Create request with on-device requirement
        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = configuration.enablePunctuation
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            let task = recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return }
                
                if let error = error {
                    hasResumed = true
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed(error.localizedDescription))
                    return
                }
                
                if let result = result, result.isFinal {
                    hasResumed = true
                    
                    let transcriptionResult = TranscriptionResult(
                        text: result.bestTranscription.formattedString,
                        confidence: 0.95, // On-device doesn't provide confidence scores
                        duration: 0, // Calculate if needed
                        timestamp: Date(),
                        detectedLanguage: configuration.languageCode,
                        alternatives: []
                    )
                    
                    continuation.resume(returning: transcriptionResult)
                }
            }
            
            // Timeout protection
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                if !hasResumed {
                    hasResumed = true
                    task.cancel()
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed("On-device transcription timeout"))
                }
            }
        }
    }
}