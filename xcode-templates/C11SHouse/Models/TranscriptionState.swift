//
//  TranscriptionState.swift
//  C11SHouse
//
//  State management for voice transcription feature
//

import Foundation

/// Represents the current state of the voice transcription system
enum TranscriptionState: Equatable {
    /// Initial state - no recording or transcription active
    case idle
    
    /// Preparing to record (requesting permissions, setting up audio session)
    case preparing
    
    /// Ready to start recording
    case ready
    
    /// Currently recording audio
    case recording(duration: TimeInterval)
    
    /// Processing recorded audio for transcription
    case processing
    
    /// Transcription completed successfully
    case transcribed(text: String)
    
    /// Error occurred during the process
    case error(TranscriptionError)
    
    /// Recording was cancelled by user
    case cancelled
    
    var isRecording: Bool {
        if case .recording = self {
            return true
        }
        return false
    }
    
    var isProcessing: Bool {
        switch self {
        case .preparing, .processing:
            return true
        default:
            return false
        }
    }
    
    var canStartRecording: Bool {
        switch self {
        case .ready, .transcribed, .error, .cancelled:
            return true
        default:
            return false
        }
    }
}

/// Errors that can occur during transcription
enum TranscriptionError: LocalizedError, Equatable {
    case microphonePermissionDenied
    case audioSessionSetupFailed
    case recordingFailed(String)
    case transcriptionFailed(String)
    case networkError(String)
    case invalidAudioFormat
    case exceedsMaximumDuration
    case insufficientStorage
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required for voice transcription. Please enable it in Settings."
        case .audioSessionSetupFailed:
            return "Failed to set up audio recording. Please try again."
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .invalidAudioFormat:
            return "Invalid audio format detected."
        case .exceedsMaximumDuration:
            return "Recording exceeds maximum duration of 60 seconds."
        case .insufficientStorage:
            return "Not enough storage space available for recording."
        case .unknown(let reason):
            return "An unexpected error occurred: \(reason)"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .microphonePermissionDenied, .insufficientStorage:
            return false
        default:
            return true
        }
    }
}

/// Configuration for transcription behavior
struct TranscriptionConfiguration {
    /// Maximum recording duration in seconds
    let maxRecordingDuration: TimeInterval
    
    /// Audio sample rate in Hz
    let sampleRate: Double
    
    /// Number of audio channels (1 for mono, 2 for stereo)
    let channels: Int
    
    /// Whether to show interim results during transcription
    let showInterimResults: Bool
    
    /// Language code for transcription (e.g., "en-US")
    let languageCode: String
    
    /// Whether to enable automatic punctuation
    let enablePunctuation: Bool
    
    /// Silence detection threshold in seconds
    let silenceThreshold: TimeInterval
    
    static let `default` = TranscriptionConfiguration(
        maxRecordingDuration: 60,
        sampleRate: 16000,
        channels: 1,
        showInterimResults: true,
        languageCode: "en-US",
        enablePunctuation: true,
        silenceThreshold: 2.0
    )
}

/// Audio level information for visualization
struct AudioLevel {
    /// Current audio power level in decibels
    let powerLevel: Float
    
    /// Peak audio level in the current buffer
    let peakLevel: Float
    
    /// Average audio level over a time window
    let averageLevel: Float
    
    /// Normalized level (0.0 to 1.0) for UI display
    var normalizedLevel: Float {
        // Convert dB to linear scale for visualization
        let minDb: Float = -60
        let maxDb: Float = 0
        let clampedPower = max(minDb, min(maxDb, powerLevel))
        return (clampedPower - minDb) / (maxDb - minDb)
    }
    
    static let silent = AudioLevel(powerLevel: -60, peakLevel: -60, averageLevel: -60)
}

/// Result of a transcription operation
struct TranscriptionResult {
    /// The transcribed text
    let text: String
    
    /// Confidence score (0.0 to 1.0)
    let confidence: Float
    
    /// Duration of the audio in seconds
    let duration: TimeInterval
    
    /// Timestamp when transcription completed
    let timestamp: Date
    
    /// Language detected (if applicable)
    let detectedLanguage: String?
    
    /// Alternative transcriptions with lower confidence
    let alternatives: [String]
}