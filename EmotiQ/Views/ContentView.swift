//
//  ContentView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 31-07-2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var showingOnboarding = false
    @State private var isAuthenticated = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
                    .environmentObject(subscriptionService)
                    // Defer heavy services until after authentication
                    .environmentObject(CoreMLEmotionService.shared)
                    .environmentObject(VoiceRecordingService())
                    .environmentObject(HapticManager.shared)
                    .environmentObject(ElevenLabsService.shared)
            } else {
                AuthenticationView(isAuthenticated: $isAuthenticated)
            }
        }
        .onAppear {
            checkAuthenticationStatus()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
    }
    
    private func checkAuthenticationStatus() {
        let securityManager = SecurityManager.shared
        let faceIDEnabled = securityManager.isFaceIDEnabled()
        
        if faceIDEnabled {
            authenticateWithBiometrics()
        } else {
            isAuthenticated = true
        }
    }
    
    private func authenticateWithBiometrics() {
        Task { @MainActor in
            let securityManager = SecurityManager.shared
            do {
                let success = try await securityManager.authenticateWithBiometrics(
                    reason: "Authenticate to access EmotiQ"
                )
                isAuthenticated = success
            } catch {
                // Stay on auth screen if cancelled/failed
                isAuthenticated = false
            }
        }
    }
}

// MARK: - Authentication View
struct AuthenticationView: View {
    @Binding var isAuthenticated: Bool
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: Config.UI.primaryPurple),
                    Color(hex: Config.UI.primaryCyan)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // App logo/icon
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    Text("EmotiQ")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Emotional Intelligence Coach")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Button(action: authenticateUser) {
                    HStack {
                        Image(systemName: "faceid")
                        Text("Authenticate with Face ID")
                    }
                    .font(.headline)
                    .foregroundColor(Color(hex: Config.UI.primaryPurple))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                
//                Button("Skip Authentication") {
//                    isAuthenticated = true
//                }
//                .font(.subheadline)
//                .foregroundColor(.white.opacity(0.8))
            }
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func authenticateUser() {
        Task { @MainActor in
            do {
                let success = try await SecurityManager.shared.authenticateWithBiometrics(
                    reason: "Authenticate to access EmotiQ"
                )
                if success { isAuthenticated = true }
            } catch let error as SecurityError {
                switch error {
                case .userCancelled:
                    break
                default:
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Welcome to EmotiQ")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your AI-powered emotional intelligence coach")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Get Started") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: Config.UI.primaryPurple),
                        Color(hex: Config.UI.primaryCyan)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
        .padding()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
