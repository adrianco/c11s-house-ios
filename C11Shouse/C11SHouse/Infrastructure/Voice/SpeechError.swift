/*
 * CONTEXT & PURPOSE:
 * SpeechError provides type-safe error handling for speech recognition operations.
 * Replaces magic NSError codes with meaningful enum cases, making error handling
 * more maintainable and debuggable.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation
 *   - Created as part of Phase 4 refactoring
 *   - Replaces hardcoded error codes in ConversationRecognizer
 *   - Adds isIgnorable property for better error filtering
 *   - Maps common NSError codes to semantic meanings
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation
import Speech

enum SpeechError: Error, LocalizedError {
    case noSpeechDetected
    case recordingError(NSError)
    case cancelled
    case deviceNotAvailable
    case recognitionError(String)
    case permissionDenied
    case audioEngineError
    
    init(nsError: NSError) {
        switch nsError.code {
        case 1110:
            self = .noSpeechDetected
        case 1101:
            self = .recordingError(nsError)
        case 203, 216, 301:
            self = .cancelled
        case 1700:
            self = .deviceNotAvailable
        default:
            self = .recognitionError(nsError.localizedDescription)
        }
    }
    
    /// Determines if this error should be ignored (not shown to user)
    var isIgnorable: Bool {
        switch self {
        case .noSpeechDetected, .cancelled:
            return true
        case .recordingError(let error) where error.code == 1101:
            return true // Known benign error during normal operation
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .noSpeechDetected:
            return "No speech was detected. Please try speaking again."
        case .recordingError(let error):
            return "Recording error: \(error.localizedDescription)"
        case .cancelled:
            return "Speech recognition was cancelled."
        case .deviceNotAvailable:
            return "The audio device is not available."
        case .recognitionError(let message):
            return "Recognition error: \(message)"
        case .permissionDenied:
            return "Microphone or speech recognition permission denied."
        case .audioEngineError:
            return "Audio engine error. Please try again."
        }
    }
    
    /// Returns true if this error indicates a permission issue
    var isPermissionError: Bool {
        switch self {
        case .permissionDenied:
            return true
        case .recognitionError(let message):
            return message.lowercased().contains("permission") || 
                   message.lowercased().contains("authorization")
        default:
            return false
        }
    }
}