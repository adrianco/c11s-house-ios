import SwiftUI

struct VoiceRecordingButton: View {
    @Binding var isRecording: Bool
    let action: () -> Void
    
    @State private var animationScale: CGFloat = 1.0
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.5
    
    private let buttonSize: CGFloat = 80
    private let rippleSize: CGFloat = 120
    
    var body: some View {
        ZStack {
            // Ripple effect when recording
            if isRecording {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 2)
                    .frame(width: rippleSize * rippleScale, height: rippleSize * rippleScale)
                    .opacity(rippleOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            rippleScale = 1.5
                            rippleOpacity = 0
                        }
                    }
                    .onDisappear {
                        rippleScale = 1.0
                        rippleOpacity = 0.5
                    }
            }
            
            // Main button
            Button(action: action) {
                ZStack {
                    // Background circle
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: isRecording ? Color.red.opacity(0.4) : Color.blue.opacity(0.4), 
                                radius: isRecording ? 20 : 10, x: 0, y: 5)
                    
                    // Icon
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: isRecording ? 28 : 32))
                        .foregroundColor(.white)
                        .scaleEffect(animationScale)
                }
            }
            .scaleEffect(isRecording ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
            
            // Recording indicator pulse
            if isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .offset(x: 35, y: -35)
                    .opacity(animationScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            animationScale = 0.3
                        }
                    }
                    .onDisappear {
                        animationScale = 1.0
                    }
            }
        }
        .frame(width: rippleSize, height: rippleSize)
    }
}

// Preview for development
struct VoiceRecordingButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 50) {
            // Not recording state
            VoiceRecordingButton(isRecording: Binding.constant(false)) {
                print("Start recording")
            }
            
            // Recording state
            VoiceRecordingButton(isRecording: Binding.constant(true)) {
                print("Stop recording")
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}