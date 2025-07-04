/*
 * CONTEXT & PURPOSE:
 * PermissionRequestView provides a user-friendly interface for requesting and managing microphone
 * and speech recognition permissions. It displays the current permission status and guides users
 * through the permission granting process with clear visual feedback and actionable buttons.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Clean, centered layout with clear messaging about why permissions are needed
 *   - Visual permission status cards with icons and color coding
 *   - Green checkmarks for granted, red X for denied permissions
 *   - Conditional action buttons based on permission state
 *   - "Grant Permissions" button when permissions needed
 *   - "Open Settings" button when permissions denied (manual grant required)
 *   - Success state with green checkmark when all permissions granted
 *   - PermissionStatusCard as reusable component for each permission
 *   - Shadow effects for depth and visual hierarchy
 *   - System background colors for automatic dark mode support
 *   - EnvironmentObject injection of PermissionManager
 *   - Task-based async permission requests
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  PermissionRequestView.swift
//  C11SHouse
//
//  Created on 2025-07-03
//  UI for requesting and managing voice-related permissions
//

import SwiftUI

struct PermissionRequestView: View {
    @EnvironmentObject var permissionManager: PermissionManager
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Voice Control Permissions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("C11S House needs access to your microphone and speech recognition to enable voice control for your smart home.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            
            // Permission Status Cards
            VStack(spacing: 16) {
                PermissionStatusCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    status: permissionManager.microphoneStatusDescription,
                    isGranted: permissionManager.isMicrophoneGranted
                )
                
                PermissionStatusCard(
                    icon: "waveform",
                    title: "Speech Recognition",
                    status: permissionManager.speechRecognitionStatusDescription,
                    isGranted: permissionManager.isSpeechRecognitionGranted
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                if !permissionManager.allPermissionsGranted {
                    Button(action: {
                        Task {
                            await permissionManager.requestAllPermissions()
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                            Text("Grant Permissions")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
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
                }
                
                if permissionManager.allPermissionsGranted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All permissions granted!")
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .edgesIgnoringSafeArea(.all)
    }
}

struct PermissionStatusCard: View {
    let icon: String
    let title: String
    let status: String
    let isGranted: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(isGranted ? .green : .red)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct PermissionRequestView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionRequestView()
            .environmentObject(PermissionManager.shared)
    }
}