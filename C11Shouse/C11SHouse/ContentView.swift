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
                    
                    Text("C11S House")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Voice-based House Consciousness")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // Main content area with navigation to voice transcription
                VStack(spacing: 20) {
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
                    
                    Text("Tap to access voice controls")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    NavigationLink(destination: VoiceTranscriptionView()) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Start Voice Transcription")
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
                    
                    // Debug button for testing
                    NavigationLink(destination: SimpleSpeechTestView()) {
                        HStack {
                            Image(systemName: "waveform")
                            Text("Test Speech Recognition")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                    }
                    .padding(.top, 10)
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