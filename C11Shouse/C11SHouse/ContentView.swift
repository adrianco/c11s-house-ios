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
                    
                    NavigationLink(destination: HybridVoiceTranscriptionView()) {
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
                    
                    // Debug buttons for testing
                    VStack(spacing: 8) {
                        NavigationLink(destination: SimpleSpeechTestView()) {
                            HStack {
                                Image(systemName: "waveform")
                                Text("File-Based Test (Works)")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                        }
                        
                        NavigationLink(destination: FixedSpeechTestView()) {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                Text("Fixed Real-Time Test")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        
                        NavigationLink(destination: VoiceTranscriptionView()) {
                            HStack {
                                Image(systemName: "waveform.badge.exclamationmark")
                                Text("Original (Error 1101)")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                        }
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