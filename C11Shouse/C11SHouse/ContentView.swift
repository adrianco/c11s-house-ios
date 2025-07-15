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
    @State private var showSettings = false
    @State private var showNotesView = false
    @State private var showVoiceSettings = false
    @State private var showVoiceTest = false
    @State private var currentError: UserFriendlyError?
    
    init() {
        _viewModel = StateObject(wrappedValue: ViewModelFactory.shared.makeContentViewModel())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.secondarySystemBackground)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 30) {
                    // App icon and title
                    VStack(spacing: 16) {
                        Image(uiImage: AppIconCreatorLegacy.createIcon(size: CGSize(width: 200, height: 200)))
                            .resizable()
                            .frame(width: 120, height: 120)
                            .cornerRadius(24)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Text(viewModel.houseName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let thought = viewModel.houseThought {
                            HStack(spacing: 4) {
                                Text(thought.emotion.emoji)
                                    .font(.title2)
                                Text("Feeling \(thought.emotion.displayName.lowercased())")
                                    .font(.headline)
                            }
                            .foregroundStyle(.tint)
                        }
                        
                        Text("Conversations to help manage your house")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    // Weather and thought section
                    VStack(spacing: 16) {
                        // Weather display
                        if viewModel.currentAddress != nil {
                            if let weather = viewModel.currentWeather {
                                HStack(spacing: 12) {
                                    Image(systemName: weather.condition.icon)
                                        .font(.title2)
                                        .foregroundColor(weather.condition.iconColor)
                                    
                                    Text(weather.temperature.formatted)
                                        .font(.title2)
                                        .fontWeight(.medium)
                                    
                                    Text(weather.condition.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(20)
                            }
                            
                            if viewModel.isLoadingWeather {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let weatherError = viewModel.weatherError {
                                Button(action: {
                                    currentError = weatherError.asUserFriendlyError
                                }) {
                                    Label("Weather Error", systemImage: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        // House thought
                        if let thought = viewModel.houseThought {
                            Text(thought.thought)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .frame(maxWidth: 340)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }
                    }
                    
                    Spacer()
                    
                    // Start conversation button
                    NavigationLink(destination: ConversationView()) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Start Conversation")
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    
                    Spacer()
                        .frame(height: 100)
                }
                
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
            }
            .navigationTitle("Conscious House")
            .navigationBarHidden(true)
            .background(
                Group {
                    NavigationLink(destination: NotesView(), isActive: $showNotesView) {
                        EmptyView()
                    }
                    NavigationLink(destination: VoiceSettingsView(), isActive: $showVoiceSettings) {
                        EmptyView()
                    }
                    NavigationLink(destination: VoiceTestView(), isActive: $showVoiceTest) {
                        EmptyView()
                    }
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle()) // For iPad compatibility
        .onAppear {
            checkLocationPermission()
            checkOnboardingStatus()
        }
        .errorOverlay($currentError) {
            Task { await viewModel.refreshWeather() }
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
            // Trigger loading address and weather, which will set appropriate house emotion
            await viewModel.loadAddressAndWeather()
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(ServiceContainer.shared)
}
