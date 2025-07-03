//
//  PermissionManagerImpl.swift
//  C11SHouse
//
//  Concrete implementation of permission management
//

import Foundation
import AVFoundation
import Speech

/// Concrete implementation of PermissionManager for handling system permissions
class PermissionManagerImpl: PermissionManager {
    
    // MARK: - PermissionManager Implementation
    
    func checkMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                continuation.resume(returning: true)
            case .denied, .undetermined:
                continuation.resume(returning: false)
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Additional Permission Methods
    
    /// Check if speech recognition is authorized
    func checkSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized:
                continuation.resume(returning: true)
            case .denied, .notDetermined, .restricted:
                continuation.resume(returning: false)
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Request speech recognition permission
    func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// Check all required permissions for voice transcription
    func checkAllPermissions() async -> (microphone: Bool, speechRecognition: Bool) {
        async let microphonePermission = checkMicrophonePermission()
        async let speechPermission = checkSpeechRecognitionPermission()
        
        return await (microphonePermission, speechPermission)
    }
    
    /// Request all required permissions
    func requestAllPermissions() async -> (microphone: Bool, speechRecognition: Bool) {
        // Request microphone first
        let microphoneGranted = await requestMicrophonePermission()
        
        // Only request speech recognition if microphone was granted
        let speechGranted: Bool
        if microphoneGranted {
            speechGranted = await requestSpeechRecognitionPermission()
        } else {
            speechGranted = false
        }
        
        return (microphoneGranted, speechGranted)
    }
    
    /// Get human-readable permission status
    func getPermissionStatus() async -> PermissionStatus {
        let (microphone, speech) = await checkAllPermissions()
        
        if microphone && speech {
            return .allGranted
        } else if !microphone && !speech {
            return .noneGranted
        } else if !microphone {
            return .microphoneDenied
        } else {
            return .speechRecognitionDenied
        }
    }
}

/// Permission status enum for UI display
enum PermissionStatus {
    case allGranted
    case noneGranted
    case microphoneDenied
    case speechRecognitionDenied
    
    var description: String {
        switch self {
        case .allGranted:
            return "All permissions granted"
        case .noneGranted:
            return "Microphone and speech recognition permissions required"
        case .microphoneDenied:
            return "Microphone permission required"
        case .speechRecognitionDenied:
            return "Speech recognition permission required"
        }
    }
    
    var isFullyAuthorized: Bool {
        return self == .allGranted
    }
}