//
//  VoiceTranscriptionService.swift
//  C11SHouse
//
//  Created on 2025-07-03.
//

import Foundation
import Combine
import Speech

/// High-level service for voice transcription pipeline
@MainActor
final class VoiceTranscriptionService: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var currentTranscript = ""
    @Published private(set) var finalTranscript = ""
    @Published private(set) var isTranscribing = false
    @Published private(set) var confidenceLevel: ConfidenceLevel = .unknown
    @Published private(set) var transcriptionState: TranscriptionState = .idle
    @Published private(set) var processingMode: ProcessingMode = .onDevice
    
    // MARK: - Private Properties
    private let speechRecognizer = SpeechRecognizer()
    private var cancellables = Set<AnyCancellable>()
    private var transcriptionHistory: [TranscriptionEntry] = []
    private let transcriptionQueue = DispatchQueue(label: "com.c11shouse.transcription", qos: .userInitiated)
    
    // Configuration
    private let minimumConfidenceThreshold: Float = 0.5
    private let maximumTranscriptionDuration: TimeInterval = 60.0 // 1 minute max per session
    private var transcriptionTimer: Timer?
    
    // MARK: - Types
    enum TranscriptionState: Equatable {
        case idle
        case preparing
        case listening
        case processing
        case completed
        case error(String)
        
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .preparing: return "Preparing..."
            case .listening: return "Listening..."
            case .processing: return "Processing..."
            case .completed: return "Completed"
            case .error(let message): return "Error: \(message)"
            }
        }
    }
    
    enum ConfidenceLevel: String, CaseIterable {
        case unknown = "Unknown"
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case veryHigh = "Very High"
        
        init(from confidence: Float) {
            switch confidence {
            case 0..<0.3: self = .low
            case 0.3..<0.6: self = .medium
            case 0.6..<0.85: self = .high
            case 0.85...1.0: self = .veryHigh
            default: self = .unknown
            }
        }
        
        var color: String {
            switch self {
            case .unknown: return "gray"
            case .low: return "red"
            case .medium: return "orange"
            case .high: return "green"
            case .veryHigh: return "blue"
            }
        }
    }
    
    enum ProcessingMode: String, CaseIterable {
        case onDevice = "On-Device"
        case cloud = "Cloud"
        case hybrid = "Hybrid"
        
        var description: String {
            switch self {
            case .onDevice: return "Processing locally for privacy"
            case .cloud: return "Using cloud for better accuracy"
            case .hybrid: return "Optimizing between privacy and accuracy"
            }
        }
    }
    
    struct TranscriptionEntry: Identifiable {
        let id = UUID()
        let text: String
        let confidence: Float
        let timestamp: Date
        let duration: TimeInterval
        let processingMode: ProcessingMode
        let isFinal: Bool
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupBindings()
        configureProcessingMode()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind speech recognizer transcript
        speechRecognizer.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                self?.currentTranscript = transcript
            }
            .store(in: &cancellables)
        
        // Bind confidence updates
        speechRecognizer.$confidence
            .receive(on: DispatchQueue.main)
            .map { ConfidenceLevel(from: $0) }
            .assign(to: &$confidenceLevel)
        
        // Bind recording state
        speechRecognizer.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isTranscribing = isRecording
                self?.transcriptionState = isRecording ? .listening : .idle
            }
            .store(in: &cancellables)
        
        // Bind error states
        speechRecognizer.$error
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.transcriptionState = .error(error.localizedDescription)
                self?.stopTranscription()
            }
            .store(in: &cancellables)
        
        // Bind authorization status
        speechRecognizer.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status != .authorized {
                    self?.transcriptionState = .error("Speech recognition not authorized")
                }
            }
            .store(in: &cancellables)
    }
    
    private func configureProcessingMode() {
        // Determine processing mode based on device capabilities
        if #available(iOS 13.0, *) {
            processingMode = .onDevice
        } else {
            processingMode = .cloud
        }
    }
    
    // MARK: - Public Methods
    func startTranscription() async throws {
        guard transcriptionState == .idle || transcriptionState == .completed else {
            throw TranscriptionError.alreadyInProgress
        }
        
        transcriptionState = .preparing
        currentTranscript = ""
        
        // Request permissions if needed
        if speechRecognizer.authorizationStatus == .notDetermined {
            speechRecognizer.checkAuthorization()
            
            // Wait for authorization
            try await waitForAuthorization()
        }
        
        // Start transcription
        try await MainActor.run {
            try speechRecognizer.startRecording()
            startTranscriptionTimer()
            transcriptionState = .listening
        }
    }
    
    func stopTranscription() {
        speechRecognizer.stopRecording()
        transcriptionTimer?.invalidate()
        transcriptionTimer = nil
        
        if !currentTranscript.isEmpty {
            finalTranscript = currentTranscript
            saveTranscriptionEntry()
            transcriptionState = .completed
        } else {
            transcriptionState = .idle
        }
    }
    
    func pauseTranscription() {
        if isTranscribing {
            speechRecognizer.stopRecording()
            transcriptionState = .processing
        }
    }
    
    func resumeTranscription() throws {
        if transcriptionState == .processing {
            try speechRecognizer.startRecording()
            transcriptionState = .listening
        }
    }
    
    func resetTranscription() {
        speechRecognizer.reset()
        currentTranscript = ""
        finalTranscript = ""
        confidenceLevel = .unknown
        transcriptionState = .idle
        transcriptionTimer?.invalidate()
        transcriptionTimer = nil
    }
    
    // MARK: - Transcription Pipeline
    func processTranscriptionResult(_ text: String, confidence: Float) -> TranscriptionResult {
        // Apply confidence threshold
        let meetsThreshold = confidence >= minimumConfidenceThreshold
        
        // Post-process text
        let processedText = postProcessTranscript(text)
        
        // Create segments
        let segments = createTranscriptionSegments(from: processedText, confidence: confidence)
        
        return TranscriptionResult(
            text: processedText,
            confidence: confidence,
            segments: segments,
            isFinal: !isTranscribing,
            timestamp: Date()
        )
    }
    
    private func postProcessTranscript(_ text: String) -> String {
        var processed = text
        
        // Capitalize first letter
        if !processed.isEmpty {
            processed = processed.prefix(1).uppercased() + processed.dropFirst()
        }
        
        // Add punctuation if missing
        if !processed.isEmpty && !processed.hasSuffix(".") && !processed.hasSuffix("?") && !processed.hasSuffix("!") {
            processed += "."
        }
        
        // Clean up extra spaces
        processed = processed.replacingOccurrences(of: "  ", with: " ")
        
        return processed
    }
    
    private func createTranscriptionSegments(from text: String, confidence: Float) -> [TranscriptionSegment] {
        // For now, create a single segment
        // In a real implementation, this would parse actual speech segments
        return [
            TranscriptionSegment(
                text: text,
                confidence: confidence,
                timestamp: 0,
                duration: 0
            )
        ]
    }
    
    // MARK: - History Management
    func getTranscriptionHistory() -> [TranscriptionEntry] {
        return transcriptionHistory
    }
    
    func clearHistory() {
        transcriptionHistory.removeAll()
    }
    
    private func saveTranscriptionEntry() {
        let entry = TranscriptionEntry(
            text: finalTranscript,
            confidence: speechRecognizer.confidence,
            timestamp: Date(),
            duration: 0, // Would calculate actual duration
            processingMode: processingMode,
            isFinal: true
        )
        
        transcriptionHistory.append(entry)
        
        // Limit history size
        if transcriptionHistory.count > 100 {
            transcriptionHistory.removeFirst()
        }
    }
    
    // MARK: - Timer Management
    private func startTranscriptionTimer() {
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: maximumTranscriptionDuration, repeats: false) { [weak self] _ in
            self?.stopTranscription()
        }
    }
    
    // MARK: - Utility Methods
    private func waitForAuthorization() async throws {
        for _ in 0..<30 { // Wait up to 3 seconds
            if speechRecognizer.authorizationStatus == .authorized {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        throw TranscriptionError.authorizationTimeout
    }
    
    // MARK: - Error Types
    enum TranscriptionError: LocalizedError {
        case alreadyInProgress
        case authorizationTimeout
        case processingError(String)
        
        var errorDescription: String? {
            switch self {
            case .alreadyInProgress:
                return "Transcription already in progress"
            case .authorizationTimeout:
                return "Authorization timeout"
            case .processingError(let message):
                return "Processing error: \(message)"
            }
        }
    }
}

// MARK: - Service Configuration
extension VoiceTranscriptionService {
    struct Configuration {
        var minimumConfidence: Float = 0.5
        var maxDuration: TimeInterval = 60.0
        var preferOnDevice: Bool = true
        var autoCapitalize: Bool = true
        var autoPunctuate: Bool = true
        var enableNoiseCancellation: Bool = true
    }
    
    func configure(with configuration: Configuration) {
        // Apply configuration settings
        // This would update the service behavior
    }
}

// MARK: - Analytics Support
extension VoiceTranscriptionService {
    struct TranscriptionMetrics {
        let totalTranscriptions: Int
        let averageConfidence: Float
        let averageDuration: TimeInterval
        let successRate: Float
        let preferredMode: ProcessingMode
    }
    
    func getMetrics() -> TranscriptionMetrics {
        let validEntries = transcriptionHistory.filter { $0.isFinal }
        
        let totalConfidence = validEntries.reduce(0) { $0 + $1.confidence }
        let averageConfidence = validEntries.isEmpty ? 0 : totalConfidence / Float(validEntries.count)
        
        let totalDuration = validEntries.reduce(0) { $0 + $1.duration }
        let averageDuration = validEntries.isEmpty ? 0 : totalDuration / Double(validEntries.count)
        
        return TranscriptionMetrics(
            totalTranscriptions: validEntries.count,
            averageConfidence: averageConfidence,
            averageDuration: averageDuration,
            successRate: Float(validEntries.count) / Float(max(transcriptionHistory.count, 1)),
            preferredMode: processingMode
        )
    }
}