import SwiftUI

struct ContentView: View {
    @Environment(\.serviceContainer) private var serviceContainer
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

// Simple UI components that might be referenced elsewhere
struct TranscriptionView: View {
    let transcription: String
    let isListening: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                    .foregroundColor(isListening ? .red : .gray)
                    .symbolEffect(.pulse, value: isListening)
                
                Text(isListening ? "Listening..." : "Transcription")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Text(transcription)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
        }
    }
}

struct VoiceRecordingButton: View {
    @Binding var isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(
                        isRecording ?
                            Animation.easeInOut(duration: 1.5).repeatForever() :
                            Animation.default,
                        value: isRecording
                    )
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
            }
        }
    }
}

// Permission Request View
struct PermissionRequestView: View {
    @Environment(\.serviceContainer) private var serviceContainer
    @State private var isCheckingPermissions = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "mic.slash.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("Permissions Required")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This app needs access to your microphone and speech recognition to transcribe your voice.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: requestPermissions) {
                if isCheckingPermissions {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Grant Permissions")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(width: 200, height: 50)
            .background(Color.blue)
            .cornerRadius(25)
            .disabled(isCheckingPermissions)
        }
    }
    
    private func requestPermissions() {
        isCheckingPermissions = true
        
        Task {
            _ = await serviceContainer.permissionManager.requestAllPermissions()
            
            await MainActor.run {
                isCheckingPermissions = false
            }
        }
    }
}

#Preview {
    ContentView()
        .withServiceContainer()
}