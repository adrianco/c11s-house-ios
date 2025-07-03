//
//  HybridVoiceTranscriptionView.swift
//  C11SHouse
//
//  Voice transcription view using hybrid approach to avoid error 1101
//

import SwiftUI

struct HybridVoiceTranscriptionView: View {
    @StateObject private var recognizer = HybridSpeechRecognizer()
    @State private var animationScale: CGFloat = 1.0
    @State private var waveformAnimation: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: recognizer.isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(recognizer.isRecording ? .red : .blue)
                        .symbolEffect(.pulse, value: recognizer.isRecording)
                    
                    Text(recognizer.isRecording ? "Listening..." : "Tap to speak")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 20)
                
                if let error = recognizer.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Transcription Display
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !recognizer.transcript.isEmpty {
                        Text(recognizer.transcript)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        
                        if recognizer.confidence > 0 {
                            HStack {
                                Text("Confidence:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ProgressView(value: recognizer.confidence)
                                    .tint(confidenceColor(recognizer.confidence))
                                
                                Text("\(Int(recognizer.confidence * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "waveform")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text("Your transcription will appear here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding()
                    }
                }
                .padding()
            }
            
            Spacer()
            
            // Recording Button
            Button(action: {
                withAnimation(.spring()) {
                    recognizer.toggleRecording()
                }
            }) {
                ZStack {
                    // Ripple effect
                    if recognizer.isRecording {
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(Color.red.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                                .frame(width: 80 + CGFloat(index * 30), height: 80 + CGFloat(index * 30))
                                .scaleEffect(waveformAnimation ? 1.2 : 1.0)
                                .opacity(waveformAnimation ? 0 : 1)
                                .animation(
                                    Animation.easeOut(duration: 1.5)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(index) * 0.2),
                                    value: waveformAnimation
                                )
                        }
                    }
                    
                    Circle()
                        .fill(recognizer.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .scaleEffect(animationScale)
                        .shadow(color: recognizer.isRecording ? .red.opacity(0.4) : .blue.opacity(0.4), 
                                radius: recognizer.isRecording ? 20 : 10)
                    
                    Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.white)
                }
            }
            .disabled(recognizer.authorizationStatus != .authorized)
            .padding(.bottom, 30)
            .onAppear {
                withAnimation {
                    waveformAnimation = true
                }
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.secondarySystemBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Voice Transcription")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: recognizer.isRecording) { isRecording in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                animationScale = isRecording ? 1.1 : 1.0
            }
        }
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .yellow
        case 0.4..<0.6:
            return .orange
        default:
            return .red
        }
    }
}