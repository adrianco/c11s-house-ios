/*
 * CONTEXT & PURPOSE:
 * OnboardingCompletionView is the final step in the onboarding flow. It confirms
 * setup completion and directs users to start using the conversation interface
 * where they can add notes, ask questions, and interact with their house.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Created to replace Phase4TutorialView
 *   - Simplified completion screen
 *   - Directs users to conversation for note creation
 *   - No separate tutorial for notes - integrated into chat
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI

struct OnboardingCompletionView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.green, .mint]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(1.2)
                .shadow(radius: 10)
            
            // Title
            Text("Setup Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Description
            VStack(spacing: 16) {
                Text("Your house consciousness is ready to help you.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                
                Text("You can now:")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "message.fill", text: "Chat with your house")
                    FeatureRow(icon: "note.text", text: "Create notes about rooms and devices")
                    FeatureRow(icon: "questionmark.circle", text: "Answer setup questions")
                    FeatureRow(icon: "cloud.sun.fill", text: "Get weather updates")
                    FeatureRow(icon: "mic.fill", text: "Use voice or text input")
                }
                .padding(.horizontal, 40)
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            // Start Button
            Button(action: onComplete) {
                HStack {
                    Text("Start Chatting")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(30)
                .shadow(radius: 5)
            }
            .padding(.bottom, 50)
        }
        .padding()
        .onAppear {
            OnboardingLogger.shared.logUserAction("view_completion_screen", phase: "completion")
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct OnboardingCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingCompletionView(onComplete: {})
            .environmentObject(ServiceContainer.shared)
    }
}