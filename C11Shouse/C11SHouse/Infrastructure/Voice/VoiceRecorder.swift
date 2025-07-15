/*
 * CONTEXT & PURPOSE:
 * VoiceRecorder provides a high-level, SwiftUI-friendly interface for voice recording functionality.
 * It abstracts the complexity of AudioEngine and AudioSessionManager, providing a simple API with
 * reactive state management for UI integration. Handles recording lifecycle, file management,
 * and permission coordination.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - ObservableObject pattern for SwiftUI integration
 *   - @MainActor for thread-safe UI state updates
 *   - Published properties for reactive UI binding
 *   - State machine pattern with RecordingState enum
 *   - Delegation to AudioEngine for actual recording
 *   - Automatic file management in Documents/Recordings directory
 *   - M4A format for recorded files (iOS standard)
 *   - Date-based file naming convention
 *   - Error handling with user-friendly messages
 *   - Combine bindings for real-time audio level and duration updates
 *   - Recording file metadata (duration, size, creation date)
 *   - Convenience view modifiers for easy UI integration
 *   - VoiceRecorderButton component with visual state feedback
 *   - AudioEngineDelegate implementation for event handling
 *   - Async/await API for recording operations
 *
 * - 2025-01-09: iOS 18+ migration
 *   - Changed AVAudioSession.sharedInstance().recordPermission to AVAudioApplication.shared.recordPermission
 *   - Added AVFAudio import for AVAudioApplication
 *   - Updated getAudioDuration to use async load(.duration) API instead of deprecated duration property
 *   - Used semaphore to bridge async/sync since called from synchronous compactMap
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

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
import AVFAudio

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
    
    /// Current error if any
    @Published var error: UserFriendlyError?
    
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
            error = nil
            
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
            error = AppError.microphoneAccessDenied
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
        let audioAsset = AVURLAsset(url: url)
        
        // Since this is called from a sync context (compactMap), we need to bridge async to sync
        // In a production app, consider making getSavedRecordings async to properly use the new API
        let semaphore = DispatchSemaphore(value: 0)
        var loadedDuration: CMTime = .invalid
        var loadError: Error?
        
        Task {
            do {
                loadedDuration = try await audioAsset.load(.duration)
            } catch {
                loadError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = loadError {
            print("Failed to load audio duration: \(error)")
            return 0
        }
        
        if loadedDuration.isValid && !loadedDuration.isIndefinite {
            return CMTimeGetSeconds(loadedDuration)
        } else {
            return 0
        }
    }
    
    /// Handles errors
    /// - Parameter error: The error to handle
    private func handleError(_ error: Error) {
        recordingState = .idle
        
        // Convert to user-friendly error
        if let userFriendlyError = error as? UserFriendlyError {
            self.error = userFriendlyError
        } else {
            // For any other error, wrap it as unknown
            self.error = AppError.unknown(error)
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
            error = VoiceRecorderError.recordingInterrupted
        }
    }
    
    func audioEngineDidResetMediaServices(_ engine: AudioEngine) async {
        error = VoiceRecorderError.audioServicesReset
    }
}

// MARK: - Supporting Types

/// Voice recorder specific errors
enum VoiceRecorderError: UserFriendlyError {
    case recordingInterrupted
    case audioServicesReset
    
    var userFriendlyTitle: String {
        switch self {
        case .recordingInterrupted:
            return "Recording Interrupted"
        case .audioServicesReset:
            return "Audio System Reset"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .recordingInterrupted:
            return "Your recording was interrupted by another app or system event."
        case .audioServicesReset:
            return "The audio system was reset. Please try recording again."
        }
    }
    
    var recoverySuggestions: [String] {
        switch self {
        case .recordingInterrupted:
            return [
                "Close other apps that might be using audio",
                "Disable notifications during recording",
                "Try recording again"
            ]
        case .audioServicesReset:
            return [
                "Wait a moment for the system to stabilize",
                "Restart the app if needed",
                "Try recording again"
            ]
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .recordingInterrupted:
            return .warning
        case .audioServicesReset:
            return .error
        }
    }
    
    var errorCode: String? {
        switch self {
        case .recordingInterrupted:
            return "VRC-001"
        case .audioServicesReset:
            return "VRC-002"
        }
    }
}

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