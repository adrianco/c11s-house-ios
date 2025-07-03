//
//  SimpleSpeechTestView.swift
//  C11SHouse
//
//  Test view for debugging speech recognition
//

import SwiftUI

struct SimpleSpeechTestView: View {
    @StateObject private var recognizer = SimpleSpeechRecognizer()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Simple Speech Test")
                .font(.largeTitle)
                .padding()
            
            if let error = recognizer.error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                    .multilineTextAlignment(.center)
            }
            
            Text("Transcript:")
                .font(.headline)
            
            Text(recognizer.transcript.isEmpty ? "No transcript yet" : recognizer.transcript)
                .padding()
                .frame(minHeight: 100)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            Button(action: {
                if recognizer.isRecording {
                    recognizer.stopRecording()
                } else {
                    recognizer.startRecording()
                }
            }) {
                HStack {
                    Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                    Text(recognizer.isRecording ? "Stop Recording" : "Start Recording")
                }
                .foregroundColor(.white)
                .padding()
                .background(recognizer.isRecording ? Color.red : Color.blue)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Speech Test")
    }
}