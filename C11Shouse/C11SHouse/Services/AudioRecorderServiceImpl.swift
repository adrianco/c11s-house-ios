/*
 * CONTEXT & PURPOSE:
 * AudioRecorderServiceImpl is the concrete implementation of the AudioRecorderService protocol,
 * providing audio recording functionality using AVAudioEngine. It handles audio capture, level
 * monitoring, file management, and publishes reactive state updates via Combine publishers.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Protocol-based design for testability and flexibility
 *   - AVAudioEngine chosen for low-level control and buffer access
 *   - Combine publishers for reactive audio level and recording state updates
 *   - Temporary WAV file storage in Documents directory
 *   - PCM Float32 format for high-quality audio capture
 *   - Buffer size: 1024 frames for real-time processing
 *   - RMS calculation for power level in dB
 *   - Peak level detection for visual feedback
 *   - Moving average buffer (size 10) for smooth level visualization
 *   - Audio session configuration: playAndRecord with defaultToSpeaker
 *   - Automatic cleanup of temporary files
 *   - Thread-safe audio level updates via main queue dispatch
 *   - Error handling with descriptive TranscriptionError types
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  AudioRecorderServiceImpl.swift
//  C11SHouse
//
//  Concrete implementation of audio recording service
//

import Foundation
import AVFoundation
import Combine

/// Concrete implementation of AudioRecorderService using AVAudioEngine
class AudioRecorderServiceImpl: NSObject, AudioRecorderService {
    
    // MARK: - Published Properties
    
    private let audioLevelSubject = CurrentValueSubject<AudioLevel, Never>(.silent)
    var audioLevelPublisher: AnyPublisher<AudioLevel, Never> {
        audioLevelSubject.eraseToAnyPublisher()
    }
    
    private let isRecordingSubject = CurrentValueSubject<Bool, Never>(false)
    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        isRecordingSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingFileURL: URL?
    private var inputNode: AVAudioInputNode?
    
    // Audio level monitoring
    private var audioLevelBuffer: [Float] = []
    private let audioLevelBufferSize = 10
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - AudioRecorderService Implementation
    
    func startRecording(configuration: TranscriptionConfiguration) async throws {
        // Stop any existing recording
        if audioEngine.isRunning {
            cancelRecording()
        }
        
        // Create temporary file for recording
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        recordingFileURL = documentsPath.appendingPathComponent(fileName)
        
        guard let recordingURL = recordingFileURL else {
            throw TranscriptionError.recordingFailed("Failed to create recording file")
        }
        
        // Configure audio format
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: configuration.sampleRate,
            channels: AVAudioChannelCount(configuration.channels),
            interleaved: false
        )
        
        guard let format = audioFormat else {
            throw TranscriptionError.invalidAudioFormat
        }
        
        // Create audio file
        do {
            audioFile = try AVAudioFile(forWriting: recordingURL, settings: format.settings)
        } catch {
            throw TranscriptionError.recordingFailed("Failed to create audio file: \(error.localizedDescription)")
        }
        
        // Setup audio engine
        inputNode = audioEngine.inputNode
        
        guard let inputNode = inputNode else {
            throw TranscriptionError.recordingFailed("No audio input available")
        }
        
        // Install tap on input node
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Write to file
            if let audioFile = self.audioFile {
                do {
                    try audioFile.write(from: buffer)
                } catch {
                    print("Error writing audio buffer: \(error)")
                }
            }
            
            // Update audio level
            self.processAudioBuffer(buffer)
        }
        
        // Prepare and start engine
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async { [weak self] in
                self?.isRecordingSubject.send(true)
            }
        } catch {
            inputNode.removeTap(onBus: 0)
            throw TranscriptionError.recordingFailed("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() async throws -> Data {
        guard audioEngine.isRunning else {
            throw TranscriptionError.recordingFailed("Not currently recording")
        }
        
        // Stop recording
        audioEngine.stop()
        inputNode?.removeTap(onBus: 0)
        DispatchQueue.main.async { [weak self] in
            self?.isRecordingSubject.send(false)
            self?.audioLevelSubject.send(.silent)
        }
        
        // Close audio file
        audioFile = nil
        
        // Read recorded data
        guard let recordingURL = recordingFileURL else {
            throw TranscriptionError.recordingFailed("No recording file found")
        }
        
        do {
            let audioData = try Data(contentsOf: recordingURL)
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: recordingURL)
            recordingFileURL = nil
            
            return audioData
        } catch {
            throw TranscriptionError.recordingFailed("Failed to read audio data: \(error.localizedDescription)")
        }
    }
    
    func cancelRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        inputNode?.removeTap(onBus: 0)
        DispatchQueue.main.async { [weak self] in
            self?.isRecordingSubject.send(false)
            self?.audioLevelSubject.send(.silent)
        }
        audioFile = nil
        
        // Clean up temporary file
        if let recordingURL = recordingFileURL {
            try? FileManager.default.removeItem(at: recordingURL)
            recordingFileURL = nil
        }
    }
    
    func updateAudioLevel() {
        // Audio level is updated automatically via the tap callback
        // This method is here for compatibility but doesn't need to do anything
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))
        
        // Calculate RMS (Root Mean Square) for power level
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        let powerLevel = 20 * log10(max(rms, 0.000001)) // Convert to dB
        
        // Calculate peak level
        let peakLevel = 20 * log10(max(channelDataArray.map { abs($0) }.max() ?? 0.000001, 0.000001))
        
        // Update buffer for average calculation
        audioLevelBuffer.append(powerLevel)
        if audioLevelBuffer.count > audioLevelBufferSize {
            audioLevelBuffer.removeFirst()
        }
        
        // Calculate average level
        let averageLevel = audioLevelBuffer.reduce(0, +) / Float(audioLevelBuffer.count)
        
        // Update audio level
        let audioLevel = AudioLevel(
            powerLevel: powerLevel,
            peakLevel: peakLevel,
            averageLevel: averageLevel
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevelSubject.send(audioLevel)
        }
    }
    
    deinit {
        cancelRecording()
    }
}