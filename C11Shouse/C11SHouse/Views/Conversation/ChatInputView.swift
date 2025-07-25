/*
 * CONTEXT & PURPOSE:
 * ChatInputView provides the input area for both text and voice messages.
 * It switches between text input and voice recording modes based on mute state.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Extracted from ConversationView for better modularity
 *   - Mute state controls input mode
 *   - Text input with send button when muted
 *   - Voice recording with live transcript when unmuted
 *   - Voice confirmation flow
 *   - Error display for recognition issues
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct ChatInputView: View {
    @ObservedObject var recognizer: ConversationRecognizer
    @Binding var inputText: String
    @Binding var isMuted: Bool
    @Binding var isProcessing: Bool
    @Binding var pendingVoiceText: String
    @Binding var showVoiceConfirmation: Bool
    @FocusState var isTextFieldFocused: Bool
    
    let onSendText: () -> Void
    let onToggleRecording: () -> Void
    let onConfirmVoice: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if let error = recognizer.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }
            
            HStack(spacing: 12) {
                if isMuted {
                    // Text input field with clear button
                    HStack {
                        TextField("Type a message...", text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                onSendText()
                            }
                        
                        // Clear button inside text field area
                        if !inputText.isEmpty {
                            Button(action: {
                                inputText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                            .accessibilityIdentifier("clear.text")
                            .accessibilityLabel("Clear")
                        }
                    }
                    
                    // Send button
                    Button(action: onSendText) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || isProcessing)
                    .accessibilityIdentifier("arrow.up.circle.fill")
                    .accessibilityLabel("Send")
                } else {
                    // Voice input
                    if showVoiceConfirmation {
                        VoiceConfirmationView(
                            pendingVoiceText: $pendingVoiceText,
                            isTextFieldFocused: $isTextFieldFocused,
                            onConfirm: onConfirmVoice,
                            onCancel: {
                                showVoiceConfirmation = false
                                pendingVoiceText = ""
                                recognizer.transcript = ""
                                isTextFieldFocused = false
                            }
                        )
                    } else {
                        HStack {
                            // Edit button on the left when recording with transcript
                            if recognizer.isRecording && !recognizer.transcript.isEmpty {
                                Button(action: {
                                    // Stop recording and show confirmation view for editing
                                    onToggleRecording()
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                }
                                .accessibilityIdentifier("pencil.circle.fill")
                                .accessibilityLabel("Edit")
                            }
                            
                            // Show live transcript while recording
                            if recognizer.isRecording && !recognizer.transcript.isEmpty {
                                Text(recognizer.transcript)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color(UIColor.secondarySystemFill))
                                    .cornerRadius(12)
                                    .transition(.opacity)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Spacer()
                            }
                            
                            VStack(spacing: 4) {
                                if recognizer.isRecording && !recognizer.transcript.isEmpty {
                                    // When recording with transcript, show confirm button
                                    Button(action: {
                                        // Stop recording - this will trigger voice confirmation
                                        onToggleRecording()
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.green)
                                    }
                                    .accessibilityIdentifier("checkmark.circle.fill")
                                    .accessibilityLabel("Confirm")
                                    
                                    Text("Confirm")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    // Normal recording button
                                    Button(action: onToggleRecording) {
                                        Image(systemName: recognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(recognizer.isRecording ? .red : .blue)
                                    }
                                    .disabled(recognizer.authorizationStatus != .authorized || isProcessing)
                                    .accessibilityIdentifier(recognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    
                                    Text(recognizer.isRecording ? "Recording..." : "Tap to speak")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !recognizer.isRecording || recognizer.transcript.isEmpty {
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}