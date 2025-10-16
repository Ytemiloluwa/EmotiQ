//
//  CoachingView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import SwiftUI

struct CoachingView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var coachingService = CoachingService.shared
    @StateObject private var elevenLabsViewModel = ElevenLabsViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    
    // Navigation state variables
    @State private var showingGoalSetting = false
    @State private var showingMicroInterventions = false
    @State private var showingInsights = false
    @State private var showingAffirmations = false
    @State private var showingVoiceCloningSetup = false
    @State private var showingVoiceGuidedIntervention = false
    @State private var showingCustomAffirmationCreator = false
    @State private var showingAffirmationDetail = false
    @State private var showingAllAffirmations = false
    
    // Data for navigation
    @State private var selectedAffirmation: PersonalizedAffirmation?
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeColors.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        CoachingHeaderView()
                        
                        // Quick Actions
                        QuickActionsSection(
                            hasVoiceProfile: elevenLabsViewModel.isVoiceCloned,
                            onGoalSetting: { showingGoalSetting = true },
                            onMicroInterventions: { showingMicroInterventions = true },
                            onInsights: { showingInsights = true },
                            onVoiceGuidedIntervention: { //intervention in
                                // Navigate to the selection view instead of a specific intervention
                                showingVoiceGuidedIntervention = true
                            },
                            onVoiceCloningSetup: { showingVoiceCloningSetup = true },
                            onShowAffirmations: { showingAffirmations = true }
                        )
                        
                        // Daily Affirmations Section
                        DailyAffirmationsSection(
                            onViewAll: { showingAllAffirmations = true },
                            onAffirmationDetail: { affirmation in
                                selectedAffirmation = affirmation
                                showingAffirmationDetail = true
                            },
                            onCustomAffirmationCreator: { showingCustomAffirmationCreator = true }
                        )
                        
                        // Recommendations
                 /*       RecommendationsSection(
                            onVoiceGuidedIntervention: { //intervention in
                                // Navigate to the selection view instead of a specific intervention
                                showingVoiceGuidedIntervention = true
                            }
                      )  */
                        
                        // Progress Overview
                        //CoachingProgressOverviewSection()
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Coaching")
            .navigationBarTitleDisplayMode(.automatic)
            
            // Navigation destinations
            .navigationDestination(isPresented: $showingGoalSetting) {
                GoalSettingView()
            }
            .navigationDestination(isPresented: $showingMicroInterventions) {
                MicroInterventionsView()
            }
            .navigationDestination(isPresented: $showingAffirmations) {
                AffirmationsView()
            }
            .navigationDestination(isPresented: $showingVoiceCloningSetup) {
                VoiceCloningSetupView()
            }
            .navigationDestination(isPresented: $showingVoiceGuidedIntervention) {
                VoiceGuidedInterventionView(intervention: nil)
            }
            .navigationDestination(isPresented: $showingCustomAffirmationCreator) {
                CustomAffirmationCreatorView()
            }
            .navigationDestination(isPresented: $showingAffirmationDetail) {
                if let affirmation = selectedAffirmation {
                    AffirmationDetailView(affirmation: affirmation)
                }
            }
            .navigationDestination(isPresented: $showingAllAffirmations) {
                AllAffirmationsView()
            }
            
            .onAppear {
                // Refresh voice profile status to ensure UI is up to date
                Task {
                    elevenLabsViewModel.loadVoiceProfile()
                }
            }
        }
    }
}

// MARK: - Coaching Header View
struct CoachingHeaderView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Emotional Coach")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Personalized guidance for emotional growth")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ThemeColors.accent)
            }
        }
        .padding()
        .themedCard()
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    let hasVoiceProfile: Bool
    let onGoalSetting: () -> Void
    let onMicroInterventions: () -> Void
    let onInsights: () -> Void
    let onVoiceGuidedIntervention: () -> Void
    let onVoiceCloningSetup: () -> Void
    let onShowAffirmations: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                // Enhanced Personal Coaching with Voice Integration
                VoiceQuickActionCard(
                    title: "Voice Affirmations",
                    description: hasVoiceProfile ? "Listen to Affirmations in your voice" : "Set up your voice for emotional impact",
                    icon: hasVoiceProfile ? "waveform.circle.fill" : "waveform.circle",
                    color: .purple,
                    hasVoiceFeature: true,
                    isVoiceEnabled: hasVoiceProfile,
                    action: {
                        hapticManager.impact(.medium)
                        if hasVoiceProfile {
                            onShowAffirmations()
                        } else {
                            onVoiceCloningSetup()
                        }
                    }
                )
                
                QuickActionCard(
                    title: "Set Goals",
                    description: "Create emotional growth objectives",
                    icon: "target",
                    color: .blue,
                    action: {
                        hapticManager.impact(.light)
                        onGoalSetting()
                    }
                )
                
                // Enhanced Quick Relief - Always Voice Guided (Premium+ users only)
                VoiceQuickActionCard(
                    title: "Quick Relief",
                    description: "Your Voice guided Quick Relief",
                    icon: "lungs.fill",
                    color: .orange,
                    hasVoiceFeature: true,
                    isVoiceEnabled: hasVoiceProfile,
                    action: {
                        hapticManager.impact(.light)
                        onVoiceGuidedIntervention()
                    }
                )
                
                QuickActionCard(
                    title: "Micro Interventions",
                    description: "Quick emotional Micro interventions",
                    icon: "heart.circle.fill",
                    color: .green,
                    action: {
                        hapticManager.impact(.light)
                        onMicroInterventions()
                    }
                )
            }
        }
    }
}

// MARK: - Daily Affirmations Section
struct DailyAffirmationsSection: View {
    let onViewAll: () -> Void
    let onAffirmationDetail: (PersonalizedAffirmation) -> Void
    let onCustomAffirmationCreator: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticManager
    @StateObject private var affirmationEngine = AffirmationEngine.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Affirmations")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Button("View All") {
                    hapticManager.impact(.light)
                    onViewAll()
                }
                .font(.subheadline)
                .foregroundColor(ThemeColors.accent)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(affirmationEngine.dailyAffirmations.prefix(3), id: \.id) { affirmation in
                        AffirmationPreviewCard(
                            affirmation: affirmation,
                            onTap: {
                                hapticManager.impact(.medium)
                                onAffirmationDetail(affirmation)
                            }
                        )
                    }
                    
                    // Create Custom Affirmation Card
                    CreateAffirmationCard {
                        hapticManager.impact(.medium)
                        onCustomAffirmationCreator()
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Affirmation Preview Card
struct AffirmationPreviewCard: View {
    let affirmation: PersonalizedAffirmation
    let onTap: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isPlaying = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Voice Waveform Indicator
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        let hasVoice = affirmation.audioURL != nil
                        let fillColor = hasVoice ? ThemeColors.accent : ThemeColors.secondaryText.opacity(0.3)
                        let height = CGFloat.random(in: 8...20)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(fillColor)
                            .frame(width: 3, height: height)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                                value: isPlaying
                            )
                    }
                }
                .frame(height: 24)
                
                VStack(spacing: 8) {
                    Text(affirmation.category.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.accent)
                        .textCase(.uppercase)
                    
                    Text(affirmation.text)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    
                    if affirmation.audioURL != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.caption2)
                                .foregroundColor(ThemeColors.accent)
                            
                            Text("Your Voice")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(ThemeColors.accent)
                        }
                    }
                }
            }
            .frame(width: 160, height: 140)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemeColors.accent.opacity(themeManager.isDarkMode ? 0.15 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ThemeColors.accent.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if affirmation.audioURL != nil {
                isPlaying = true
            }
        }
    }
}

// MARK: - Create Affirmation Card
struct CreateAffirmationCard: View {
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(ThemeColors.accent)
                
                VStack(spacing: 4) {
                    Text("Create Custom")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Personalized affirmation")
                        .font(.caption2)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 160, height: 140)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemeColors.secondaryText.opacity(themeManager.isDarkMode ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ThemeColors.secondaryText.opacity(0.2), lineWidth: 1)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Voice Quick Action Card
struct VoiceQuickActionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let hasVoiceFeature: Bool
    let isVoiceEnabled: Bool
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundColor(color)
                    
                    if hasVoiceFeature && isVoiceEnabled {
                        // Voice indicator badge
                        Circle()
                            .fill(ThemeColors.accent)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Image(systemName: "waveform")
                                    .font(.system(size: 6))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 12, y: -12)
                    }
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(themeManager.isDarkMode ? 0.2 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                        //.lineLimit(2)
                        //.fixedSize(horizontal: false, vertical: true)
                        
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(themeManager.isDarkMode ? 0.2 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recommendations Section
struct RecommendationsSection: View {
    let onVoiceGuidedIntervention: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var coachingService = CoachingService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(spacing: 12) {
                ForEach(coachingService.currentRecommendations.prefix(3), id: \.id) { recommendation in
                    RecommendationCard(
                        recommendation: recommendation,
                        onVoiceGuidedIntervention: onVoiceGuidedIntervention
                    )
                }
            }
        }
    }
}

// MARK: - Recommendation Card
struct RecommendationCard: View {
    let recommendation: CoachingRecommendation
    let onVoiceGuidedIntervention: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticManager
    @State private var isCompleted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: recommendation.icon)
                    .foregroundColor(recommendation.color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text(recommendation.category)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Spacer()
                
                // Voice indicator if available
                if recommendation.hasVoiceVersion {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(ThemeColors.accent)
                        .font(.caption)
                }
                
                Button(action: {
                    hapticManager.impact(.light)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isCompleted.toggle()
                    }
                }) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? ThemeColors.success : ThemeColors.secondaryText)
                        .font(.title3)
                }
            }
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                if let duration = recommendation.estimatedDuration {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(ThemeColors.accent)
                            .font(.caption)
                        
                        Text(duration)
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                }
                
                Spacer()
                
                // Start Voice Session Button
                if recommendation.hasVoiceVersion {
                    Button("Start Voice Session") {
                        hapticManager.impact(.medium)
                        onVoiceGuidedIntervention()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeColors.accent.opacity(0.15))
                    )
                }
                
                Text(recommendation.priority.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(recommendation.priority.color.opacity(0.2))
                    .foregroundColor(recommendation.priority.color)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .themedCard()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? ThemeColors.success : Color.clear, lineWidth: 1)
        )
        .opacity(isCompleted ? 0.7 : 1.0)
        .scaleEffect(isCompleted ? 0.98 : 1.0)
    }
}

// MARK: - Coaching Progress Overview Section
struct CoachingProgressOverviewSection: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var coachingService = CoachingService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Progress")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(spacing: 12) {
                ProgressMetricRow(
                    title: "Emotional Awareness",
                    progress: coachingService.progressMetrics.emotionalAwarenessProgress,
                    color: ThemeColors.accent
                )
                
                ProgressMetricRow(
                    title: "Stress Management",
                    progress: coachingService.progressMetrics.stressManagementProgress,
                    color: .blue
                )
                
                ProgressMetricRow(
                    title: "Mindfulness Practice",
                    progress: coachingService.progressMetrics.mindfulnessProgress,
                    color: .green
                )
                
                ProgressMetricRow(
                    title: "Goal Achievement",
                    progress: coachingService.progressMetrics.goalAchievementProgress,
                    color: ThemeColors.success
                )
            }
            .padding()
            .themedCard()
        }
    }
}

// MARK: - Progress Metric Row
struct ProgressMetricRow: View {
    let title: String
    let progress: Double
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 1.2)
        }
    }
}

// MARK: - Extensions for Voice Integration
extension CoachingRecommendation {
    var hasVoiceVersion: Bool {
        // Check if this recommendation has a voice-guided version available
        return category.lowercased().contains("breathing") ||
               category.lowercased().contains("meditation") ||
               category.lowercased().contains("affirmation") ||
               priority == .high
    }
}

// MARK: - Preview
struct CoachingView_Previews: PreviewProvider {
    static var previews: some View {
        CoachingView()
            .environmentObject(ThemeManager())
            .environmentObject(CoachingService.shared)
            .environmentObject(HapticManager.shared)
    }
}

