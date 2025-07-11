/*
 * CONTEXT & PURPOSE:
 * SuggestedAnswerQuestionView provides a unified UI for all questions that have
 * suggested answers. It shows the question with a pre-populated answer that can
 * be confirmed or edited. This replaces separate views for address, name, etc.
 *
 * DECISION HISTORY:
 * - 2025-01-11: Initial implementation
 *   - Generic view for any question with suggested answer
 *   - Shows question with icon based on type
 *   - Pre-populated answer with edit capability
 *   - Consistent confirmation flow
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI

struct SuggestedAnswerQuestionView: View {
    let question: String
    let suggestedAnswer: String
    let icon: String
    let onSubmit: (String) -> Void
    
    @State private var isEditing = false
    @State private var editedAnswer = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(question)
                    .font(.headline)
            }
            
            if isEditing {
                // Edit mode
                VStack(spacing: 12) {
                    TextField("Enter your answer", text: $editedAnswer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onAppear {
                            editedAnswer = suggestedAnswer
                            isTextFieldFocused = true
                        }
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            isEditing = false
                            editedAnswer = suggestedAnswer
                        }) {
                            Text("Cancel")
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            let trimmed = editedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                onSubmit(trimmed)
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(20)
                        }
                    }
                }
            } else {
                // Display mode
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestedAnswer)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Text("Tap the pencil to edit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
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
                .background(Color(UIColor.secondarySystemFill))
                .cornerRadius(12)
                
                // Confirm button
                Button(action: {
                    onSubmit(suggestedAnswer)
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Yes, this is correct")
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
    }
}

// Helper to determine icon based on question type
extension SuggestedAnswerQuestionView {
    static func icon(for question: String) -> String {
        if question.lowercased().contains("address") {
            return "location.fill"
        } else if question.lowercased().contains("house") {
            return "house.fill"
        } else if question.lowercased().contains("name") {
            return "person.fill"
        } else {
            return "questionmark.circle.fill"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SuggestedAnswerQuestionView(
            question: "Is this the right address?",
            suggestedAnswer: "123 Main Street, San Francisco, CA",
            icon: "location.fill"
        ) { answer in
            print("Submitted: \(answer)")
        }
        
        SuggestedAnswerQuestionView(
            question: "What should I call this house?",
            suggestedAnswer: "Main House",
            icon: "house.fill"
        ) { answer in
            print("Submitted: \(answer)")
        }
        
        SuggestedAnswerQuestionView(
            question: "What's your name?",
            suggestedAnswer: "John Doe",
            icon: "person.fill"
        ) { answer in
            print("Submitted: \(answer)")
        }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
}