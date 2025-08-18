//
//  CoachingView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import Foundation
//
//struct CoachingView: View {
//    @StateObject private var viewModel = CoachingViewModel()
//    @EnvironmentObject private var subscriptionService: SubscriptionService
//    @EnvironmentObject private var emotionService: CoreMLEmotionService
//    @State private var showingSubscriptionPaywall = false
//    
//    var body: some View {
//        NavigationView {
//            ZStack {
//                // Background gradient
//                LinearGradient(
//                    colors: [Color.purple.opacity(0.05), Color.cyan.opacity(0.05)],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//                .ignoresSafeArea()
//                
//                if subscriptionService.hasActiveSubscription {
//                    // Premium coaching content
//                    ScrollView {
//                        VStack(spacing: 20) {
//                            // MARK: - Personalized Greeting
//                            PersonalizedGreetingSection(viewModel: viewModel)
//                            
//                            // MARK: - Today's Coaching
//                            TodaysCoachingSection(viewModel: viewModel)
//                            
//                            // MARK: - Quick Interventions
//                            QuickInterventionsSection(viewModel: viewModel)
//                            
//                            // MARK: - Coaching Programs
//                            CoachingProgramsSection(viewModel: viewModel)
//                            
//                            // MARK: - Progress Tracking
//                            ProgressTrackingSection(viewModel: viewModel)
//                            
//                            Spacer(minLength: 100) // Tab bar spacing
//                        }
//                        .padding(.horizontal)
//                    }
//                } else {
//                    // Premium feature locked state
//                    CoachingLockedView {
//                        showingSubscriptionPaywall = true
//                    }
//                }
//            }
//            .navigationTitle("Emotional Coach")
//            .navigationBarTitleDisplayMode(.large)
//            .sheet(isPresented: $showingSubscriptionPaywall) {
//                SubscriptionPaywallView()
//            }
//            .onAppear {
//                if subscriptionService.hasActiveSubscription {
//                    viewModel.loadCoachingData()
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Coaching Locked View
//struct CoachingLockedView: View {
//    let upgradeAction: () -> Void
//    
//    var body: some View {
//        VStack(spacing: 30) {
//            // Coach icon
//            Image(systemName: "person.crop.circle.badge.checkmark")
//                .font(.system(size: 60))
//                .foregroundColor(.purple.opacity(0.6))
//            
//            VStack(spacing: 12) {
//                Text("Emotional Coaching")
//                    .font(.title2)
//                    .fontWeight(.semibold)
//                
//                Text("Get personalized emotional intelligence coaching powered by advanced AI")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal)
//            }
//            
//            // Preview features
//            VStack(alignment: .leading, spacing: 12) {
//                CoachingFeatureRow(icon: "brain.head.profile", title: "Personalized Emotional Coaching")
//                CoachingFeatureRow(icon: "target", title: "Custom Goal Setting")
//                CoachingFeatureRow(icon: "heart.text.square", title: "Daily Emotional Check-ins")
//                CoachingFeatureRow(icon: "leaf", title: "Mindfulness Exercises")
//                CoachingFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking")
//                CoachingFeatureRow(icon: "speaker.wave.2", title: "Voice-Generated Affirmations")
//            }
//            .padding()
//            .background(
//                RoundedRectangle(cornerRadius: 16)
//                    .fill(.regularMaterial)
//            )
//            
//            Button(action: upgradeAction) {
//                HStack {
//                    Image(systemName: "crown.fill")
//                    Text("Start Emotional Coaching")
//                }
//                .font(.headline)
//                .foregroundColor(.white)
//                .padding(.horizontal, 30)
//                .padding(.vertical, 15)
//                .background(
//                    LinearGradient(
//                        colors: [.purple, .cyan],
//                        startPoint: .leading,
//                        endPoint: .trailing
//                    )
//                )
//                .clipShape(Capsule())
//            }
//        }
//        .padding()
//    }
//}
//
//struct CoachingFeatureRow: View {
//    let icon: String
//    let title: String
//    
//    var body: some View {
//        HStack(spacing: 12) {
//            Image(systemName: icon)
//                .foregroundColor(.purple)
//                .frame(width: 24)
//            
//            Text(title)
//                .font(.subheadline)
//                .foregroundColor(.primary)
//            
//            Spacer()
//            
//            Image(systemName: "checkmark")
//                .foregroundColor(.green)
//                .font(.caption)
//        }
//    }
//}
//
//// MARK: - Personalized Greeting Section
//struct PersonalizedGreetingSection: View {
//    @ObservedObject var viewModel: CoachingViewModel
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(viewModel.personalizedGreeting)
//                        .font(.title2)
//                        .fontWeight(.semibold)
//                    
//                    Text(viewModel.motivationalMessage)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//                
//                Spacer()
//                
//                // AI coach avatar
//                Image(systemName: "brain.head.profile.fill")
//                    .font(.system(size: 40))
//                    .foregroundColor(.purple)
//            }
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 16)
//                .fill(.regularMaterial)
//        )
//    }
//}
//
//// MARK: - Today's Coaching Section
//struct TodaysCoachingSection: View {
//    @ObservedObject var viewModel: CoachingViewModel
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Today's Coaching")
//                .font(.headline)
//                .fontWeight(.semibold)
//            
//            VStack(spacing: 12) {
//                ForEach(viewModel.todaysRecommendations, id: \.id) { recommendation in
//                    CoachingRecommendationCard(recommendation: recommendation)
//                }
//            }
//        }
//    }
//}
//
//struct CoachingRecommendationCard: View {
//    let recommendation: CoachingRecommendation
//    @State private var isCompleted = false
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Image(systemName: recommendation.icon)
//                    .foregroundColor(recommendation.color)
//                    .font(.title3)
//                
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(recommendation.title)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                    
//                    Text(recommendation.category)
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                
//                Spacer()
//                
//                Button(action: {
//                    isCompleted.toggle()
//                }) {
//                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
//                        .foregroundColor(isCompleted ? .green : .gray)
//                        .font(.title3)
//                }
//            }
//            
//            Text(recommendation.description)
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .fixedSize(horizontal: false, vertical: true)
//            
//            if let duration = recommendation.estimatedDuration {
//                HStack {
//                    Image(systemName: "clock")
//                        .foregroundColor(.secondary)
//                        .font(.caption)
//                    
//                    Text(duration)
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    
//                    Spacer()
//                }
//            }
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(.regularMaterial)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(isCompleted ? .green : .clear, lineWidth: 1)
//                )
//        )
//        .opacity(isCompleted ? 0.7 : 1.0)
//    }
//}
//
//// MARK: - Quick Interventions Section
//struct QuickInterventionsSection: View {
//    @ObservedObject var viewModel: CoachingViewModel
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Quick Interventions")
//                .font(.headline)
//                .fontWeight(.semibold)
//            
//            LazyVGrid(columns: [
//                GridItem(.flexible()),
//                GridItem(.flexible())
//            ], spacing: 12) {
//                ForEach(viewModel.quickInterventions, id: \.id) { intervention in
//                    QuickInterventionCard(intervention: intervention)
//                }
//            }
//        }
//    }
//}
//
//struct QuickInterventionCard: View {
//    let intervention: QuickIntervention
//    
//    var body: some View {
//        Button(action: {
//            // Handle intervention action
//        }) {
//            VStack(spacing: 8) {
//                Image(systemName: intervention.icon)
//                    .font(.title2)
//                    .foregroundColor(intervention.color)
//                
//                Text(intervention.title)
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                    .multilineTextAlignment(.center)
//                
//                Text(intervention.duration)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(.regularMaterial)
//            )
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}
//
//// MARK: - Coaching Programs Section
//struct CoachingProgramsSection: View {
//    @ObservedObject var viewModel: CoachingViewModel
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            HStack {
//                Text("Coaching Programs")
//                    .font(.headline)
//                    .fontWeight(.semibold)
//                
//                Spacer()
//                
//                Button("View All") {}
//                    .font(.caption)
//                    .foregroundColor(.purple)
//            }
//            
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 12) {
//                    ForEach(viewModel.coachingPrograms, id: \.id) { program in
//                        CoachingProgramCard(program: program)
//                    }
//                }
//                .padding(.horizontal, 1)
//            }
//        }
//    }
//}
//
//struct CoachingProgramCard: View {
//    let program: CoachingProgram
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Image(systemName: program.icon)
//                    .foregroundColor(program.color)
//                    .font(.title3)
//                
//                Spacer()
//                
//                Text("\(program.completedSessions)/\(program.totalSessions)")
//                    .font(.caption)
//                    .fontWeight(.medium)
//                    .foregroundColor(.secondary)
//            }
//            
//            Text(program.title)
//                .font(.subheadline)
//                .fontWeight(.semibold)
//                .lineLimit(2)
//            
//            Text(program.description)
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .lineLimit(3)
//            
//            ProgressView(value: Double(program.completedSessions), total: Double(program.totalSessions))
//                .progressViewStyle(LinearProgressViewStyle(tint: program.color))
//        }
//        .frame(width: 160)
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(.regularMaterial)
//        )
//    }
//}
//
//// MARK: - Progress Tracking Section
//struct ProgressTrackingSection: View {
//    @ObservedObject var viewModel: CoachingViewModel
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Your Progress")
//                .font(.headline)
//                .fontWeight(.semibold)
//            
//            VStack(spacing: 12) {
//                ProgressMetricRow(
//                    title: "Emotional Awareness",
//                    progress: viewModel.emotionalAwarenessProgress,
//                    color: .purple
//                )
//                
//                ProgressMetricRow(
//                    title: "Stress Management",
//                    progress: viewModel.stressManagementProgress,
//                    color: .blue
//                )
//                
//                ProgressMetricRow(
//                    title: "Mindfulness Practice",
//                    progress: viewModel.mindfulnessProgress,
//                    color: .green
//                )
//                
//                ProgressMetricRow(
//                    title: "Goal Achievement",
//                    progress: viewModel.goalAchievementProgress,
//                    color: .orange
//                )
//            }
//            .padding()
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(.regularMaterial)
//            )
//        }
//    }
//}
//
//struct ProgressMetricRow: View {
//    let title: String
//    let progress: Double
//    let color: Color
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 4) {
//            HStack {
//                Text(title)
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                
//                Spacer()
//                
//                Text("\(Int(progress * 100))%")
//                    .font(.caption)
//                    .fontWeight(.medium)
//                    .foregroundColor(.secondary)
//            }
//            
//            ProgressView(value: progress)
//                .progressViewStyle(LinearProgressViewStyle(tint: color))
//        }
//    }
//}
//
//// MARK: - Data Models
//struct CoachingRecommendation {
//    let id = UUID()
//    let title: String
//    let description: String
//    let category: String
//    let icon: String
//    let color: Color
//    let estimatedDuration: String?
//}
//
//struct QuickIntervention {
//    let id = UUID()
//    let title: String
//    let duration: String
//    let icon: String
//    let color: Color
//}
//
//struct CoachingProgram {
//    let id = UUID()
//    let title: String
//    let description: String
//    let icon: String
//    let color: Color
//    let totalSessions: Int
//    let completedSessions: Int
//}
//
//// MARK: - Coaching View Model
//@MainActor
//class CoachingViewModel: ObservableObject {
//    @Published var personalizedGreeting = ""
//    @Published var motivationalMessage = ""
//    @Published var todaysRecommendations: [CoachingRecommendation] = []
//    @Published var quickInterventions: [QuickIntervention] = []
//    @Published var coachingPrograms: [CoachingProgram] = []
//    @Published var emotionalAwarenessProgress: Double = 0
//    @Published var stressManagementProgress: Double = 0
//    @Published var mindfulnessProgress: Double = 0
//    @Published var goalAchievementProgress: Double = 0
//    
//    func loadCoachingData() {
//        generatePersonalizedContent()
//        loadRecommendations()
//        loadQuickInterventions()
//        loadCoachingPrograms()
//        loadProgressMetrics()
//    }
//    
//    private func generatePersonalizedContent() {
//        let hour = Calendar.current.component(.hour, from: Date())
//        let timeGreeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
//        
//        personalizedGreeting = "\(timeGreeting), ready for today's coaching?"
//        motivationalMessage = "You're on a 7-day streak! Let's keep building your emotional intelligence."
//    }
//    
//    private func loadRecommendations() {
//        todaysRecommendations = [
//            CoachingRecommendation(
//                title: "Practice Gratitude",
//                description: "Take a moment to reflect on three things you're grateful for today. This helps shift focus to positive aspects of your life.",
//                category: "Mindfulness",
//                icon: "heart.fill",
//                color: .pink,
//                estimatedDuration: "3 minutes"
//            ),
//            CoachingRecommendation(
//                title: "Breathing Exercise",
//                description: "Try the 4-7-8 breathing technique to reduce stress and increase calm. Inhale for 4, hold for 7, exhale for 8.",
//                category: "Stress Management",
//                icon: "lungs.fill",
//                color: .blue,
//                estimatedDuration: "5 minutes"
//            ),
//            CoachingRecommendation(
//                title: "Emotion Check-in",
//                description: "Record a voice note describing how you're feeling right now. This builds emotional awareness and vocabulary.",
//                category: "Self-Awareness",
//                icon: "waveform.circle.fill",
//                color: .purple,
//                estimatedDuration: "2 minutes"
//            )
//        ]
//    }
//    
//    private func loadQuickInterventions() {
//        quickInterventions = [
//            QuickIntervention(
//                title: "Deep Breathing",
//                duration: "1 min",
//                icon: "lungs.fill",
//                color: .blue
//            ),
//            QuickIntervention(
//                title: "Body Scan",
//                duration: "3 min",
//                icon: "figure.walk",
//                color: .green
//            ),
//            QuickIntervention(
//                title: "Positive Affirmation",
//                duration: "30 sec",
//                icon: "heart.text.square.fill",
//                color: .pink
//            ),
//            QuickIntervention(
//                title: "Mindful Moment",
//                duration: "2 min",
//                icon: "leaf.fill",
//                color: .green
//            )
//        ]
//    }
//    
//    private func loadCoachingPrograms() {
//        coachingPrograms = [
//            CoachingProgram(
//                title: "Stress Mastery",
//                description: "Learn effective techniques to manage and reduce stress in daily life.",
//                icon: "brain.head.profile.fill",
//                color: .blue,
//                totalSessions: 10,
//                completedSessions: 3
//            ),
//            CoachingProgram(
//                title: "Emotional Intelligence",
//                description: "Develop deeper understanding and management of emotions.",
//                icon: "heart.circle.fill",
//                color: .purple,
//                totalSessions: 12,
//                completedSessions: 7
//            ),
//            CoachingProgram(
//                title: "Mindfulness Journey",
//                description: "Build a sustainable mindfulness practice for daily well-being.",
//                icon: "leaf.circle.fill",
//                color: .green,
//                totalSessions: 8,
//                completedSessions: 2
//            )
//        ]
//    }
//    
//    private func loadProgressMetrics() {
//        emotionalAwarenessProgress = 0.75
//        stressManagementProgress = 0.60
//        mindfulnessProgress = 0.45
//        goalAchievementProgress = 0.80
//    }
//}
//
//// MARK: - Preview
//struct CoachingView_Previews: PreviewProvider {
//    static var previews: some View {
//        CoachingView()
//            .environmentObject(SubscriptionService())
//            .environmentObject(CoreMLEmotionService())
//    }
//}
//
//
import SwiftUI

// MARK: - Updated Coaching View
struct CoachingView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var coachingService = CoachingService.shared
    @State private var showingGoalSetting = false
    @State private var showingMicroInterventions = false
    @State private var showInsight = false
    
    var body: some View {
        ZStack {
            ThemeColors.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    CoachingHeaderView()
                    
                    // Quick Actions
                    QuickActionsSection(
                        showingGoalSetting: $showingGoalSetting,
                        showingMicroInterventions: $showingMicroInterventions, showInsights: $showInsight
                    )
                    
                    // Recommendations
                    RecommendationsSection()
                    
                    // Progress Overview
                    CoachingProgressOverviewSection()
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Coaching")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingGoalSetting) {
            GoalSettingView()
        }
        .sheet(isPresented: $showingMicroInterventions) {
            MicroInterventionsView()
        }
        .sheet(isPresented: $showInsight) {
            
            InsightsView()
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
    @Binding var showingGoalSetting: Bool
    @Binding var showingMicroInterventions: Bool
    @Binding var showInsights: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
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
                QuickActionCard(
                    title: "Set Goals",
                    description: "Create emotional growth objectives",
                    icon: "target",
                    color: .blue,
                    action: { showingGoalSetting = true }
                )
                
                QuickActionCard(
                    title: "Quick Relief",
                    description: "Instant emotional interventions",
                    icon: "heart.circle.fill",
                    color: .green,
                    action: { showingMicroInterventions = true }
                )
                
                QuickActionCard(
                    title: "Progress",
                    description: "Track your emotional journey",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple,
                    action: { /* Show progress detail */ }
                )
                
                QuickActionCard(
                    title: "Insights",
                    description: "Discover emotional patterns",
                    icon: "lightbulb.fill",
                    color: .orange,
                    action: { showInsights = true }
                )
            }
        }
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

// MARK: - Recommendations Section
struct RecommendationsSection: View {
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
                    RecommendationCard(recommendation: recommendation)
                }
            }
        }
    }
}

// MARK: - Recommendation Card
struct RecommendationCard: View {
    let recommendation: CoachingRecommendation
    @EnvironmentObject private var themeManager: ThemeManager
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
                
                Button(action: {
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
            
            if let duration = recommendation.estimatedDuration {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(ThemeColors.accent)
                        .font(.caption)
                    
                    Text(duration)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    Spacer()
                    
                    Text(recommendation.priority.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(recommendation.priority.color.opacity(0.2))
                        .foregroundColor(recommendation.priority.color)
                        .clipShape(Capsule())
                }
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

// MARK: - Preview
struct CoachingView_Previews: PreviewProvider {
    static var previews: some View {
        CoachingView()
            .environmentObject(ThemeManager())
            .environmentObject(CoachingService.shared)
    }
}

