//
//  ErrorView.swift
//  c11s-house-ios
//
//  Created by Claude on 2025-07-15.
//

import SwiftUI

/// A reusable view for displaying errors with consistent styling
struct ErrorView: View {
    let error: UserFriendlyError
    let onDismiss: (() -> Void)?
    let onRetry: (() -> Void)?
    
    @State private var isExpanded = false
    @State private var shouldDismiss = false
    
    init(error: UserFriendlyError, onDismiss: (() -> Void)? = nil, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: error.severity.iconSystemName)
                    .font(.title2)
                    .foregroundColor(Color(error.severity.tintColor))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.userFriendlyTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error.userFriendlyMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if onDismiss != nil {
                    Button(action: { onDismiss?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Expandable recovery suggestions
            if !error.recoverySuggestions.isEmpty {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        Text("Recovery Suggestions")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(error.recoverySuggestions.enumerated()), id: \.offset) { index, suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.leading, 20)
                    .transition(.opacity)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if let errorCode = error.errorCode {
                    Text("Error Code: \(errorCode)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                if let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(backgroundView)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            if error.shouldAutoDismiss {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        shouldDismiss = true
                        onDismiss?()
                    }
                }
            }
        }
        .opacity(shouldDismiss ? 0 : 1)
        .scaleEffect(shouldDismiss ? 0.8 : 1)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch error.severity {
        case .info:
            Color.blue.opacity(0.1)
        case .warning:
            Color.orange.opacity(0.1)
        case .error, .critical:
            Color.red.opacity(0.1)
        }
    }
}

/// A view modifier for displaying errors as overlays
struct ErrorOverlay: ViewModifier {
    @Binding var error: UserFriendlyError?
    let onRetry: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let error = error {
                VStack {
                    Spacer()
                    
                    ErrorView(
                        error: error,
                        onDismiss: { self.error = nil },
                        onRetry: onRetry
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: error.errorCode)
            }
        }
    }
}

/// Extension to make it easy to add error overlays
extension View {
    func errorOverlay(_ error: Binding<UserFriendlyError?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorOverlay(error: error, onRetry: onRetry))
    }
}

/// A full-screen error view for critical errors
struct FullScreenErrorView: View {
    let error: UserFriendlyError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: error.severity.iconSystemName)
                .font(.system(size: 60))
                .foregroundColor(Color(error.severity.tintColor))
            
            VStack(spacing: 12) {
                Text(error.userFriendlyTitle)
                    .font(.title)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(error.userFriendlyMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if !error.recoverySuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What you can try:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(error.recoverySuggestions.enumerated()), id: \.offset) { index, suggestion in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .font(.body)
                                    .foregroundColor(.accentColor)
                                
                                Text(suggestion)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        Text("Try Again")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                if let errorCode = error.errorCode {
                    Text("Error Code: \(errorCode)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// Preview helpers
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ErrorView(
                error: AppError.networkUnavailable,
                onDismiss: {},
                onRetry: {}
            )
            
            ErrorView(
                error: AppError.locationAccessDenied,
                onDismiss: {}
            )
            
            ErrorView(
                error: AppError.voiceRecognitionFailed,
                onRetry: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}