//
//  ContentView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 31-07-2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var showVoiceRecording = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hex: Config.UI.primaryPurple),
                        Color(hex: Config.UI.primaryCyan)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 16) {
                        // App Logo/Icon
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("EmotiQ")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("AI Emotional Intelligence Coach")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Main Content
                    VStack(spacing: 24) {
                        // Daily Usage Status
                        if viewModel.subscriptionStatus == .free {
                            VStack(spacing: 8) {
                                Text("Daily Check-ins Remaining")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("\(viewModel.dailyUsageRemaining)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.2))
                            )
                        }
                        
                        // Primary Action Button
                        Button(action: {
                            if viewModel.canPerformVoiceAnalysis {
                                showVoiceRecording = true
                            } else {
                                viewModel.showUpgradePrompt = true
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mic.fill")
                                    .font(.title2)
                                
                                Text("Start Voice Check-In")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(Color(hex: Config.UI.primaryPurple))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                        }
                        .disabled(viewModel.isLoading)
                        
                        // Secondary Action Button
                        Button(action: {
                            // TODO: Navigate to insights view
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title2)
                                
                                Text("View Emotional Insights")
                                    .font(.headline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Subscription Status
                    VStack(spacing: 8) {
                        Text("Current Plan: \(viewModel.subscriptionStatus.displayName)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        if viewModel.subscriptionStatus == .free {
                            Button("Upgrade to Premium") {
                                viewModel.showUpgradePrompt = true
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .underline()
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showVoiceRecording) {
            VoiceRecordingView()
        }
        .alert("Upgrade Required", isPresented: $viewModel.showUpgradePrompt) {
            Button("Upgrade Now") {
                // TODO: Show subscription paywall
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You've reached your daily limit of \(Config.Subscription.freeDailyLimit) voice check-ins. Upgrade to Premium for unlimited access.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.loadInitialData()
        }
    }
}

#Preview {
    ContentView()
}


