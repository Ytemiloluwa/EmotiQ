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
    @EnvironmentObject private var emotionService: CoreMLEmotionService
    
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
                        
                        Text("Speak naturally for 2-120 seconds")
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
                            
                            // Analyze Button (only show when recording is complete)
                            if viewModel.hasRecording {
                                Button(action: {
                                    viewModel.processRecording()
                                }) {
                                    VStack(spacing: 4) {
                                        if viewModel.isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "brain.head.profile")
                                                .font(.title2)
                                        }
                                        Text(viewModel.isLoading ? "Analyzing..." : "Analyze")
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
            .overlay(
                // Analysis Loading Overlay
                Group {
                    if viewModel.isLoading {
                        ZStack {
                            Color.black.opacity(0.7)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                
                                VStack(spacing: 8) {
                                    Text("Analyzing Your Voice")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    Text("Processing audio features and detecting emotions...")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
            )
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
        .onReceive(NotificationCenter.default.publisher(for: .recordingCompleted)) { _ in
            dismiss()
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

struct AudioVisualizationView: View {
    let audioLevel: Float
    let isRecording: Bool
    
    private let barCount = 20
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4)
                    .frame(height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 80
        
        if !isRecording {
            return baseHeight
        }
        
        // Create a wave pattern based on audio level
        let normalizedIndex = Float(index) / Float(barCount - 1)
        let waveOffset = sin(normalizedIndex * .pi * 2) * 0.3
        let adjustedLevel = max(0, audioLevel + waveOffset)
        
        return baseHeight + (maxHeight - baseHeight) * CGFloat(adjustedLevel)
    }
    
    private func barColor(for index: Int) -> Color {
        let normalizedIndex = Float(index) / Float(barCount - 1)
        let threshold = audioLevel * 0.8
        
        if normalizedIndex <= threshold {
            return .white
        } else {
            return .white.opacity(0.3)
        }
    }
}


#Preview {
    VoiceRecordingView()
}

