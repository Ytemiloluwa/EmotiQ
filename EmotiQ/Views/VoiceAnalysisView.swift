//
//  VoiceAnalysisView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import SwiftUI
import AVFoundation

// MARK: - Voice Analysis View
struct VoiceAnalysisView: View {
    @StateObject private var viewModel = VoiceAnalysisViewModel()
    @EnvironmentObject private var emotionService: CoreMLEmotionService
    @EnvironmentObject private var subscriptionService: SubscriptionService
    // Navigation state is controlled by the ViewModel
    @State private var showingSubscriptionPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 30) {
                        headerSection
                        
                        // MARK: - Recording Interface
                        VoiceRecordingInterface(viewModel: viewModel)
                        
                        // MARK: - Usage Information
                        if !subscriptionService.hasActiveSubscription {
                            UsageLimitCard(
                                used: viewModel.dailyUsageCount,
                                limit: viewModel.dailyUsageLimit
                            )
                        }
                        
                        // MARK: - Recent Results
                        if let lastResult = emotionService.lastAnalysisResult {
                            RecentAnalysisSection(result: lastResult)
                        }
                        
                        // MARK: - Tips Section
                        RecordingTipsSection()
                        
                        Spacer(minLength: 100) // Tab bar spacing
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Voice Check")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $viewModel.showingAnalysisResult) {
                if let result = viewModel.analysisResult {
                    EmotionResultView(
                        emotionType: EmotionType(rawValue: result.primaryEmotion.rawValue) ?? .neutral,
                        confidence: result.confidence,
                        timestamp: result.timestamp
                    )
                }
            }
            .sheet(isPresented: $showingSubscriptionPaywall) {
                SubscriptionPaywallView()
            }
            .alert("Daily Limit Reached", isPresented: $viewModel.showingLimitAlert) {
                Button("Upgrade to Premium") {
                    showingSubscriptionPaywall = true
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text("You've reached your daily limit of \(viewModel.dailyUsageLimit) voice analyses. Upgrade to Premium for unlimited access.")
            }
            .alert("Analysis Error", isPresented: $viewModel.showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .onAppear {
            viewModel.checkDailyUsage()
        }

    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.purple.opacity(0.1), Color.cyan.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Voice Emotion Analysis")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Speak naturally for 2-120 seconds to analyze your emotional state")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }
}

// MARK: - Voice Recording Interface
struct VoiceRecordingInterface: View {
    @ObservedObject var viewModel: VoiceAnalysisViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Audio Level Visualization
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 200, height: 200)
                
                // Enhanced audio visualization
                CircularAudioLevelIndicator(
                    audioLevel: viewModel.getNormalizedAudioLevel(),
                    isRecording: viewModel.isRecording
                )
                
                // Recording button
                Button(action: {
                    Task {
                        if viewModel.isRecording {
                            await viewModel.stopRecording()
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.recordButtonColor)
                            .frame(width: 80, height: 80)
                        
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        } else {
                            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!viewModel.canStartRecording && !viewModel.isRecording)
                .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
            }
            
            // Recording status and timer
            VStack(spacing: 8) {
                Text(viewModel.recordButtonText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.recordButtonColor)
                
                if viewModel.isRecording {
                    Text(viewModel.recordingTimeText)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
                
                if viewModel.isProcessing {
                    Text("Analyzing your voice patterns...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Enhanced Bar Visualization
            if viewModel.isRecording {
                AudioLevelVisualization(
                    audioLevel: viewModel.getNormalizedAudioLevel(),
                    isRecording: viewModel.isRecording
                )
                .frame(height: 60)
                .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Usage Limit Card
struct UsageLimitCard: View {
    let used: Int
    let limit: Int
    
    private var progressPercentage: Double {
        guard limit > 0 else { return 0 }
        return min(Double(used) / Double(limit), 1.0)
    }
    
    private var statusColor: Color {
        if used >= limit {
            return .red
        } else if used >= limit - 1 {
            return .orange
        } else {
            return .purple
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Usage")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(used)/\(limit)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progressPercentage)
                }
            }
            .frame(height: 8)
            
            if used >= limit {
                Text("Upgrade to Premium for unlimited voice analyses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let remaining = limit - used
                Text("\(remaining) analysis remaining today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - Recent Analysis Section
struct RecentAnalysisSection: View {
    let result: EmotionAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                // Emotion icon
                ZStack {
                    Circle()
                        .fill(result.primaryEmotion.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Text(result.primaryEmotion.emoji)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.primaryEmotion.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(result.confidence * 100))% confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatRelativeTime(result.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Recording Tips Section
struct RecordingTipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recording Tips")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                TipRow(icon: "mic", text: "Speak naturally in a quiet environment")
                TipRow(icon: "timer", text: "Record for 2-120 seconds for best results")
                TipRow(icon: "speaker.wave.2", text: "Express your current feelings authentically")
                TipRow(icon: "lock.shield", text: "Your voice data is processed on your device")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - Tip Row
struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.purple)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct VoiceAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceAnalysisView()
            .environmentObject(CoreMLEmotionService.shared)
            .environmentObject(SubscriptionService.shared)
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let recordingCompleted = Notification.Name("recordingCompleted")
    static let emotionalDataSaved = Notification.Name("emotionalDataSaved")
}

