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
    @State private var showingCoaching = false
    @State private var showingMicroInterventions = false
    @State private var showingGoalSetting = false
    @State private var showingInsights = false
    @State private var animateResult = false
    
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
                    coachingPreviewSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Analysis Result")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateResult = true
            }
        }
        .navigationDestination(isPresented: $showingCoaching) {
            CoachingView()
        }
        .navigationDestination(isPresented: $showingMicroInterventions) {
            MicroInterventionsView()
        }
        .navigationDestination(isPresented: $showingGoalSetting) {
            GoalSettingView()
        }
        .navigationDestination(isPresented: $showingInsights) {
            InsightsView()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Analysis Complete")
                .font(.headline)
                .foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Your emotional state has been analyzed")
                .font(.subheadline)
                .foregroundColor(ThemeColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Main Result Section
    private var mainResultSection: some View {
        VStack(spacing: 24) {
            // Emotion Icon with Animation
            ZStack {
                Circle()
                    .fill(ThemeColors.accent.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateResult ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateResult)
                
                Text(emotionType.emoji)
                    .font(.system(size: 48, weight: .medium))
                    .scaleEffect(animateResult ? 1.0 : 0.5)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateResult)
            }
            
            // Emotion Name
            Text(emotionType.displayName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ThemeColors.accent)
                .opacity(animateResult ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.6).delay(0.4), value: animateResult)
            
            // Subtitle
            Text("Primary emotion detected")
                .font(.subheadline)
                .foregroundColor(ThemeColors.secondaryText)
                .opacity(animateResult ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.6).delay(0.5), value: animateResult)
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
                        .foregroundColor(ThemeColors.accent)
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(ThemeColors.secondaryText.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(ThemeColors.accent)
                            .frame(width: geometry.size.width * (animateResult ? confidence : 0), height: 8)
                            .cornerRadius(4)
                            .animation(.easeOut(duration: 1.0).delay(0.6), value: animateResult)
                    }
                }
                .frame(height: 8)
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
        )
        .opacity(animateResult ? 1.0 : 0.0)
        .animation(.easeIn(duration: 0.6).delay(0.7), value: animateResult)
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
                QuickActionButton(
                    title: "Get Coaching",
                    icon: "brain.head.profile",
                    color: .purple,
                    action: { showingCoaching = true }
                )
                
                QuickActionButton(
                    title: "Quick Relief",
                    icon: "heart.circle",
                    color: .blue,
                    action: { showingMicroInterventions = true }
                )
                
                QuickActionButton(
                    title: "Set Goal",
                    icon: "target",
                    color: .green,
                    action: { showingGoalSetting = true }
                )
                
                QuickActionButton(
                    title: "View Insights",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange,
                    action: { showingInsights = true }
                )
            }
        }
        .opacity(animateResult ? 1.0 : 0.0)
        .animation(.easeIn(duration: 0.6).delay(0.8), value: animateResult)
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
                    showingCoaching = true
                }
                .font(.subheadline)
                .foregroundColor(ThemeColors.accent)
            }
            
            VStack(spacing: 12) {
                CoachingPreviewCard(
                    title: getCoachingTitle(),
                    description: getCoachingDescription(),
                    icon: getCoachingIcon(),
                    color: ThemeColors.accent,
                    duration: "5 min"
                )
                
                CoachingPreviewCard(
                    title: "Breathing Exercise",
                    description: "Calm your mind with guided breathing",
                    icon: "lungs.fill",
                    color: .blue,
                    duration: "3 min"
                )
            }
            
            // Get Coaching Button
            Button(action: { showingCoaching = true }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text("Start Coaching Session")
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
        .animation(.easeIn(duration: 0.6).delay(0.9), value: animateResult)
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

// MARK: - Preview
struct EmotionResultView_Previews: PreviewProvider {
    static var previews: some View {
        EmotionResultView(
            emotionType: .joy,
            confidence: 0.85,
            timestamp: Date()
        )
        .environmentObject(ThemeManager())
    }
}

