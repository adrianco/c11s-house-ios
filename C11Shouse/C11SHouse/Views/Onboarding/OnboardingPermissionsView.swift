/*
 * CONTEXT & PURPOSE:
 * OnboardingPermissionsView implements Phase 2 of the onboarding UX plan. It handles
 * permission requests with clear explanations and progressive disclosure, ensuring
 * users understand why each permission is needed.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation based on OnboardingUXPlan.md
 *   - Clear visual permission cards
 *   - Progressive permission requests
 *   - Recovery options for denied permissions
 *   - Skip option for non-essential permissions
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI

struct OnboardingPermissionsView: View {
    @ObservedObject var permissionManager: PermissionManager
    @EnvironmentObject private var serviceContainer: ServiceContainer
    let onContinue: () -> Void
    
    @State private var isRequestingPermissions = false
    @State private var showLocationExplanation = false
    @State private var hasRequestedPermissions = false
    
    private var canContinue: Bool {
        // Microphone and speech are required, location is optional
        return permissionManager.isMicrophoneGranted &&
               permissionManager.isSpeechRecognitionGranted
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(uiImage: AppIconCreatorLegacy.createIcon(size: CGSize(width: 80, height: 80)))
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    .padding(.top, 40)
                
                Text("Quick Setup")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("We need a few permissions to make your house truly conscious")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
            
            // Permission Cards
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "To hear your voice commands",
                    status: permissionManager.isMicrophoneGranted ? .granted : 
                            (permissionManager.microphonePermissionStatus == .denied ? .denied : .notDetermined),
                    isRequired: true
                )
                
                PermissionCard(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "To understand your requests",
                    status: permissionManager.isSpeechRecognitionGranted ? .granted : 
                            (permissionManager.speechRecognitionPermissionStatus == .denied ? .denied : .notDetermined),
                    isRequired: true
                )
                
                PermissionCard(
                    icon: "location.fill",
                    title: "Location",
                    description: "To provide local weather and context",
                    status: permissionManager.hasLocationPermission ? .granted : 
                            (permissionManager.locationPermissionStatus == .denied || permissionManager.locationPermissionStatus == .restricted ? .denied : .notDetermined),
                    isRequired: false
                ) {
                    showLocationExplanation = true
                }
                
                PermissionCard(
                    icon: "homekit",
                    title: "HomeKit",
                    description: "To find existing named rooms and devices",
                    status: permissionManager.isHomeKitGranted ? .granted :
                            (permissionManager.homeKitPermissionStatus == .restricted ? .denied : .notDetermined),
                    isRequired: false
                )
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 16) {
                if !hasRequestedPermissions {
                    Button(action: requestPermissions) {
                        HStack {
                            if isRequestingPermissions {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.shield.fill")
                            }
                            Text("Grant Permissions")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .disabled(isRequestingPermissions)
                    }
                    
                    if permissionManager.permissionError != nil {
                        Button(action: {
                            permissionManager.openAppSettings()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                } else {
                    // Show Next button after permissions have been requested
                    Button(action: onContinue) {
                        HStack {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "007AFF"), Color(hex: "5856D6")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .disabled(!canContinue) // Disable if required permissions not granted
                }
                
                // Skip location permission if not granted
                if !permissionManager.hasLocationPermission && canContinue {
                    Button(action: onContinue) {
                        Text("Skip Location Setup")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
        .sheet(isPresented: $showLocationExplanation) {
            LocationExplanationSheet()
        }
    }
    
    private func requestPermissions() {
        isRequestingPermissions = true
        
        Task {
            // Initialize services that require permissions - this triggers permission popups
            
            // 1. Audio Recorder Service (triggers microphone permission)
            _ = serviceContainer.audioRecorder
            await permissionManager.requestMicrophonePermission()
            
            // 2. Transcription Service (triggers speech recognition permission)
            await MainActor.run {
                _ = serviceContainer.transcriptionService
            }
            await permissionManager.requestSpeechRecognitionPermission()
            
            // 3. Location Service (optional)
            if !permissionManager.hasLocationPermission {
                _ = serviceContainer.locationService
                await permissionManager.requestLocationPermission()
            }
            
            // 4. HomeKit Service (optional)
            if !permissionManager.isHomeKitGranted {
                await MainActor.run {
                    _ = serviceContainer.homeKitService
                }
                await permissionManager.requestHomeKitPermission()
            }
            
            // Background address lookup if location permission granted
            if permissionManager.hasLocationPermission {
                let addressManager = serviceContainer.addressManager
                Task.detached(priority: .background) {
                    do {
                        let startTime = Date()
                        // Use the captured address manager
                        let address = try await addressManager.detectCurrentAddress()
                        
                        // Store detected address for later confirmation in conversation
                        await addressManager.storeDetectedAddress(address)
                        
                        let duration = Date().timeIntervalSince(startTime)
                        OnboardingLogger.shared.logServiceCall("address_detection", phase: "permissions", success: true, duration: duration)
                        OnboardingLogger.shared.logFeatureUsage("auto_address_detection", phase: "permissions", details: [
                            "address": address
                        ])
                    } catch {
                        print("Background address detection failed: \(error)")
                        OnboardingLogger.shared.logServiceCall("address_detection", phase: "permissions", success: false)
                        OnboardingLogger.shared.logError(error, phase: "permissions", recovery: "User will need to enter address manually")
                    }
                }
            }
            
            await MainActor.run {
                isRequestingPermissions = false
                hasRequestedPermissions = true
            }
        }
    }
}

// MARK: - Permission Card

// Define PermissionStatus at file level
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

struct PermissionCard: View {
    
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let isRequired: Bool
    var onTap: (() -> Void)? = nil
    
    private var statusIcon: String {
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "circle"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .gray
        }
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(status == .granted ? .green : .blue)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(status == .granted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    )
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isRequired {
                            Text("Required")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(onTap == nil)
    }
}

// MARK: - Location Explanation

struct LocationExplanationSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                Text("Why Location Access?")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    ExplanationRow(
                        icon: "cloud.sun.fill",
                        text: "Get accurate local weather for your home"
                    )
                    
                    ExplanationRow(
                        icon: "house.fill",
                        text: "Automatically detect your home address"
                    )
                    
                    ExplanationRow(
                        icon: "lock.shield.fill",
                        text: "Location data never leaves your device"
                    )
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                Text("You can always add your address manually if you prefer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct ExplanationRow: View {
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
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct OnboardingPermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingPermissionsView(
            permissionManager: PermissionManager.shared,
            onContinue: {}
        )
    }
}