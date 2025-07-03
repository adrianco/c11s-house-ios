//
//  VoiceRecorder.swift
//  C11SHouse
//
//  Created on 2025-07-03
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

/// High-level voice recorder that provides a SwiftUI-friendly interface
@MainActor
final class VoiceRecorder: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current recording state
    @Published private(set) var recordingState: RecordingState = .idle
    
    /// Current audio level (0.0 to 1.0)
    @Published private(set) var audioLevel: Float = 0.0
    
    /// Recording duration in seconds
    @Published private(set) var recordingDuration: TimeInterval = 0.0
    
    /// Error message if any
    @Published var errorMessage: String?
    
    /// Whether microphone permission is granted
    @Published private(set) var hasPermission: Bool = false
    
    // MARK: - Private Properties
    
    /// Audio engine for recording
    private let audioEngine = AudioEngine()
    
    /// Audio session manager
    private let sessionManager = AudioSessionManager.shared
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Current recording URL
    private var currentRecordingURL: URL?
    
    /// Recordings directory URL
    private lazy var recordingsDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        
        return recordingsPath
    }()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        checkPermission()
        audioEngine.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// Starts a new recording
    func startRecording() async {
        guard recordingState == .idle else { return }
        
        do {
            // Clear any previous error
            errorMessage = nil
            
            // Update state
            recordingState = .preparing
            
            // Prepare audio engine
            try await audioEngine.prepareForRecording()
            
            // Generate recording URL
            currentRecordingURL = generateRecordingURL()
            
            // Start recording
            try await audioEngine.startRecording()
            
        } catch {
            handleError(error)
        }
    }
    
    /// Stops the current recording
    func stopRecording() async -> URL? {
        guard recordingState == .recording || recordingState == .paused else { return nil }
        
        recordingState = .stopping
        
        // Stop the audio engine
        audioEngine.stopRecording()
        
        // Export recording if we have a URL
        if let url = currentRecordingURL {
            do {
                try await audioEngine.exportRecording(to: url)
                recordingState = .idle
                return url
            } catch {
                handleError(error)
                return nil
            }
        }
        
        recordingState = .idle
        return nil
    }
    
    /// Pauses the current recording
    func pauseRecording() {
        guard recordingState == .recording else { return }
        
        audioEngine.pauseRecording()
        recordingState = .paused
    }
    
    /// Resumes a paused recording
    func resumeRecording() async {
        guard recordingState == .paused else { return }
        
        do {
            try await audioEngine.resumeRecording()
            recordingState = .recording
        } catch {
            handleError(error)
        }
    }
    
    /// Cancels the current recording without saving
    func cancelRecording() {
        guard recordingState != .idle else { return }
        
        audioEngine.stopRecording()
        recordingState = .idle
        currentRecordingURL = nil
        
        // Reset duration and level
        recordingDuration = 0.0
        audioLevel = 0.0
    }
    
    /// Requests microphone permission
    func requestPermission() async {
        hasPermission = await sessionManager.requestRecordingPermission()
        
        if !hasPermission {
            errorMessage = "Microphone permission is required to record audio"
        }
    }
    
    /// Gets all saved recordings
    func getSavedRecordings() -> [RecordingFile] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
        ) else {
            return []
        }
        
        return contents.compactMap { url in
            guard url.pathExtension == "m4a" else { return nil }
            
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let creationDate = attributes?[.creationDate] as? Date ?? Date()
            let fileSize = attributes?[.size] as? Int64 ?? 0
            
            return RecordingFile(
                url: url,
                name: url.deletingPathExtension().lastPathComponent,
                creationDate: creationDate,
                duration: getAudioDuration(url: url),
                fileSize: fileSize
            )
        }.sorted { $0.creationDate > $1.creationDate }
    }
    
    /// Deletes a recording file
    /// - Parameter recording: The recording to delete
    func deleteRecording(_ recording: RecordingFile) throws {
        try FileManager.default.removeItem(at: recording.url)
    }
    
    // MARK: - Private Methods
    
    /// Sets up Combine bindings
    private func setupBindings() {
        // Bind audio level
        audioEngine.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
        
        // Bind recording duration
        audioEngine.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)
        
        // Bind permission state
        sessionManager.$hasRecordingPermission
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasPermission)
    }
    
    /// Checks current permission status
    private func checkPermission() {
        hasPermission = AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    /// Generates a unique recording URL
    /// - Returns: URL for the new recording
    private func generateRecordingURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = formatter.string(from: Date())
        let fileName = "Recording-\(dateString).m4a"
        
        return recordingsDirectory.appendingPathComponent(fileName)
    }
    
    /// Gets the duration of an audio file
    /// - Parameter url: The audio file URL
    /// - Returns: Duration in seconds
    private func getAudioDuration(url: URL) -> TimeInterval {
        do {
            let audioAsset = AVURLAsset(url: url)
            let duration = try await audioAsset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
        }
    }
    
    /// Handles errors
    /// - Parameter error: The error to handle
    private func handleError(_ error: Error) {
        recordingState = .idle
        
        if let audioError = error as? AudioEngineError {
            errorMessage = audioError.localizedDescription
        } else if let sessionError = error as? AudioSessionError {
            errorMessage = sessionError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        
        print("Voice Recorder Error: \(error)")
    }
}

// MARK: - AudioEngineDelegate

extension VoiceRecorder: AudioEngineDelegate {
    
    func audioEngineDidStartRecording(_ engine: AudioEngine) async {
        recordingState = .recording
    }
    
    func audioEngineDidStopRecording(_ engine: AudioEngine, audioData: Data) async {
        // State will be updated by stopRecording method
    }
    
    func audioEngineDidPauseRecording(_ engine: AudioEngine) async {
        recordingState = .paused
    }
    
    func audioEngineDidResumeRecording(_ engine: AudioEngine) async {
        recordingState = .recording
    }
    
    func audioEngine(_ engine: AudioEngine, didReceiveBuffer buffer: AVAudioPCMBuffer, atTime: AVAudioTime) async {
        // Buffer handling is done internally by AudioEngine
    }
    
    func audioEngine(_ engine: AudioEngine, didFailWithError error: Error) async {
        handleError(error)
    }
    
    func audioEngineWasInterrupted(_ engine: AudioEngine) async {
        if recordingState == .recording {
            recordingState = .paused
            errorMessage = "Recording was interrupted"
        }
    }
    
    func audioEngineDidResetMediaServices(_ engine: AudioEngine) async {
        errorMessage = "Audio services were reset. Please try recording again."
    }
}

// MARK: - Supporting Types

/// Recording state enum
enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case paused
    case stopping
}

/// Represents a saved recording file
struct RecordingFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let creationDate: Date
    let duration: TimeInterval
    let fileSize: Int64
    
    /// Formatted duration string
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0:00"
    }
    
    /// Formatted file size string
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - View Extensions

/// Convenience view modifiers for voice recording
extension View {
    
    /// Adds a voice recording button with customizable appearance
    func voiceRecordingButton(
        recorder: VoiceRecorder,
        size: CGFloat = 60,
        activeColor: Color = .red,
        inactiveColor: Color = .blue
    ) -> some View {
        self.overlay(alignment: .bottom) {
            VoiceRecorderButton(
                recorder: recorder,
                size: size,
                activeColor: activeColor,
                inactiveColor: inactiveColor
            )
            .padding(.bottom, 30)
        }
    }
}

/// Voice recording button view specific to VoiceRecorder
struct VoiceRecorderButton: View {
    @ObservedObject var recorder: VoiceRecorder
    let size: CGFloat
    let activeColor: Color
    let inactiveColor: Color
    
    var body: some View {
        Button(action: handleTap) {
            ZStack {
                Circle()
                    .fill(recorder.recordingState == .recording ? activeColor : inactiveColor)
                    .frame(width: size, height: size)
                
                Image(systemName: iconName)
                    .foregroundColor(.white)
                    .font(.system(size: size * 0.4))
            }
        }
        .disabled(recorder.recordingState == .preparing || recorder.recordingState == .stopping)
        .scaleEffect(recorder.recordingState == .recording ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: recorder.recordingState)
    }
    
    private var iconName: String {
        switch recorder.recordingState {
        case .idle:
            return "mic.fill"
        case .preparing, .stopping:
            return "hourglass"
        case .recording:
            return "stop.fill"
        case .paused:
            return "pause.fill"
        }
    }
    
    private func handleTap() {
        Task {
            switch recorder.recordingState {
            case .idle:
                await recorder.startRecording()
            case .recording:
                _ = await recorder.stopRecording()
            case .paused:
                await recorder.resumeRecording()
            default:
                break
            }
        }
    }
}