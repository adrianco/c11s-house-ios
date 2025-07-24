/*
 * CONTEXT & PURPOSE:
 * VoiceTranscriptionViewModel is the central coordinator for voice transcription functionality,
 * implementing MVVM pattern with Combine. It manages recording state, coordinates between services,
 * handles timers, detects silence, and provides reactive UI updates through published properties.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - MVVM architecture with ObservableObject for SwiftUI binding
 *   - @MainActor for thread-safe UI updates
 *   - Dependency injection of services for testability
 *   - Protocol-based service interfaces for flexibility
 *   - Combine publishers for reactive state management
 *   - State machine pattern using TranscriptionState enum
 *   - Recording timer with 0.1s precision for duration tracking
 *   - Audio level monitoring at 50ms intervals (20Hz)
 *   - Silence detection with configurable threshold
 *   - Auto-stop after silence period if speech detected
 *   - Speech detection threshold at -35dB
 *   - Transcription history tracking for session
 *   - Error recovery with retry capability
 *   - Permission handling integrated with state flow
 *   - Task-based async/await for service calls
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  VoiceTranscriptionViewModel.swift
//  C11SHouse
//
//  ViewModel for voice transcription feature using Combine
//

import Foundation
import Combine
import AVFoundation

/// Main ViewModel for voice transcription functionality
@MainActor
class VoiceTranscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current state of the transcription system
    @Published private(set) var state: TranscriptionState = .idle
    
    /// Current audio level for visualization
    @Published private(set) var audioLevel: AudioLevel = .silent
    
    /// Transcribed text (latest result)
    @Published private(set) var transcribedText: String = ""
    
    /// History of all transcriptions in this session
    @Published private(set) var transcriptionHistory: [TranscriptionResult] = []
    
    /// Whether the system is currently recording
    @Published private(set) var isRecording: Bool = false
    
    /// Current recording duration
    @Published private(set) var recordingDuration: TimeInterval = 0
    
    /// Whether microphone permission is granted
    @Published private(set) var isMicrophoneAuthorized: Bool = false
    
    // MARK: - Private Properties
    
    private let configuration: TranscriptionConfiguration
    private var cancellables = Set<AnyCancellable>()
    
    // Service dependencies (to be injected)
    private let audioRecorder: AudioRecorderService
    private let transcriptionService: TranscriptionService
    private let permissionManager: PermissionManager
    
    // Timers and monitoring
    private var recordingTimer: Timer?
    private var audioLevelTimer: Timer?
    private var silenceDetectionTimer: Timer?
    
    // Audio monitoring
    private var lastSoundTime: Date = Date()
    private var hasDetectedSpeech: Bool = false
    private var isStartingRecording: Bool = false
    
    // MARK: - Initialization
    
    init(
        configuration: TranscriptionConfiguration = .default,
        audioRecorder: AudioRecorderService,
        transcriptionService: TranscriptionService,
        permissionManager: PermissionManager
    ) {
        self.configuration = configuration
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.permissionManager = permissionManager
        
        setupBindings()
        checkMicrophonePermission()
    }
    
    // MARK: - Public Methods
    
    /// Start recording audio for transcription
    func startRecording() {
        guard state.canStartRecording else {
            print("Cannot start recording in current state: \(state)")
            return
        }
        
        guard !isStartingRecording else {
            print("Already starting recording, ignoring duplicate call")
            return
        }
        
        isStartingRecording = true
        Task {
            await handleStartRecording()
            isStartingRecording = false
        }
    }
    
    /// Stop recording and process transcription
    func stopRecording() {
        guard state.isRecording else {
            print("Not currently recording")
            return
        }
        
        Task {
            await handleStopRecording()
        }
    }
    
    /// Cancel the current recording without processing
    func cancelRecording() {
        guard state.isRecording || state.isProcessing else {
            return
        }
        
        stopTimers()
        audioRecorder.cancelRecording()
        updateState(.cancelled)
    }
    
    /// Clear transcription history
    func clearHistory() {
        transcriptionHistory.removeAll()
        transcribedText = ""
    }
    
    /// Retry after an error
    func retry() {
        if case .error(let error) = state, error.isRecoverable {
            updateState(.idle)
            checkMicrophonePermission()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor state changes
        $state
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
            }
            .store(in: &cancellables)
        
        // Monitor audio level updates from recorder
        audioRecorder.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
                self?.detectSpeech(level: level)
            }
            .store(in: &cancellables)
        
        // Monitor recording state
        audioRecorder.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
            }
            .store(in: &cancellables)
    }
    
    private func checkMicrophonePermission() {
        Task {
            let isAuthorized = permissionManager.isMicrophoneGranted
            await MainActor.run {
                self.isMicrophoneAuthorized = isAuthorized
                if isAuthorized {
                    updateState(.ready)
                } else {
                    updateState(.error(.microphonePermissionDenied))
                }
            }
        }
    }
    
    private func handleStartRecording() async {
        updateState(.preparing)
        
        do {
            // Check permission
            if !isMicrophoneAuthorized {
                updateState(.error(.microphonePermissionDenied))
                return
            }
            
            // Start recording
            try await audioRecorder.startRecording(configuration: configuration)
            
            // Update state and start monitoring
            updateState(.recording(duration: 0))
            startTimers()
            hasDetectedSpeech = false
            
        } catch {
            updateState(.error(.recordingFailed(error.localizedDescription)))
        }
    }
    
    private func handleStopRecording() async {
        stopTimers()
        updateState(.processing)
        
        do {
            // Stop recording and get audio data
            let audioData = try await audioRecorder.stopRecording()
            
            // Process transcription
            let result = try await transcriptionService.transcribe(
                audioData: audioData,
                configuration: configuration
            )
            
            // Update state with result
            transcribedText = result.text
            transcriptionHistory.append(result)
            updateState(.transcribed(text: result.text))
            
        } catch {
            if let transcriptionError = error as? TranscriptionError {
                updateState(.error(transcriptionError))
            } else {
                updateState(.error(.transcriptionFailed(error.localizedDescription)))
            }
        }
    }
    
    private func handleStateChange(_ newState: TranscriptionState) {
        switch newState {
        case .recording:
            recordingDuration = 0
        case .idle, .ready, .transcribed, .error, .cancelled:
            recordingDuration = 0
            stopTimers()
        default:
            break
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimers() {
        // Ensure timers are scheduled on main thread's run loop
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Recording duration timer
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingDuration += 0.1
                self.updateState(.recording(duration: self.recordingDuration))
                
                // Check maximum duration
                if self.recordingDuration >= self.configuration.maxRecordingDuration {
                    Task { await self.handleStopRecording() }
                }
            }
            
            // Audio level monitoring timer
            self.audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.audioRecorder.updateAudioLevel()
            }
            
            // Silence detection timer
            if self.configuration.silenceThreshold > 0 {
                self.silenceDetectionTimer = Timer.scheduledTimer(
                    withTimeInterval: self.configuration.silenceThreshold,
                    repeats: false
                ) { [weak self] _ in
                    guard let self = self else { return }
                    if self.hasDetectedSpeech && 
                       Date().timeIntervalSince(self.lastSoundTime) >= self.configuration.silenceThreshold {
                        // Auto-stop after silence
                        Task { await self.handleStopRecording() }
                    }
                }
            }
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        silenceDetectionTimer?.invalidate()
        silenceDetectionTimer = nil
    }
    
    private func detectSpeech(level: AudioLevel) {
        // Simple speech detection based on audio level
        let speechThreshold: Float = -35.0 // dB
        
        if level.powerLevel > speechThreshold {
            hasDetectedSpeech = true
            lastSoundTime = Date()
            
            // Reset silence timer
            silenceDetectionTimer?.invalidate()
            if configuration.silenceThreshold > 0 && state.isRecording {
                silenceDetectionTimer = Timer.scheduledTimer(
                    withTimeInterval: configuration.silenceThreshold,
                    repeats: false
                ) { [weak self] _ in
                    guard let self = self else { return }
                    Task { @MainActor in
                        if Date().timeIntervalSince(self.lastSoundTime) >= self.configuration.silenceThreshold {
                            await self.handleStopRecording()
                        }
                    }
                }
            }
        }
    }
    
    private func updateState(_ newState: TranscriptionState) {
        state = newState
    }
}

// MARK: - Service Protocols

/// Protocol for audio recording service
protocol AudioRecorderService {
    var audioLevelPublisher: AnyPublisher<AudioLevel, Never> { get }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    
    func startRecording(configuration: TranscriptionConfiguration) async throws
    func stopRecording() async throws -> Data
    func cancelRecording()
    func updateAudioLevel()
}

/// Protocol for transcription service
protocol TranscriptionService {
    func transcribe(audioData: Data, configuration: TranscriptionConfiguration) async throws -> TranscriptionResult
}

// Using the actual PermissionManager class from Infrastructure/Voice/PermissionManager.swift