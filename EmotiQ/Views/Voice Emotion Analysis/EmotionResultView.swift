//
//  EmotionResultView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import SwiftUI

struct EmotionResultView: View {
    let emotionType: EmotionType
    let confidence: Double
    let timestamp: Date
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticManager
    @StateObject private var elevenLabsViewModel = ElevenLabsViewModel()
    @State private var showingCoaching = false
    @State private var showingMicroInterventions = false
    @State private var showingGoalSetting = false
    @State private var showingInsights = false
    @State private var showingAllEmotionalPrompts = false
    @State private var showingVoiceCloningSetup = false
    @State private var showingAffirmations = false
    @State private var showingVoiceGuidedIntervention = false
    @State private var animateResult = false
    @State private var pulseEmotionIcon = false
    @State private var confidenceAnimationProgress: Double = 0
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            ThemeColors.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                    
                    // Main Result
                    mainResultSection
                    
                    // Confidence & Details
                    detailsSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Coaching Preview
                    //coachingPreviewSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Analysis Result")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    hapticManager.selection()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ThemeColors.accent)
                }
            }
        }
        .onAppear {
            startAnimationSequence()
        }
        .navigationDestination(isPresented: $showingCoaching) {
            FeatureGateView(feature: .personalizedCoaching) {
                CoachingView()
            }
        }
        .navigationDestination(isPresented: $showingMicroInterventions) {
            FeatureGateView(feature: .personalizedCoaching) {
                MicroInterventionsView()
            }
        }
        .navigationDestination(isPresented: $showingGoalSetting) {
            FeatureGateView(feature: .goalSetting) {
                GoalSettingView()
            }
        }
        .navigationDestination(isPresented: $showingInsights) {
            FeatureGateView(feature: .advancedAnalytics) {
                InsightsView(showBackButton: true)
            }
        }
        .navigationDestination(isPresented: $showingAllEmotionalPrompts) {
            FeatureGateView(feature: .personalizedCoaching) {
                AllEmotionalPromptsView(viewModel: MicroInterventionsViewModel.shared)
            }
        }
        .navigationDestination(isPresented: $showingVoiceCloningSetup) {
            FeatureGateView(feature: .voiceCloning) {
                VoiceCloningSetupView()
            }
        }
        .navigationDestination(isPresented: $showingAffirmations) {
            FeatureGateView(feature: .voiceAffirmations) {
                AffirmationsView()
            }
        }
        .navigationDestination(isPresented: $showingVoiceGuidedIntervention) {
            FeatureGateView(feature: .personalizedCoaching) {
                VoiceGuidedInterventionView(intervention: nil)
            }
        }
    }
    
    // MARK: - Animation Control
    private func startAnimationSequence() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateResult = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            pulseEmotionIcon = true
            hapticManager.emotionalFeedback(for: emotionType)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            confidenceAnimationProgress = confidence
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Analysis Complete")
                .font(.headline)
                .foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.center)
                .opacity(animateResult ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.6).delay(0.2), value: animateResult)
            
            Text("Your emotional state has been analyzed")
                .font(.subheadline)
                .foregroundColor(ThemeColors.secondaryText)
                .multilineTextAlignment(.center)
                .opacity(animateResult ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.6).delay(0.4), value: animateResult)
        }
    }
    
    // MARK: - Main Result Section
    private var mainResultSection: some View {
        VStack(spacing: 24) {
            // Emotion Icon with Enhanced Animation
            ZStack {
                // Outer pulse rings
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(emotionColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 140 + CGFloat(index * 20), height: 140 + CGFloat(index * 20))
                        .scaleEffect(pulseEmotionIcon ? 1.2 : 1.0)
                        .opacity(pulseEmotionIcon ? 0.0 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                            value: pulseEmotionIcon
                        )
                }
                
                // Main emotion circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [emotionColor.opacity(0.3), emotionColor.opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateResult ? 1.0 : 0.6)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateResult)
                
                // Emotion emoji with bounce
                Text(emotionType.emoji)
                    .font(.system(size: 56, weight: .medium))
                    .scaleEffect(animateResult ? 1.0 : 0.3)
                    .rotationEffect(.degrees(animateResult ? 0 : -180))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3), value: animateResult)
            }
            
            // Emotion Name
            Text(emotionType.displayName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(emotionColor)
                .opacity(animateResult ? 1.0 : 0.0)
                .scaleEffect(animateResult ? 1.0 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateResult)
            
            // Subtitle
            Text("Primary emotion detected")
                .font(.subheadline)
                .foregroundColor(ThemeColors.secondaryText)
                .opacity(animateResult ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.6).delay(0.7), value: animateResult)
        }
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(spacing: 16) {
            // Confidence Score
            VStack(spacing: 8) {
                HStack {
                    Text("Confidence")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Spacer()
                    
                    Text("\(Int(confidence * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(emotionColor)
                }
                
                // Enhanced Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ThemeColors.secondaryText.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [emotionColor, emotionColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * confidenceAnimationProgress, height: 12)
                            .animation(.easeOut(duration: 1.5).delay(0.8), value: confidenceAnimationProgress)
                        
                        // Shimmer effect
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 50, height: 12)
                            .offset(x: animateResult ? geometry.size.width : -50)
                            .animation(.linear(duration: 2.0).repeatForever(autoreverses: false).delay(1.0), value: animateResult)
                    }
                }
                .frame(height: 12)
            }
            
            // Timestamp
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(ThemeColors.secondaryText)
                    .font(.caption)
                
                Text("Analyzed \(timestamp, formatter: timeFormatter)")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ThemeColors.secondaryBackground)
                .shadow(color: emotionColor.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .opacity(animateResult ? 1.0 : 0.0)
        .offset(y: animateResult ? 0 : 30)
        .animation(.easeOut(duration: 0.8).delay(0.9), value: animateResult)
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                EmotionActionButton(
                    title: "Voice Affirmation",
                    icon: elevenLabsViewModel.isVoiceCloned ? "waveform.circle.fill" : "waveform.circle",
                    color: .purple,
                    action: {
                        hapticManager.buttonPress(.primary)
                        if elevenLabsViewModel.isVoiceCloned {
                            showingAffirmations = true
                        } else {
                            showingVoiceCloningSetup = true
                        }
                    }
                )
                
                Button(action: {
        
                     hapticManager.buttonPress(.primary)
                     showingAllEmotionalPrompts = true
                 }) {
                     VStack(spacing: 12) {
                         Image(systemName: "heart.circle")
                             .font(.title2)
                             .foregroundColor(.green)
                             .frame(width: 32, height: 32)
                         
                         VStack(spacing: 4) {
                             Text("Emotional Prompts")
                                 .font(.subheadline)
                                 .fontWeight(.semibold)
                                 .foregroundColor(ThemeColors.primaryText)
                         }
                     }
                     .frame(maxWidth: .infinity)
                     .padding(.vertical, 20)
                     .padding(.horizontal, 16)
                     .background(
                         RoundedRectangle(cornerRadius: 16)
                             .fill(Color.green.opacity(themeManager.isDarkMode ? 0.15 : 0.08))
                             .overlay(
                                 RoundedRectangle(cornerRadius: 16)
                                     .stroke(Color.green.opacity(0.2), lineWidth: 1)
                             )
                     )
                 }
                 .buttonStyle(PlainButtonStyle())
                
                EmotionActionButton(
                    title: "Set Goal",
                    icon: "target",
                    color: .blue,
                    action: {
                        hapticManager.buttonPress(.primary)
                        showingGoalSetting = true
                    }
                )
                
                EmotionActionButton(
                    title: "View Insights",
                    icon: "chart.bar.fill",
                    color: .orange,
                    action: {
                        hapticManager.buttonPress(.primary)
                        showingInsights = true
                    }
                )
            }
        }
        .opacity(animateResult ? 1.0 : 0.0)
        .offset(y: animateResult ? 0 : 50)
        .animation(.easeIn(duration: 0.6).delay(1.1), value: animateResult)
    }
    
    // MARK: - Coaching Preview Section
    private var coachingPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Personalized Coaching")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Button("View All") {
                    hapticManager.buttonPress(.primary)
                    showingCoaching = true
                }
                .font(.subheadline)
                .foregroundColor(ThemeColors.accent)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    hapticManager.buttonPress(.standard)
                    showingCoaching = true
                }) {
                    CoachingPreviewCard(
                        title: getCoachingTitle(),
                        description: getCoachingDescription(),
                        icon: getCoachingIcon(),
                        color: ThemeColors.accent,
                        duration: "5 min"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    hapticManager.buttonPress(.standard)
                    showingMicroInterventions = true
                }) {
                    CoachingPreviewCard(
                        title: "Breathing Exercise",
                        description: "Calm your mind with guided breathing",
                        icon: "lungs.fill",
                        color: .blue,
                        duration: "3 min"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Get Coaching Button
            Button(action: {
                hapticManager.buttonPress(.primary)
                showingVoiceGuidedIntervention = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker")
                    Spacer()
                    Text("Voice Guided Intervention")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [ThemeColors.accent, ThemeColors.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .opacity(animateResult ? 1.0 : 0.0)
        .offset(y: animateResult ? 0 : 30)
        .animation(.easeIn(duration: 0.6).delay(1.3), value: animateResult)
    }
    
    // MARK: - Helper Properties
    private var emotionColor: Color {
        Color(hex: emotionType.hexColor)
    }
    
    // MARK: - Helper Methods
    func getCoachingTitle() -> String {
        switch emotionType {
        case .joy: return "Amplify Your Joy"
        case .sadness: return "Gentle Self-Compassion"
        case .anger: return "Channel Your Energy"
        case .fear: return "Build Inner Courage"
        case .surprise: return "Embrace the Unexpected"
        case .disgust: return "Process and Release"
        case .neutral: return "Deepen Self-Awareness"
        }
    }
    
    func getCoachingDescription() -> String {
        switch emotionType {
        case .joy: return "Learn to sustain and share positive emotions"
        case .sadness: return "Practice self-care and emotional healing"
        case .anger: return "Transform anger into productive action"
        case .fear: return "Develop confidence and resilience"
        case .surprise: return "Navigate change with curiosity"
        case .disgust: return "Understand and process difficult feelings"
        case .neutral: return "Explore your emotional landscape"
        }
    }
    
    private func getCoachingIcon() -> String {
        switch emotionType {
        case .joy: return "sun.max.fill"
        case .sadness: return "heart.fill"
        case .anger: return "flame.fill"
        case .fear: return "shield.fill"
        case .surprise: return "sparkles"
        case .disgust: return "leaf.fill"
        case .neutral: return "circle.dotted"
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Coaching Preview Card
struct CoachingPreviewCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let duration: String
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(duration)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .cornerRadius(8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColors.secondaryBackground)
        )
    }
}

// MARK: - Quick Action Button
struct EmotionActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
            }
        }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(themeManager.isDarkMode ? 0.15 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: color.opacity(0.2), radius: isPressed ? 2 : 8, x: 0, y: isPressed ? 1 : 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct EmotionResultView_Previews: PreviewProvider {
    static var previews: some View {
        EmotionResultView(
            emotionType: .fear,
            confidence: 0.85,
            timestamp: Date()
        )
        .environmentObject(ThemeManager())
        .environmentObject(HapticManager.shared)
    }
}

