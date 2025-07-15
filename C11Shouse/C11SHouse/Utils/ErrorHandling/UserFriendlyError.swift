//
//  UserFriendlyError.swift
//  c11s-house-ios
//
//  Created by Claude on 2025-07-15.
//

import Foundation

/// Error severity levels for user interface display
enum ErrorSeverity {
    case info      // Informational, doesn't prevent operation
    case warning   // User should be aware, but can continue
    case error     // Operation failed, but app can continue
    case critical  // Major failure requiring immediate attention
    
    var iconSystemName: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }
    
    var tintColor: String {
        switch self {
        case .info:
            return "blue"
        case .warning:
            return "orange"
        case .error:
            return "red"
        case .critical:
            return "red"
        }
    }
}

/// Protocol for errors that can be displayed to users with helpful information
protocol UserFriendlyError: Error {
    /// A user-friendly title for the error
    var userFriendlyTitle: String { get }
    
    /// A user-friendly description of what went wrong
    var userFriendlyMessage: String { get }
    
    /// Suggestions for how the user can resolve the issue
    var recoverySuggestions: [String] { get }
    
    /// The severity level of this error
    var severity: ErrorSeverity { get }
    
    /// Whether this error should be automatically dismissed after a delay
    var shouldAutoDismiss: Bool { get }
    
    /// Optional error code for support/debugging
    var errorCode: String? { get }
}

// Default implementations
extension UserFriendlyError {
    var userFriendlyTitle: String {
        "An Error Occurred"
    }
    
    var shouldAutoDismiss: Bool {
        severity == .info || severity == .warning
    }
    
    var errorCode: String? {
        nil
    }
}

/// Common app errors with user-friendly messages
enum AppError: UserFriendlyError {
    case networkUnavailable
    case locationAccessDenied
    case microphoneAccessDenied
    case weatherServiceUnavailable
    case voiceRecognitionFailed
    case dataCorrupted
    case unknown(Error)
    
    var userFriendlyTitle: String {
        switch self {
        case .networkUnavailable:
            return "No Internet Connection"
        case .locationAccessDenied:
            return "Location Access Required"
        case .microphoneAccessDenied:
            return "Microphone Access Required"
        case .weatherServiceUnavailable:
            return "Weather Service Unavailable"
        case .voiceRecognitionFailed:
            return "Voice Recognition Failed"
        case .dataCorrupted:
            return "Data Error"
        case .unknown:
            return "Unexpected Error"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection and try again."
        case .locationAccessDenied:
            return "This app needs access to your location to provide weather information."
        case .microphoneAccessDenied:
            return "This app needs access to your microphone for voice commands."
        case .weatherServiceUnavailable:
            return "The weather service is temporarily unavailable."
        case .voiceRecognitionFailed:
            return "We couldn't understand your voice command."
        case .dataCorrupted:
            return "There was a problem loading your data."
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestions: [String] {
        switch self {
        case .networkUnavailable:
            return [
                "Check your Wi-Fi or cellular connection",
                "Try moving to an area with better signal",
                "Toggle Airplane Mode on and off"
            ]
        case .locationAccessDenied:
            return [
                "Open Settings > Privacy > Location Services",
                "Find this app and enable location access",
                "Restart the app after granting permission"
            ]
        case .microphoneAccessDenied:
            return [
                "Open Settings > Privacy > Microphone",
                "Find this app and enable microphone access",
                "Restart the app after granting permission"
            ]
        case .weatherServiceUnavailable:
            return [
                "Wait a few moments and try again",
                "Check if you have a stable internet connection",
                "The service may be undergoing maintenance"
            ]
        case .voiceRecognitionFailed:
            return [
                "Speak clearly and try again",
                "Reduce background noise",
                "Make sure your microphone is not obstructed"
            ]
        case .dataCorrupted:
            return [
                "Try refreshing the app",
                "If the problem persists, reinstall the app",
                "Contact support if you continue to have issues"
            ]
        case .unknown:
            return [
                "Try refreshing the app",
                "Restart your device if the problem persists",
                "Contact support with error details"
            ]
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .networkUnavailable, .weatherServiceUnavailable:
            return .warning
        case .locationAccessDenied, .microphoneAccessDenied:
            return .error
        case .voiceRecognitionFailed:
            return .info
        case .dataCorrupted:
            return .critical
        case .unknown:
            return .error
        }
    }
    
    var errorCode: String? {
        switch self {
        case .networkUnavailable:
            return "NET-001"
        case .locationAccessDenied:
            return "LOC-001"
        case .microphoneAccessDenied:
            return "MIC-001"
        case .weatherServiceUnavailable:
            return "WTH-001"
        case .voiceRecognitionFailed:
            return "VOC-001"
        case .dataCorrupted:
            return "DAT-001"
        case .unknown:
            return "UNK-001"
        }
    }
}

/// Extension to convert standard errors to user-friendly errors
extension Error {
    var asUserFriendlyError: UserFriendlyError {
        if let userFriendly = self as? UserFriendlyError {
            return userFriendly
        }
        return AppError.unknown(self)
    }
}