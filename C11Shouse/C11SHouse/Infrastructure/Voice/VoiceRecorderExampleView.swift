/*
 * CONTEXT & PURPOSE:
 * VoiceRecorderExampleView demonstrates the usage of VoiceRecorder with a complete UI implementation.
 * It serves as both an example for developers and a functional voice recording interface with
 * recording controls, audio level visualization, recordings management, and permission handling.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Full-featured demo view showcasing VoiceRecorder capabilities
 *   - Visual recording state indicators with SF Symbols
 *   - Real-time audio level meter with color coding
 *   - Recording duration display with monospaced font
 *   - Dual control interface: standard buttons and floating action button
 *   - Recording list with playback UI (playback TODO)
 *   - SwiftUI alerts for permission requests and errors
 *   - Automatic recordings refresh on save
 *   - Delete functionality for saved recordings
 *   - Responsive button states based on recording state
 *   - Animated visual feedback for recording state changes
 *   - RecordingRow component for list items
 *   - Formatted display of duration, file size, and creation date
 *   - Color-coded audio levels (green/yellow/red)
 *   - Spring animations for floating button
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  VoiceRecorderExampleView.swift
//  C11SHouse
//
//  Created on 2025-07-03
//

import SwiftUI
import AVFoundation

/// Example view demonstrating voice recording functionality
struct VoiceRecorderExampleView: View {
    @StateObject private var recorder = VoiceRecorder()
    @State private var recordings: [RecordingFile] = []
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    // Recording status
                    recordingStatusView
                    
                    // Audio level indicator
                    if recorder.recordingState == .recording {
                        audioLevelView
                    }
                    
                    // Recording controls
                    recordingControlsView
                    
                    Divider()
                        .padding(.vertical)
                    
                    // Recordings list
                    recordingsListView
                }
                .padding()
                
                // Floating record button
                VStack {
                    Spacer()
                    floatingRecordButton
                }
            }
            .navigationTitle("Voice Recorder")
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Microphone permission is required to record audio. Please enable it in Settings.")
            }
            .alert("Recording Error", isPresented: .constant(recorder.errorMessage != nil)) {
                Button("OK") {
                    recorder.errorMessage = nil
                }
            } message: {
                Text(recorder.errorMessage ?? "")
            }
            .onAppear {
                checkPermissionAndLoadRecordings()
            }
        }
    }
    
    // MARK: - View Components
    
    private var recordingStatusView: some View {
        VStack(spacing: 8) {
            // Status icon
            Image(systemName: statusIconName)
                .font(.system(size: 50))
                .foregroundColor(statusColor)
                .symbolEffect(.pulse, value: recorder.recordingState == .recording)
            
            // Status text
            Text(statusText)
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Duration
            if recorder.recordingState != .idle {
                Text(formatDuration(recorder.recordingDuration))
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var audioLevelView: some View {
        VStack(spacing: 8) {
            Text("Audio Level")
                .font(.caption)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Level indicator
                    RoundedRectangle(cornerRadius: 4)
                        .fill(levelColor)
                        .frame(width: geometry.size.width * CGFloat(recorder.audioLevel), height: 8)
                        .animation(.linear(duration: 0.1), value: recorder.audioLevel)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal)
    }
    
    private var recordingControlsView: some View {
        HStack(spacing: 30) {
            // Start/Stop button
            Button(action: handleMainAction) {
                Label(
                    recorder.recordingState == .idle ? "Start" : "Stop",
                    systemImage: recorder.recordingState == .idle ? "mic.fill" : "stop.fill"
                )
                .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!recorder.hasPermission || 
                     recorder.recordingState == .preparing || 
                     recorder.recordingState == .stopping)
            
            // Pause/Resume button
            if recorder.recordingState == .recording || recorder.recordingState == .paused {
                Button(action: handlePauseResume) {
                    Label(
                        recorder.recordingState == .paused ? "Resume" : "Pause",
                        systemImage: recorder.recordingState == .paused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            // Cancel button
            if recorder.recordingState != .idle {
                Button(action: {
                    recorder.cancelRecording()
                }) {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)
            }
        }
    }
    
    private var recordingsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recordings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    loadRecordings()
                }
                .font(.caption)
            }
            
            if recordings.isEmpty {
                Text("No recordings yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recordings) { recording in
                            RecordingRow(recording: recording) {
                                deleteRecording(recording)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var floatingRecordButton: some View {
        HStack {
            Spacer()
            
            Button(action: handleFloatingButtonTap) {
                ZStack {
                    Circle()
                        .fill(floatingButtonColor)
                        .frame(width: 70, height: 70)
                        .shadow(radius: 4)
                    
                    Image(systemName: floatingButtonIcon)
                        .foregroundColor(.white)
                        .font(.system(size: 30))
                }
            }
            .disabled(!recorder.hasPermission)
            .scaleEffect(recorder.recordingState == .recording ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: recorder.recordingState)
            
            Spacer()
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Helper Properties
    
    private var statusIconName: String {
        switch recorder.recordingState {
        case .idle:
            return "mic.slash.fill"
        case .preparing:
            return "hourglass"
        case .recording:
            return "mic.fill"
        case .paused:
            return "pause.circle.fill"
        case .stopping:
            return "hourglass"
        }
    }
    
    private var statusColor: Color {
        switch recorder.recordingState {
        case .idle:
            return .gray
        case .preparing, .stopping:
            return .orange
        case .recording:
            return .red
        case .paused:
            return .yellow
        }
    }
    
    private var statusText: String {
        switch recorder.recordingState {
        case .idle:
            return "Ready to Record"
        case .preparing:
            return "Preparing..."
        case .recording:
            return "Recording"
        case .paused:
            return "Paused"
        case .stopping:
            return "Saving..."
        }
    }
    
    private var levelColor: Color {
        if recorder.audioLevel < 0.3 {
            return .green
        } else if recorder.audioLevel < 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var floatingButtonColor: Color {
        recorder.recordingState == .recording ? .red : .blue
    }
    
    private var floatingButtonIcon: String {
        switch recorder.recordingState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .paused:
            return "play.fill"
        default:
            return "mic.fill"
        }
    }
    
    // MARK: - Actions
    
    private func handleMainAction() {
        Task {
            if recorder.recordingState == .idle {
                await recorder.startRecording()
            } else {
                if let url = await recorder.stopRecording() {
                    print("Recording saved to: \(url)")
                    loadRecordings()
                }
            }
        }
    }
    
    private func handlePauseResume() {
        Task {
            if recorder.recordingState == .paused {
                await recorder.resumeRecording()
            } else {
                recorder.pauseRecording()
            }
        }
    }
    
    private func handleFloatingButtonTap() {
        Task {
            switch recorder.recordingState {
            case .idle:
                await recorder.startRecording()
            case .recording:
                if let url = await recorder.stopRecording() {
                    print("Recording saved to: \(url)")
                    loadRecordings()
                }
            case .paused:
                await recorder.resumeRecording()
            default:
                break
            }
        }
    }
    
    private func checkPermissionAndLoadRecordings() {
        Task {
            if !recorder.hasPermission {
                await recorder.requestPermission()
                if !recorder.hasPermission {
                    showingPermissionAlert = true
                }
            }
            loadRecordings()
        }
    }
    
    private func loadRecordings() {
        recordings = recorder.getSavedRecordings()
    }
    
    private func deleteRecording(_ recording: RecordingFile) {
        do {
            try recorder.deleteRecording(recording)
            loadRecordings()
        } catch {
            recorder.errorMessage = "Failed to delete recording: \(error.localizedDescription)"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Recording Row View

struct RecordingRow: View {
    let recording: RecordingFile
    let onDelete: () -> Void
    
    @State private var isPlaying = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(recording.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(recording.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(recording.creationDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func togglePlayback() {
        // TODO: Implement audio playback
        isPlaying.toggle()
    }
}

// MARK: - Preview

struct VoiceRecorderExampleView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceRecorderExampleView()
    }
}