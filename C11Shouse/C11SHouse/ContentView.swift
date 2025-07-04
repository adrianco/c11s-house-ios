/*
 * CONTEXT & PURPOSE:
 * ContentView serves as the main landing screen for the C11S House app. It provides a welcoming
 * interface with app branding and navigation to the voice transcription feature. The view
 * emphasizes voice interaction through visual metaphors (waveform icon) and clear call-to-action.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Designed with house and waveform symbolism to represent "house consciousness"
 *   - Used gradient backgrounds and shadows for modern, depth-rich UI
 *   - NavigationView with StackNavigationViewStyle for iPad compatibility
 *   - Hidden navigation bar for immersive full-screen experience
 *   - ServiceContainer injected via @EnvironmentObject for dependency access
 *   - Navigation to FixedSpeechTestView for voice transcription functionality
 *   - Linear gradient on button and background for visual hierarchy
 *   - System colors used for automatic dark mode support
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var showDetailView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    
                    Text("Conscious House")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Conversations to help manage your house")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Main content area with navigation to voice transcription
                VStack(spacing: 20) {
                    Text("Record information about rooms and things\n\n Ask questions about how to get stuff done\n\n      Use your voice to control your home")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(radius: 10)
                    
                    
                    NavigationLink(destination: FixedSpeechTestView()) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Start Conversation")
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(radius: 5)
                    }
                    .padding(.top, 20)
                }
                .frame(maxHeight: .infinity)
                
                Spacer()
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
            .navigationTitle("C11S House")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // For iPad compatibility
    }
}


#Preview {
    ContentView()
        .environmentObject(ServiceContainer.shared)
}
