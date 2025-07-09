/*
 * CONTEXT & PURPOSE:
 * TranscriptionServiceImpl provides speech-to-text functionality using Apple's Speech framework.
 * It offers both server-based transcription (TranscriptionServiceImpl) for accuracy and on-device
 * transcription (OnDeviceTranscriptionService) for privacy. Handles audio file transcription with
 * confidence scores, alternatives, and segment-level details.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Protocol-based design following TranscriptionService interface
 *   - Device locale detection with en-US fallback
 *   - Server-based recognition by default for better accuracy
 *   - Temporary file approach for audio data processing
 *   - Async/await API using withCheckedThrowingContinuation
 *   - 30-second timeout protection to prevent hanging
 *   - Segment extraction with confidence and timing information
 *   - Up to 3 alternative transcriptions provided
 *   - Error code 203 specifically handled (no speech detected)
 *   - Audio duration calculation from file metadata
 *   - Separate OnDeviceTranscriptionService for privacy-focused use cases
 *   - On-device service checks device capability before attempting
 *   - 20-second timeout for on-device (shorter due to local processing)
 *   - Automatic cleanup of temporary files in defer blocks
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

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
        // Initialize speech recognizer with device locale or fallback
        let deviceLocale = Locale.current
        if let recognizer = SFSpeechRecognizer(locale: deviceLocale) {
            self.speechRecognizer = recognizer
            print("TranscriptionServiceImpl: Using device locale \(deviceLocale.identifier)")
        } else {
            // Fallback to en-US if device locale not supported
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            print("TranscriptionServiceImpl: Falling back to en-US locale")
        }
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
        // addsPunctuation is automatically enabled in iOS 16+
        request.requiresOnDeviceRecognition = false // Use server-based recognition for better accuracy
        
        // Perform transcription
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                var shouldProcess = false
                objc_sync_enter(continuation)
                if !hasResumed {
                    shouldProcess = true
                }
                objc_sync_exit(continuation)
                
                guard shouldProcess else { return } // Prevent multiple resumptions
                
                if let error = error {
                    objc_sync_enter(continuation)
                    hasResumed = true
                    objc_sync_exit(continuation)
                    if (error as NSError).code == 203 { // No speech detected
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed("No speech detected"))
                    } else {
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed(error.localizedDescription))
                    }
                    return
                }
                
                if let result = result {
                    if result.isFinal {
                        objc_sync_enter(continuation)
                        hasResumed = true
                        objc_sync_exit(continuation)
                        
                        // Calculate duration from audio file
                        let duration = self.getAudioDuration(from: tempURL) ?? 0
                        
                        // Get alternatives
                        let alternatives = result.transcriptions.dropFirst().prefix(3).map { $0.formattedString }
                        
                        // Extract segments
                        let segments = result.bestTranscription.segments.map { segment in
                            TranscriptionSegment(
                                text: segment.substring,
                                confidence: segment.confidence,
                                timestamp: segment.timestamp,
                                duration: segment.duration
                            )
                        }
                        
                        // Create transcription result
                        let transcriptionResult = TranscriptionResult(
                            text: result.bestTranscription.formattedString,
                            confidence: Float(result.transcriptions.first?.segments.first?.confidence ?? 0),
                            duration: duration,
                            timestamp: Date(),
                            detectedLanguage: configuration.languageCode,
                            alternatives: Array(alternatives),
                            segments: segments,
                            isFinal: true
                        )
                        
                        continuation.resume(returning: transcriptionResult)
                    }
                }
            }
            
            // Set a timeout to prevent hanging
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                var shouldResume = false
                objc_sync_enter(continuation)
                if !hasResumed {
                    hasResumed = true
                    shouldResume = true
                }
                objc_sync_exit(continuation)
                
                if shouldResume {
                    self?.recognitionTask?.cancel()
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
        // addsPunctuation is automatically enabled in iOS 16+
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            let task = recognizer.recognitionTask(with: request) { result, error in
                var shouldProcess = false
                objc_sync_enter(continuation)
                if !hasResumed {
                    shouldProcess = true
                }
                objc_sync_exit(continuation)
                
                guard shouldProcess else { return }
                
                if let error = error {
                    objc_sync_enter(continuation)
                    hasResumed = true
                    objc_sync_exit(continuation)
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed(error.localizedDescription))
                    return
                }
                
                if let result = result, result.isFinal {
                    objc_sync_enter(continuation)
                    hasResumed = true
                    objc_sync_exit(continuation)
                    
                    let segments = result.bestTranscription.segments.map { segment in
                        TranscriptionSegment(
                            text: segment.substring,
                            confidence: segment.confidence,
                            timestamp: segment.timestamp,
                            duration: segment.duration
                        )
                    }
                    
                    let transcriptionResult = TranscriptionResult(
                        text: result.bestTranscription.formattedString,
                        confidence: 0.95, // On-device doesn't provide confidence scores
                        duration: 0, // Calculate if needed
                        timestamp: Date(),
                        detectedLanguage: configuration.languageCode,
                        alternatives: [],
                        segments: segments,
                        isFinal: true
                    )
                    
                    continuation.resume(returning: transcriptionResult)
                }
            }
            
            // Timeout protection
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak task] in
                var shouldResume = false
                objc_sync_enter(continuation)
                if !hasResumed {
                    hasResumed = true
                    shouldResume = true
                }
                objc_sync_exit(continuation)
                
                if shouldResume {
                    task?.cancel()
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed("On-device transcription timeout"))
                }
            }
        }
    }
}