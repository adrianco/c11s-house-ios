//
//  VoiceTranscriptionView.swift
//  C11SHouse
//
//  Created on 2025-07-03.
//

import SwiftUI

/// Example view demonstrating voice transcription usage
struct VoiceTranscriptionView: View {
    @StateObject private var transcriptionService = VoiceTranscriptionService()
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Voice Transcription")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Status
            StatusView(state: transcriptionService.transcriptionState)
            
            // Confidence Indicator
            ConfidenceView(level: transcriptionService.confidenceLevel)
            
            // Transcript Display
            TranscriptView(
                currentTranscript: transcriptionService.currentTranscript,
                finalTranscript: transcriptionService.finalTranscript
            )
            
            // Control Buttons
            ControlButtonsView(
                isTranscribing: transcriptionService.isTranscribing,
                onStart: startTranscription,
                onStop: { transcriptionService.stopTranscription() },
                onReset: { transcriptionService.resetTranscription() }
            )
            
            // Processing Mode
            ProcessingModeView(mode: transcriptionService.processingMode)
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            if case .error(let message) = transcriptionService.transcriptionState {
                Text(message)
            }
        }
        .onChange(of: transcriptionService.transcriptionState) { state in
            if case .error = state {
                showError = true
            }
        }
    }
    
    private func startTranscription() {
        Task {
            do {
                try await transcriptionService.startTranscription()
            } catch {
                // Error will be handled by the service
            }
        }
    }
}

// MARK: - Sub Views
struct StatusView: View {
    let state: VoiceTranscriptionService.TranscriptionState
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            Text(state.description)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusIcon: String {
        switch state {
        case .idle: return "mic.slash"
        case .preparing: return "gear"
        case .listening: return "mic.fill"
        case .processing: return "waveform"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .idle: return .gray
        case .preparing: return .orange
        case .listening: return .red
        case .processing: return .blue
        case .completed: return .green
        case .error: return .red
        }
    }
}

struct ConfidenceView: View {
    let level: VoiceTranscriptionService.ConfidenceLevel
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Confidence")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { index in
                    Rectangle()
                        .fill(barColor(for: index))
                        .frame(width: 40, height: 8)
                        .cornerRadius(4)
                }
            }
            
            Text(level.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let activeIndices: Int
        switch level {
        case .unknown: activeIndices = 0
        case .low: activeIndices = 1
        case .medium: activeIndices = 2
        case .high: activeIndices = 4
        case .veryHigh: activeIndices = 5
        }
        
        return index <= activeIndices ? Color(level.color) : Color.gray.opacity(0.3)
    }
}

struct TranscriptView: View {
    let currentTranscript: String
    let finalTranscript: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !currentTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentTranscript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if !finalTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Final")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(finalTranscript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if currentTranscript.isEmpty && finalTranscript.isEmpty {
                Text("Tap the microphone to start speaking")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct ControlButtonsView: View {
    let isTranscribing: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Start/Stop Button
            Button(action: {
                if isTranscribing {
                    onStop()
                } else {
                    onStart()
                }
            }) {
                Image(systemName: isTranscribing ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(isTranscribing ? .red : .blue)
            }
            
            // Reset Button
            Button(action: onReset) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            .disabled(isTranscribing)
        }
    }
}

struct ProcessingModeView: View {
    let mode: VoiceTranscriptionService.ProcessingMode
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: modeIcon)
                    .font(.caption)
                Text(mode.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Text(mode.description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var modeIcon: String {
        switch mode {
        case .onDevice: return "iphone"
        case .cloud: return "icloud"
        case .hybrid: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Preview
struct VoiceTranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceTranscriptionView()
    }
}