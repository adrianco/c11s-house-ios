/*
 * CONTEXT & PURPOSE:
 * AddressQuestionView provides a special UI for address questions in the conversation.
 * It shows the detected address with clear editing capabilities, making it obvious
 * that users can modify the address if needed.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Initial implementation
 *   - Shows detected address prominently
 *   - Clear edit button with pencil icon
 *   - Inline editing with save/cancel
 *   - Integrates with conversation flow
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI

struct AddressQuestionView: View {
    let detectedAddress: String
    let onSubmit: (String) -> Void
    
    @State private var isEditing = false
    @State private var editedAddress = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text("Is this the right address?")
                    .font(.headline)
            }
            
            if isEditing {
                // Edit mode
                VStack(spacing: 12) {
                    TextField("Enter your address", text: $editedAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onAppear {
                            editedAddress = detectedAddress
                            isTextFieldFocused = true
                        }
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            isEditing = false
                            editedAddress = detectedAddress
                        }) {
                            Text("Cancel")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            onSubmit(editedAddress)
                            isEditing = false
                        }) {
                            Text("Save")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(20)
                        }
                    }
                }
            } else {
                // Display mode
                HStack {
                    Text(detectedAddress)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    Button(action: {
                        isEditing = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(12)
                
                HStack(spacing: 16) {
                    Text("Tap the pencil to edit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        onSubmit(detectedAddress)
                    }) {
                        Text("Yes, this is correct")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(15)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
    }
}

// MARK: - Preview

struct AddressQuestionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AddressQuestionView(
                detectedAddress: "123 Main Street, San Francisco, CA 94105",
                onSubmit: { _ in }
            )
            .padding()
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}