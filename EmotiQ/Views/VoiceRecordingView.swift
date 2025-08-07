//
//  VoiceRecordingView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 07-08-2025.
//

import SwiftUI
import Combine

struct VoiceRecordingView: View {
    @StateObject private var viewModel = VoiceRecordingViewModel()
    @Environment(\.dismiss) private var dismiss
    
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
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Voice Check-In")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Speak naturally for 5-30 seconds")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Recording Status
                    VStack(spacing: 16) {
                        // Duration Display
                        Text(formatDuration(viewModel.recordingDuration))
                            .font(.system(size: 48, weight: .light, design: .monospaced))
                            .foregroundColor(.white)
                        
                        // Quality Indicator
                        QualityIndicatorView(quality: viewModel.recordingQuality)
                    }
                    
                    // Audio Visualization
                    AudioVisualizationView(
                        audioLevel: viewModel.audioLevel,
                        isRecording: viewModel.isRecording
                    )
                    .frame(height: 120)
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Recording Controls
                    VStack(spacing: 20) {
                        // Main Record Button
                        Button(action: {
                            if viewModel.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.startRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.isRecording ? Color.red : Color.white)
                                    .frame(width: 80, height: 80)
                                    .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
                                
                                if viewModel.isRecording {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                } else {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color(hex: Config.UI.primaryPurple))
                                }
                            }
                        }
                        .disabled(viewModel.isLoading)
                        
                        // Secondary Actions
                        HStack(spacing: 40) {
                            // Cancel Button
                            Button(action: {
                                viewModel.cancelRecording()
                                dismiss()
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "xmark.circle")
                                        .font(.title2)
                                    Text("Cancel")
                                        .font(.caption)
                                }
                                .foregroundColor(.white.opacity(0.8))
                            }
                            .disabled(viewModel.isLoading)
                            
                            // Done Button (only show when recording is complete)
                            if viewModel.hasRecording {
                                Button(action: {
                                    viewModel.processRecording()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                        Text("Analyze")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                }
                                .disabled(viewModel.isLoading)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Recording Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Permission Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Settings") {
                viewModel.openSettings()
            }
            Button("Cancel") { }
        } message: {
            Text("EmotiQ needs microphone access to analyze your voice. Please enable it in Settings.")
        }
        .onAppear {
            viewModel.requestPermissionIfNeeded()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct QualityIndicatorView: View {
    let quality: VoiceQuality
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(qualityColor)
                .frame(width: 8, height: 8)
            
            Text(quality.displayName)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.2))
        )
    }
    
    private var qualityColor: Color {
        switch quality {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        }
    }
}

#Preview {
    VoiceRecordingView()
}


