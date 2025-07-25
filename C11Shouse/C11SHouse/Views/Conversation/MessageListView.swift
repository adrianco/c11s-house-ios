/*
 * CONTEXT & PURPOSE:
 * MessageListView displays a scrollable list of chat messages with automatic scrolling to new messages.
 * It handles the message display and scrolling behavior for the conversation interface.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Extracted from ConversationView for better modularity
 *   - Auto-scroll to latest message
 *   - Lazy loading of messages for performance
 *   - Support for address submission callbacks
 *   - Extra padding for input area clearance
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct MessageListView: View {
    @ObservedObject var messageStore: MessageStore
    @Binding var scrollToBottom: Bool
    let onAddressSubmit: (String) -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messageStore.messages) { message in
                        MessageBubbleView(message: message) { editedAddress in
                            onAddressSubmit(editedAddress)
                        }
                        .id(message.id)
                    }
                    
                    // Invisible anchor for scrolling with extra padding
                    Color.clear
                        .frame(height: 60) // Increased height to ensure messages clear the input area
                        .id("bottom")
                }
                .padding()
                .padding(.bottom, 20) // Extra bottom padding
            }
            .onChange(of: messageStore.messages.count) { _, _ in
                // Scroll immediately when messages change
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: scrollToBottom) { _, shouldScroll in
                if shouldScroll {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    scrollToBottom = false
                }
            }
        }
    }
}