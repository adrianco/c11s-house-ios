/*
 * CONTEXT & PURPOSE:
 * MessageBubbleView displays individual chat messages with proper styling and formatting.
 * It handles both user and house messages, voice indicators, and special question formatting.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Extracted from ConversationView for better modularity
 *   - Supports user and house message styling
 *   - Voice indicator overlay
 *   - Special handling for questions with suggested answers
 *   - Timestamp formatting
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let onAddressSubmit: ((String) -> Void)?
    
    init(message: Message, onAddressSubmit: ((String) -> Void)? = nil) {
        self.message = message
        self.onAddressSubmit = onAddressSubmit
    }
    
    // Check if this is a question with a suggested answer
    private var isQuestionWithSuggestion: Bool {
        // Check for common question patterns with newlines indicating suggested answers
        let questionPatterns = [
            "Is this the right address?",
            "What's your home address?",
            "What should I call this house?",
            "What's your name?",
            "What's your phone number?",
            "What's your email?"
        ]
        
        let result = questionPatterns.contains(where: { pattern in
            message.content.contains(pattern) && message.content.contains("\n")
        })
        
        return result
    }
    
    // Extract question and suggested answer
    private var questionAndAnswer: (question: String, answer: String)? {
        if isQuestionWithSuggestion {
            let components = message.content.components(separatedBy: "\n\n")
            if components.count >= 2 {
                let question = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let answer = components[1...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                return (question, answer)
            }
        }
        return nil
    }
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromUser && isQuestionWithSuggestion, 
                   let (question, answer) = questionAndAnswer {
                    // Use generic suggested answer view
                    SuggestedAnswerQuestionView(
                        question: question,
                        suggestedAnswer: answer,
                        icon: SuggestedAnswerQuestionView.icon(for: question)
                    ) { editedAnswer in
                        onAddressSubmit?(editedAnswer)
                    }
                } else {
                    // Regular message bubble
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(message.isFromUser ? Color.blue : Color(UIColor.secondarySystemBackground))
                        .foregroundColor(message.isFromUser ? .white : .primary)
                        .cornerRadius(20)
                        .overlay(
                            message.isVoice ?
                            Image(systemName: "mic.fill")
                                .font(.caption2)
                                .foregroundColor(message.isFromUser ? .white.opacity(0.7) : .secondary)
                                .offset(x: message.isFromUser ? -8 : 8, y: -8)
                            : nil,
                            alignment: message.isFromUser ? .topTrailing : .topLeading
                        )
                }
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isFromUser ? .trailing : .leading)
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: date)
    }
}