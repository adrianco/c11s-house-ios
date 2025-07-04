/*
 * CONTEXT & PURPOSE:
 * FixedSpeechTestView is a debugging and testing interface for the FixedSpeechRecognizer.
 * It provides comprehensive status monitoring, real-time transcription display, and error
 * feedback to help diagnose and test speech recognition functionality during development.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation for testing fixed speech recognition
 *   - StateObject for FixedSpeechRecognizer lifecycle management
 *   - Status display for recording state, availability, and authorization
 *   - Real-time transcript display with confidence percentage
 *   - Error display with red background for visibility
 *   - Toggle button changes between start/stop with color feedback
 *   - Reset button to clear transcript and state
 *   - Authorization status helper for readable text
 *   - Automatic cleanup on view dismissal to prevent orphaned recordings
 *   - Disabled state for button when not authorized
 *   - Gray backgrounds for content sections
 *   - Minimum height for transcript area to prevent layout shifts
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  FixedSpeechTestView.swift
//  C11SHouse
//
//  Test view for debugging the fixed real-time speech recognition
//

import SwiftUI
import Speech

struct FixedSpeechTestView: View {
    @StateObject private var recognizer = FixedSpeechRecognizer()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Fixed Real-Time Speech Test")
                .font(.largeTitle)
                .padding()
            
            VStack(spacing: 10) {
                HStack {
                    Text("Status:")
                        .font(.headline)
                    Text(recognizer.isRecording ? "Recording" : "Ready")
                        .foregroundColor(recognizer.isRecording ? .red : .green)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Available:")
                        .font(.headline)
                    Text(recognizer.isAvailable ? "Yes" : "No")
                        .foregroundColor(recognizer.isAvailable ? .green : .red)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Authorization:")
                        .font(.headline)
                    Text(authStatusText(recognizer.authorizationStatus))
                        .foregroundColor(recognizer.authorizationStatus == .authorized ? .green : .red)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            if let error = recognizer.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Real-time Transcript:")
                        .font(.headline)
                    
                    if recognizer.confidence > 0 {
                        Spacer()
                        Text("Confidence: \(Int(recognizer.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(recognizer.transcript.isEmpty ? "Say something..." : recognizer.transcript)
                    .padding()
                    .frame(minHeight: 100)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    recognizer.toggleRecording()
                }) {
                    HStack {
                        Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                        Text(recognizer.isRecording ? "Stop Recording" : "Start Recording")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(recognizer.isRecording ? Color.red : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(recognizer.authorizationStatus != .authorized)
                
                Button("Reset") {
                    recognizer.reset()
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.gray)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Fixed Speech Test")
        .onDisappear {
            // Ensure recording stops when view is dismissed
            if recognizer.isRecording {
                recognizer.stopRecording()
            }
        }
    }
    
    private func authStatusText(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
}