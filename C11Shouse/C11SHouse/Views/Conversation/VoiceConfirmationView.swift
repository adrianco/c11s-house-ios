/*
 * CONTEXT & PURPOSE:
 * VoiceConfirmationView displays an editable transcription after voice input.
 * Users can review, edit, and confirm or cancel their voice message before sending.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Extracted from ConversationView for better modularity
 *   - Editable text field for transcription
 *   - Cancel and confirm buttons
 *   - Keyboard submit support
 *   - Voice indicator icon
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct VoiceConfirmationView: View {
    @Binding var pendingVoiceText: String
    @FocusState.Binding var isTextFieldFocused: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Review and edit your message:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TextField("Edit your message...", text: $pendingVoiceText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        onConfirm()
                    }
            }
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                Button(action: onConfirm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(pendingVoiceText.isEmpty ? .gray : .green)
                }
                .disabled(pendingVoiceText.isEmpty)
            }
        }
    }
}