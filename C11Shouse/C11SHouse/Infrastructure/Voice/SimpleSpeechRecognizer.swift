//
//  SimpleSpeechRecognizer.swift
//  C11SHouse
//
//  Simplified speech recognizer to debug error 1101
//

import Foundation
import Speech
import AVFoundation

/// Simplified speech recognizer for testing
@MainActor
class SimpleSpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var error: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    func startRecording() {
        error = nil
        transcript = ""
        
        // Check authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self?.error = "Speech recognition not authorized"
                }
                return
            }
            
            Task { @MainActor in
                await self?.startAudioRecording()
            }
        }
    }
    
    private func startAudioRecording() async {
        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            // Create temp file
            let tempDir = FileManager.default.temporaryDirectory
            audioFileURL = tempDir.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
            
            // Configure recorder
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)
            audioRecorder?.record()
            isRecording = true
            
            print("Started recording to: \(audioFileURL!)")
            
        } catch {
            self.error = "Recording failed: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        
        // Transcribe the recorded file
        if let url = audioFileURL {
            transcribeAudioFile(url: url)
        }
    }
    
    private func transcribeAudioFile(url: URL) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            error = "Speech recognizer not available"
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        
        // Don't use on-device recognition
        request.requiresOnDeviceRecognition = false
        request.shouldReportPartialResults = false
        
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.error = "Transcription error: \(error.localizedDescription)"
                    print("Transcription error details: \(error)")
                }
                return
            }
            
            if let result = result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                    print("Transcription successful: \(result.bestTranscription.formattedString)")
                }
            }
        }
    }
}