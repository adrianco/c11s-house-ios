//
//  VoiceTranscriptionView.swift
//  C11SHouse
//
//  Main view for voice transcription feature
//

import SwiftUI

struct VoiceTranscriptionView: View {
    @StateObject private var viewModel: VoiceTranscriptionViewModel
    @Environment(\.serviceContainer) private var serviceContainer
    
    // Animation states
    @State private var isAnimatingRecord = false
    @State private var showingHistory = false
    
    init() {
        _viewModel = StateObject(wrappedValue: ServiceContainer.shared.makeVoiceTranscriptionViewModel())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Status indicator
                    statusView
                    
                    // Audio waveform visualization
                    AudioWaveformView(
                        audioLevel: viewModel.audioLevel,
                        isRecording: viewModel.isRecording
                    )
                    .frame(height: 100)
                    .padding(.horizontal)
                    
                    // Transcribed text display
                    transcriptionDisplay
                    
                    Spacer()
                    
                    // Control buttons
                    controlButtons
                }
                .padding()
            }
            .navigationTitle("Voice Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingHistory.toggle() }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .disabled(viewModel.transcriptionHistory.isEmpty)
                }
            }
            .sheet(isPresented: $showingHistory) {
                TranscriptionHistoryView(history: viewModel.transcriptionHistory)
            }
            .alert(isPresented: .constant(showError), content: {
                errorAlert
            })
        }
    }
    
    // MARK: - View Components
    
    private var statusView: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title2)
            
            Text(statusText)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(statusColor.opacity(0.1))
        )
    }
    
    private var transcriptionDisplay: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !viewModel.transcribedText.isEmpty {
                    Text(viewModel.transcribedText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 2)
                        )
                } else {
                    Text("Tap the microphone to start recording")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
        .frame(maxHeight: 200)
        .padding(.horizontal)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 40) {
            // Cancel button
            if viewModel.state.isRecording || viewModel.state.isProcessing {
                Button(action: { viewModel.cancelRecording() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                }
                .transition(.scale)
            }
            
            // Main action button
            Button(action: handleMainAction) {
                ZStack {
                    Circle()
                        .fill(mainButtonColor)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isAnimatingRecord ? 1.2 : 1.0)
                        .animation(
                            viewModel.isRecording ?
                                Animation.easeInOut(duration: 1.5).repeatForever() :
                                Animation.default,
                            value: isAnimatingRecord
                        )
                    
                    Image(systemName: mainButtonIcon)
                        .font(.system(size: 35))
                        .foregroundColor(.white)
                }
            }
            .disabled(!canPerformMainAction)
            
            // Clear/Retry button
            if case .error(let error) = viewModel.state, error.isRecoverable {
                Button(action: { viewModel.retry() }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }
                .transition(.scale)
            } else if !viewModel.transcribedText.isEmpty && !viewModel.isRecording {
                Button(action: { viewModel.clearHistory() }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
                .transition(.scale)
            }
        }
        .padding(.bottom, 30)
        .onChange(of: viewModel.isRecording) { newValue in
            isAnimatingRecord = newValue
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch viewModel.state {
        case .idle: return "mic.slash"
        case .preparing: return "hourglass"
        case .ready: return "checkmark.circle"
        case .recording: return "mic.fill"
        case .processing: return "waveform"
        case .transcribed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch viewModel.state {
        case .idle, .preparing: return .gray
        case .ready: return .green
        case .recording: return .red
        case .processing: return .blue
        case .transcribed: return .green
        case .error: return .red
        case .cancelled: return .orange
        }
    }
    
    private var statusText: String {
        switch viewModel.state {
        case .idle: return "Ready to record"
        case .preparing: return "Preparing..."
        case .ready: return "Tap to start"
        case .recording(let duration):
            return String(format: "Recording... %.1fs", duration)
        case .processing: return "Processing..."
        case .transcribed: return "Transcription complete"
        case .error(let error): return error.localizedDescription
        case .cancelled: return "Recording cancelled"
        }
    }
    
    private var mainButtonIcon: String {
        switch viewModel.state {
        case .recording: return "stop.fill"
        case .processing: return "ellipsis"
        default: return "mic.fill"
        }
    }
    
    private var mainButtonColor: Color {
        switch viewModel.state {
        case .recording: return .red
        case .processing: return .blue
        case .error: return .gray
        default: return viewModel.isMicrophoneAuthorized ? .blue : .gray
        }
    }
    
    private var canPerformMainAction: Bool {
        switch viewModel.state {
        case .processing, .preparing:
            return false
        case .error(let error):
            return error.isRecoverable
        default:
            return viewModel.isMicrophoneAuthorized
        }
    }
    
    private var showError: Bool {
        if case .error = viewModel.state {
            return true
        }
        return false
    }
    
    private var errorAlert: Alert {
        guard case .error(let error) = viewModel.state else {
            return Alert(title: Text("Error"))
        }
        
        return Alert(
            title: Text("Transcription Error"),
            message: Text(error.localizedDescription),
            primaryButton: .default(Text(error.isRecoverable ? "Retry" : "OK")) {
                if error.isRecoverable {
                    viewModel.retry()
                }
            },
            secondaryButton: .cancel()
        )
    }
    
    // MARK: - Actions
    
    private func handleMainAction() {
        if viewModel.isRecording {
            viewModel.stopRecording()
        } else {
            viewModel.startRecording()
        }
    }
}

// MARK: - Supporting Views

struct AudioWaveformView: View {
    let audioLevel: AudioLevel
    let isRecording: Bool
    
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                
                // Waveform bars
                HStack(spacing: 4) {
                    ForEach(0..<20) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(for: index))
                            .frame(width: (geometry.size.width - 80) / 20)
                            .scaleEffect(y: barHeight(for: index), anchor: .bottom)
                            .animation(
                                .easeInOut(duration: 0.1)
                                    .delay(Double(index) * 0.01),
                                value: CGFloat(audioLevel.normalizedLevel)
                            )
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationPhase = 1
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard isRecording else { return 0.1 }
        
        let phase = animationPhase * .pi * 2
        let offset = Double(index) / 20.0 * .pi
        let waveHeight = sin(phase + offset) * 0.3 + 0.5
        
        return CGFloat(audioLevel.normalizedLevel) * CGFloat(waveHeight) + 0.1
    }
    
    private func barColor(for index: Int) -> Color {
        let intensity = Double(index) / 20.0
        return isRecording ? 
            Color.red.opacity(0.5 + intensity * 0.5) : 
            Color.blue.opacity(0.3)
    }
}

struct TranscriptionHistoryView: View {
    let history: [TranscriptionResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(history.reversed()) { result in
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.text)
                        .font(.body)
                    
                    HStack {
                        Label(
                            String(format: "%.1fs", result.duration),
                            systemImage: "timer"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(result.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Transcription History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// Make TranscriptionResult identifiable for List
extension TranscriptionResult: Identifiable {
    var id: Date { timestamp }
}