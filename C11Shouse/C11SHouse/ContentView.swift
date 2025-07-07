/*
 * CONTEXT & PURPOSE:
 * ContentView serves as the main landing screen for the C11S House app. It provides a welcoming
 * interface with app branding and navigation to the voice transcription feature. The view
 * features a custom programmatically generated app icon and clear call-to-action.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Designed with house and waveform symbolism to represent "house consciousness"
 *   - Used gradient backgrounds and shadows for modern, depth-rich UI
 *   - NavigationView with StackNavigationViewStyle for iPad compatibility
 *   - Hidden navigation bar for immersive full-screen experience
 *   - ServiceContainer injected via @EnvironmentObject for dependency access
 *   - Navigation to ConversationView for voice conversation functionality
 *   - Linear gradient on button and background for visual hierarchy
 *   - System colors used for automatic dark mode support
 * - 2025-07-04: Icon updates
 *   - Replaced static house.fill SF Symbol with dynamic AppIconCreator implementation
 *   - AppIconCreator generates gradient background with house + brain symbols
 *   - Removed waveform.circle.fill icon to simplify UI and focus on core branding
 *   - Added corner radius and shadow to the dynamic app icon
 * - 2025-07-04: Added personality placeholders
 *   - Added emotion state placeholder (default: "Curious")
 *   - Added house name placeholder (default: "Your House")
 *   - These will be updated based on user preferences and interactions
 * - 2025-07-04: Renamed FixedSpeech components to Conversation
 *   - Changed FixedSpeechTestView to ConversationView
 *   - Changed FixedSpeechRecognizer to ConversationRecognizer
 *   - Better reflects production use as conversation interface
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var showDetailView = false
    @State private var houseEmotion = "Curious"
    @State private var houseName = "Your House"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(uiImage: AppIconCreator.createIcon(size: CGSize(width: 200, height: 200)))
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                    
                    Text(houseName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Feeling \(houseEmotion.lowercased())")
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .padding(.bottom, 4)
                    
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
                    
                    NavigationLink(destination: ConversationView()) {
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
            .navigationTitle("Conscious House")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // For iPad compatibility
    }
}


#Preview {
    ContentView()
        .environmentObject(ServiceContainer.shared)
}
