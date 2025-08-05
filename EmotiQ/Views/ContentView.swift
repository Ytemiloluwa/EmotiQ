//
//  ContentView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 31-07-2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.4, green: 0.2, blue: 0.7),  // Darker Purple
                        Color(red: 0.2, green: 0.8, blue: 0.9)   // Cyan
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                        
                        Text("EmotiQ")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("AI Emotional Intelligence Coach")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Main Action Buttons
                    VStack(spacing: 20) {
                        Button(action: {
                            viewModel.startVoiceAnalysis()
                        }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("Start Voice Check-In")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(Color(red: 0.6, green: 0.3, blue: 0.9))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            viewModel.showInsights()
                        }) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                Text("View Emotional Insights")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Subscription Status
                    VStack(spacing: 8) {
                        Text(viewModel.subscriptionStatus.displayName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        if viewModel.subscriptionStatus == .free {
                            Text("Daily check-ins remaining: \(viewModel.dailyCheckInsRemaining)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadUserData()
        }
    }
}

#Preview {
    ContentView()
}


