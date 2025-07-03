//
//  AudioEngine.swift
//  C11SHouse
//
//  Created on 2025-07-03
//

import Foundation
import AVFoundation
import Combine
import Accelerate

/// Manages audio recording using AVAudioEngine with real-time buffer processing
@MainActor
final class AudioEngine: ObservableObject {
    
    // MARK: - Properties
    
    /// Published state for recording status
    @Published private(set) var isRecording = false
    
    /// Published state for audio levels (0.0 to 1.0)
    @Published private(set) var audioLevel: Float = 0.0
    
    /// Published state for recording duration
    @Published private(set) var recordingDuration: TimeInterval = 0.0
    
    /// The audio engine instance
    private let engine = AVAudioEngine()
    
    /// Input node for capturing audio
    private var inputNode: AVAudioInputNode { engine.inputNode }
    
    /// Audio format for recording
    private var recordingFormat: AVAudioFormat?
    
    /// Buffer for storing audio samples
    private var audioBuffer = AudioBuffer()
    
    /// Timer for updating recording duration
    private var durationTimer: Timer?
    
    /// Start time of recording
    private var recordingStartTime: Date?
    
    /// Audio session manager
    private let sessionManager = AudioSessionManager.shared
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Delegate for audio buffer processing
    weak var delegate: AudioEngineDelegate?
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
    }
    
    deinit {
        // Clean up audio engine without accessing @MainActor properties
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
    
    // MARK: - Public Methods
    
    /// Prepares the audio engine for recording
    /// - Throws: AudioEngineError if preparation fails
    func prepareForRecording() async throws {
        // Ensure we have recording permission
        if !sessionManager.hasRecordingPermission {
            let granted = await sessionManager.requestRecordingPermission()
            if !granted {
                throw AudioEngineError.permissionDenied
            }
        }
        
        // Configure and activate audio session
        try await sessionManager.configureForRecording()
        try await sessionManager.activateSession()
        
        // Reset the engine
        engine.reset()
        
        // Configure recording format
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw AudioEngineError.invalidAudioFormat
        }
        
        // Create standard recording format (mono, 44.1kHz)
        recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100.0,
            channels: 1,
            interleaved: false
        )
        
        guard let recordingFormat = recordingFormat else {
            throw AudioEngineError.formatCreationFailed
        }
        
        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 4096
        inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: recordingFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
        
        // Prepare the engine
        engine.prepare()
    }
    
    /// Starts audio recording
    /// - Throws: AudioEngineError if recording fails to start
    func startRecording() async throws {
        guard !isRecording else { return }
        
        // Clear previous recording data
        audioBuffer.clear()
        recordingDuration = 0.0
        audioLevel = 0.0
        
        // Start the engine
        do {
            try engine.start()
            isRecording = true
            recordingStartTime = Date()
            
            // Start duration timer
            startDurationTimer()
            
            // Notify delegate
            await delegate?.audioEngineDidStartRecording(self)
            
        } catch {
            throw AudioEngineError.engineStartFailed(error)
        }
    }
    
    /// Stops audio recording
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop duration timer
        stopDurationTimer()
        
        // Remove tap
        inputNode.removeTap(onBus: 0)
        
        // Stop the engine
        engine.stop()
        
        isRecording = false
        recordingStartTime = nil
        
        // Process final audio data
        Task { @MainActor in
            let audioData = audioBuffer.getAllData()
            await delegate?.audioEngineDidStopRecording(self, audioData: audioData)
        }
    }
    
    /// Pauses audio recording
    func pauseRecording() {
        guard isRecording else { return }
        engine.pause()
        stopDurationTimer()
        
        Task { @MainActor in
            await delegate?.audioEngineDidPauseRecording(self)
        }
    }
    
    /// Resumes audio recording
    /// - Throws: AudioEngineError if resume fails
    func resumeRecording() async throws {
        guard engine.isRunning else { return }
        
        do {
            try engine.start()
            startDurationTimer()
            await delegate?.audioEngineDidResumeRecording(self)
        } catch {
            throw AudioEngineError.engineStartFailed(error)
        }
    }
    
    /// Gets the current audio buffer data
    /// - Returns: Audio data as Data object
    func getCurrentAudioData() -> Data {
        return audioBuffer.getAllData()
    }
    
    /// Exports the recorded audio to a file
    /// - Parameter url: The URL to save the audio file
    /// - Throws: AudioEngineError if export fails
    func exportRecording(to url: URL) async throws {
        let audioData = audioBuffer.getAllData()
        guard !audioData.isEmpty else {
            throw AudioEngineError.noAudioData
        }
        
        // Create audio file
        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: recordingFormat?.settings ?? [:],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        
        // Convert data to audio buffer
        let buffer = try createPCMBuffer(from: audioData)
        try audioFile.write(from: buffer)
    }
    
    // MARK: - Private Methods
    
    /// Processes incoming audio buffer
    /// - Parameters:
    ///   - buffer: The audio buffer to process
    ///   - time: The audio time
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        
        // Calculate RMS for audio level
        var rms: Float = 0.0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameCount))
        
        // Convert to decibels and normalize
        let avgPower = 20 * log10(max(rms, 0.000001))
        let normalizedLevel = (avgPower + 60) / 60 // Normalize from -60dB to 0dB
        
        Task { @MainActor in
            self.audioLevel = max(0.0, min(1.0, normalizedLevel))
        }
        
        // Store audio data
        audioBuffer.append(buffer)
        
        // Notify delegate with buffer
        Task { @MainActor in
            await delegate?.audioEngine(self, didReceiveBuffer: buffer, atTime: time)
        }
    }
    
    /// Creates a PCM buffer from audio data
    /// - Parameter data: The audio data
    /// - Returns: AVAudioPCMBuffer
    /// - Throws: AudioEngineError if buffer creation fails
    private func createPCMBuffer(from data: Data) throws -> AVAudioPCMBuffer {
        guard let format = recordingFormat else {
            throw AudioEngineError.invalidAudioFormat
        }
        
        let frameCount = UInt32(data.count) / format.streamDescription.pointee.mBytesPerFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioEngineError.bufferCreationFailed
        }
        
        buffer.frameLength = frameCount
        
        data.withUnsafeBytes { bytes in
            if let channelData = buffer.floatChannelData {
                let samples = bytes.bindMemory(to: Float.self)
                channelData[0].update(from: samples.baseAddress!, count: Int(frameCount))
            }
        }
        
        return buffer
    }
    
    /// Starts the duration timer
    private func startDurationTimer() {
        stopDurationTimer()
        
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.recordingStartTime else { return }
            
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    /// Stops the duration timer
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    /// Sets up audio session notifications
    private func setupNotifications() {
        // Handle interruptions
        NotificationCenter.default.publisher(for: .audioSessionInterruptionBegan)
            .sink { [weak self] _ in
                self?.handleInterruption()
            }
            .store(in: &cancellables)
        
        // Handle media services reset
        NotificationCenter.default.publisher(for: .audioSessionMediaServicesReset)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleMediaServicesReset()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Handles audio interruptions
    private func handleInterruption() {
        if isRecording {
            pauseRecording()
            Task { @MainActor in
                await delegate?.audioEngineWasInterrupted(self)
            }
        }
    }
    
    /// Handles media services reset
    private func handleMediaServicesReset() async {
        if isRecording {
            stopRecording()
            
            // Try to reconfigure and restart
            do {
                try await prepareForRecording()
                await delegate?.audioEngineDidResetMediaServices(self)
            } catch {
                await delegate?.audioEngine(self, didFailWithError: error)
            }
        }
    }
}

// MARK: - AudioBuffer

/// Buffer for storing audio samples
private class AudioBuffer {
    private var buffers: [AVAudioPCMBuffer] = []
    private let queue = DispatchQueue(label: "com.c11shouse.audiobuffer", attributes: .concurrent)
    
    func append(_ buffer: AVAudioPCMBuffer) {
        queue.async(flags: .barrier) {
            self.buffers.append(buffer)
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.buffers.removeAll()
        }
    }
    
    func getAllData() -> Data {
        queue.sync {
            var data = Data()
            
            for buffer in buffers {
                guard let channelData = buffer.floatChannelData else { continue }
                
                let frameCount = Int(buffer.frameLength)
                let samples = UnsafeBufferPointer(start: channelData[0], count: frameCount)
                data.append(Data(buffer: samples))
            }
            
            return data
        }
    }
}

// MARK: - AudioEngineDelegate

/// Delegate protocol for audio engine events
protocol AudioEngineDelegate: AnyObject {
    /// Called when recording starts
    func audioEngineDidStartRecording(_ engine: AudioEngine) async
    
    /// Called when recording stops
    func audioEngineDidStopRecording(_ engine: AudioEngine, audioData: Data) async
    
    /// Called when recording pauses
    func audioEngineDidPauseRecording(_ engine: AudioEngine) async
    
    /// Called when recording resumes
    func audioEngineDidResumeRecording(_ engine: AudioEngine) async
    
    /// Called when audio buffer is received
    func audioEngine(_ engine: AudioEngine, didReceiveBuffer buffer: AVAudioPCMBuffer, atTime: AVAudioTime) async
    
    /// Called when audio engine encounters an error
    func audioEngine(_ engine: AudioEngine, didFailWithError error: Error) async
    
    /// Called when audio recording is interrupted
    func audioEngineWasInterrupted(_ engine: AudioEngine) async
    
    /// Called when media services are reset
    func audioEngineDidResetMediaServices(_ engine: AudioEngine) async
}

// MARK: - AudioEngineError

/// Errors that can occur during audio engine operations
enum AudioEngineError: LocalizedError {
    case permissionDenied
    case invalidAudioFormat
    case formatCreationFailed
    case engineStartFailed(Error)
    case bufferCreationFailed
    case noAudioData
    case exportFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required for voice recording"
        case .invalidAudioFormat:
            return "Invalid audio format detected"
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .noAudioData:
            return "No audio data available to export"
        case .exportFailed(let error):
            return "Failed to export audio: \(error.localizedDescription)"
        }
    }
}