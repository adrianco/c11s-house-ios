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
 *   - Replaced static house.fill SF Symbol with dynamic AppIconCreatorLegacy implementation
 *   - AppIconCreatorLegacy generates gradient background with house + brain symbols
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
 * - 2025-07-07: Added Notes & Questions navigation
 *   - Added NavigationLink to NotesView below Start Conversation button
 *   - Used note.text SF Symbol for visual consistency
 *   - Applied teal-to-blue gradient to differentiate from conversation button
 *   - Maintained consistent styling with existing button design
 * - 2025-07-08: Weather and location integration
 *   - Added ContentViewModel for weather data management
 *   - Display current weather conditions with emoji icons
 *   - House emotions react to weather conditions
 *   - Location permission request on first launch
 *   - Weather refresh button with loading state
 *   - Error handling for weather service failures
 * - 2025-01-09: Removed unused AddressConfirmationView
 *   - Address lookup happens in background and populates notes
 *   - User edits address through conversation flow, not separate view
 *   - Removed showAddressConfirmation state and sheet presentation
 * - 2025-07-10: Updated to use ViewModelFactory
 *   - Changed from ServiceContainer.shared.makeContentViewModel()
 *   - Now using ViewModelFactory.shared.makeContentViewModel()
 *   - Follows separation of concerns principle
 * - 2025-07-11: Cleaned up UI with settings menu
 *   - Moved secondary actions (Notes, Voice Settings, Test Voice) to settings menu
 *   - Added gear icon button in top-right corner with dropdown menu
 *   - Simplified main view to focus on primary "Start Conversation" action
 *   - Improved visual hierarchy and reduced clutter
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @StateObject private var viewModel: ContentViewModel
    @State private var showOnboardingInvitation = false
    @State private var showSettings = false
    @State private var showNotesView = false
    @State private var showVoiceSettings = false
    @State private var showVoiceTest = false
    
    init() {
        _viewModel = StateObject(wrappedValue: ViewModelFactory.shared.makeContentViewModel())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                    Image(uiImage: AppIconCreatorLegacy.createIcon(size: CGSize(width: 200, height: 200)))
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                    
                    Text(viewModel.houseName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let thought = viewModel.houseThought {
                        HStack(spacing: 4) {
                            Text(thought.emotion.emoji)
                            Text("Feeling \(thought.emotion.displayName.lowercased())")
                        }
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .padding(.bottom, 4)
                    }
                    
                    // Weather display or address prompt
                    if viewModel.currentAddress != nil {
                        // Weather display
                        if let weather = viewModel.currentWeather {
                            HStack(spacing: 12) {
                                Image(systemName: weather.condition.icon)
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                Text(weather.temperature.formatted)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                
                                Text(weather.condition.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(20)
                        }
                        
                        // Weather loading/error states
                        if viewModel.isLoadingWeather {
                            ProgressView()
                                .padding(.top, 4)
                        } else if viewModel.weatherError != nil {
                            Button(action: {
                                Task { await viewModel.refreshWeather() }
                            }) {
                                Label("Retry Weather", systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    } else {
                        // No address set - show onboarding invitation
                        Button(action: { showOnboardingInvitation = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.body)
                                    .foregroundColor(.blue)
                                Text("Tap here to set up your home")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                    
                    Text("Conversations to help manage your house")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Main content area with navigation to voice transcription
                VStack(spacing: 20) {
                    // House thought display
                    if let thought = viewModel.houseThought {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(thought.thought)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    
                    NavigationLink(destination: ConversationView()) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Chat with House")
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
            
            // Settings button overlay
            VStack {
                HStack {
                    Spacer()
                    
                    Menu {
                        Button(action: { showNotesView = true }) {
                            Label("Manage Notes", systemImage: "note.text")
                        }
                        
                        Button(action: { showVoiceSettings = true }) {
                            Label("Voice Settings", systemImage: "speaker.wave.2.fill")
                        }
                        
                        Button(action: { showVoiceTest = true }) {
                            Label("Test Voice", systemImage: "waveform")
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                
                Spacer()
            }
            }  // End of ZStack
        }
        .navigationViewStyle(StackNavigationViewStyle()) // For iPad compatibility
        .background(
            NavigationLink(destination: NotesView(), isActive: $showNotesView) {
                EmptyView()
            }
        )
        .background(
            NavigationLink(destination: VoiceSettingsView(), isActive: $showVoiceSettings) {
                EmptyView()
            }
        )
        .background(
            NavigationLink(destination: VoiceTestView(), isActive: $showVoiceTest) {
                EmptyView()
            }
        )
        .onAppear {
            checkLocationPermission()
            checkOnboardingStatus()
        }
    }
    
    private func checkLocationPermission() {
        Task {
            if !viewModel.hasLocationPermission {
                await viewModel.requestLocationPermission()
            }
            
            // Load address and weather data if we have permission
            if viewModel.hasLocationPermission {
                await viewModel.loadAddressAndWeather()
            }
        }
    }
    
    private func checkOnboardingStatus() {
        Task {
            // Check if required questions are answered
            let requiredComplete = await serviceContainer.notesService.areAllRequiredQuestionsAnswered()
            
            // Show invitation if setup not complete
            await MainActor.run {
                showOnboardingInvitation = !requiredComplete && viewModel.currentAddress == nil
            }
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(ServiceContainer.shared)
}
