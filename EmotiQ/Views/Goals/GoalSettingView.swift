//
//  GoalSettingView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import SwiftUI

// MARK: - Goal Setting View
struct GoalSettingView: View {
    @StateObject private var viewModel = GoalSettingViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var coachingService: CoachingService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        FeatureGateView(feature: .goalSetting) {
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack { mainContent }
                } else {
                    NavigationView { mainContent }
                        .navigationViewStyle(StackNavigationViewStyle())
                }
            }
        }
    } // Close FeatureGateView

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            ThemeColors.primaryBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    GoalSettingHeaderView()
                    
                    if !viewModel.activeGoals.isEmpty {
                        ActiveGoalsSection(goals: viewModel.activeGoals, viewModel: viewModel)
                    }
                    
                    GoalCategoriesSection(viewModel: viewModel)
                    
                    Spacer(minLength: 100)
                }
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Goal Setting")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Goal") {
                    viewModel.showingGoalCreation = true
                }
                .foregroundColor(ThemeColors.accent)
            }
        }
        .sheet(isPresented: $viewModel.showingGoalCreation) {
            GoalCreationView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedGoal) { goal in
            GoalDetailView(goal: goal, viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadGoals()
        }
    }
}

// MARK: - Goal Setting Header
struct GoalSettingHeaderView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Your Emotional Goals")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Define meaningful objectives for your emotional growth journey")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "target")
                    .font(.system(size: 40))
                    .foregroundColor(ThemeColors.accent)
            }
        }
        .padding()
        .themedCard()
    }
}

// MARK: - Active Goals Section
struct ActiveGoalsSection: View {
    let goals: [EmotionalGoal]
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var openRowID: UUID? = nil
    @State private var isAnyRowDragging = false
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Goals")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Text("\(goals.count) active")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(goals) { goal in
                    
                    SwipeableRow(
                        id: goal.id,
                        openRowID: $openRowID,
                        isAnyRowDragging: $isAnyRowDragging
                    ) {
                        GoalCard(goal: goal, viewModel: viewModel)
                    } onDelete: {
                        viewModel.deleteGoal(goal)
                    }
                }
            }
        }
    }
}

// MARK: - Goal Card
struct GoalCard: View {
    let goal: EmotionalGoal
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            viewModel.selectedGoal = goal
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: goal.category.icon)
                        .foregroundColor(goal.category.color)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeColors.primaryText)
                            .lineLimit(1)
                        
                        Text(goal.category.displayName)
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(goal.progressPercentage)%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(goal.progress >= 0.8 ? ThemeColors.success : ThemeColors.accent)
                        
                        if let daysRemaining = goal.daysRemaining {
                            Text("\(daysRemaining) days")
                                .font(.caption2)
                                .foregroundColor(goal.isOverdue ? ThemeColors.error : ThemeColors.secondaryText)
                        }
                    }
                }
                
                // Progress Bar
                ProgressView(value: goal.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: goal.category.color))
                    .scaleEffect(y: 1.5)
                
                // Description
                Text(goal.description)
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                    .lineLimit(2)
                
                // Milestones
                if !goal.milestones.isEmpty {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(ThemeColors.accent)
                            .font(.caption)
                        
                        Text("\(goal.milestones.filter { $0.isCompleted }.count)/\(goal.milestones.count) milestones")
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .contentShape(Rectangle())
            //.themedCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Template Goals Section
struct TemplateGoalsSection: View {
    let goals: [EmotionalGoal]
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var openRowID: UUID? = nil
    @State private var isAnyRowDragging = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Template Examples")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Text("\(goals.count) examples")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(goals) { goal in
                    SwipeableRow(
                        id: goal.id,
                        openRowID: $openRowID,
                        isAnyRowDragging: $isAnyRowDragging
                    ) {
                        TemplateGoalCard(goal: goal, viewModel: viewModel, category: GoalCategory.communication)
                    } onDelete: {
                        viewModel.deleteTemplateGoal(goal)
                    }
                }
            }
        }
    }
}

// MARK: - Template Goal Card
struct TemplateGoalCard: View {
    let goal: EmotionalGoal
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    let category: GoalCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Template Badge
            HStack {
                Image(systemName: goal.category.icon)
                    .foregroundColor(goal.category.color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(goal.category.displayName)
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                        
                        Text("Template")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ThemeColors.warning.opacity(0.2))
                            .foregroundColor(ThemeColors.warning)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(goal.progressPercentage)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(goal.progress >= 0.8 ? ThemeColors.success : ThemeColors.accent)
                    
                    if let daysRemaining = goal.daysRemaining {
                        Text("\(daysRemaining) days")
                            .font(.caption2)
                            .foregroundColor(goal.isOverdue ? ThemeColors.error : ThemeColors.secondaryText)
                    }
                }
            }
            
            // Progress Bar
            ProgressView(value: goal.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: goal.category.color))
                .scaleEffect(y: 1.5)
            
            // Description
            Text(goal.description)
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
                .lineLimit(2)
            
            // Milestones
            if !goal.milestones.isEmpty {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(ThemeColors.accent)
                        .font(.caption)
                    
                    Text("\(goal.milestones.filter { $0.isCompleted }.count)/\(goal.milestones.count) milestones")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    Spacer()
                    
                    Text("Swipe to delete")
                        .font(.caption2)
                        .foregroundColor(ThemeColors.secondaryText)
                        .italic()
                }
            }
        }
        .padding()
        //.themedCard()
        
    }
}

// MARK: - Goal Categories Section
struct GoalCategoriesSection: View {
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goal Categories")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(GoalCategory.allCases, id: \.self) { category in
                    GoalCategoryCard(category: category, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Goal Category Card
struct GoalCategoryCard: View {
    let category: GoalCategory
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            viewModel.selectedCategory = category
            viewModel.showingGoalCreation = true
        }) {
            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(category.color)
                
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("\(viewModel.getGoalCount(for: category)) active")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(category.color.opacity(themeManager.isDarkMode ? 0.2 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(category.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Goal Templates Section
struct QuickGoalTemplatesSection: View {
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Start Templates")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.goalTemplates, id: \.id) { template in
                        GoalTemplateCard(template: template, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

// MARK: - Goal Template Card
struct GoalTemplateCard: View {
    let template: GoalTemplate
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            viewModel.createGoalFromTemplate(template)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: template.icon)
                        .foregroundColor(template.category.color)
                        .font(.title3)
                    
                    Spacer()
                    
                    Text(template.duration)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Text(template.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                    .lineLimit(2)
                
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                    .lineLimit(3)
                
                HStack {
                    Text(template.category.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(template.category.color.opacity(0.2))
                        .foregroundColor(template.category.color)
                        .clipShape(Capsule())
                    
                    Spacer()
                }
            }
            .frame(width: 180)
            .padding()
            .themedCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Progress Overview Section
struct ProgressOverviewSection: View {
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Overview")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(spacing: 12) {
                ProgressMetricRow(
                    title: "Overall Progress",
                    progress: viewModel.overallProgress,
                    color: ThemeColors.accent
                )
                
                ProgressMetricRow(
                    title: "Goals Completed",
                    progress: viewModel.completionRate,
                    color: ThemeColors.success
                )
                
                ProgressMetricRow(
                    title: "Weekly Activity",
                    progress: viewModel.weeklyActivity,
                    color: ThemeColors.warning
                )
            }
            .padding()
            .themedCard()
        }
    }
}
// MARK: - Goal Template Model
struct GoalTemplate {
    let title: String
    let description: String
    let category: GoalCategory
    let icon: String
    let duration: String
    let milestones: [String]
    let id = UUID() // Add unique identifier for templates
    
    static let defaultTemplates: [GoalTemplate] = [
        GoalTemplate(
            title: "Daily Emotional Check-ins",
            description: "Build awareness by checking in with your emotions daily",
            category: .emotionalAwareness,
            icon: "heart.text.square",
            duration: "30 days",
            milestones: ["Week 1: Establish routine", "Week 2: Identify patterns", "Week 3: Deepen awareness", "Week 4: Integrate insights"]
        ),
        GoalTemplate(
            title: "Stress Reduction Journey",
            description: "Learn and practice effective stress management techniques",
            category: .stressManagement,
            icon: "leaf.circle",
            duration: "6 weeks",
            milestones: ["Learn breathing techniques", "Practice daily meditation", "Identify stress triggers", "Develop coping strategies"]
        ),
        GoalTemplate(
            title: "Mindful Living Practice",
            description: "Cultivate mindfulness in daily activities and interactions",
            category: .mindfulness,
            icon: "brain.head.profile",
            duration: "8 weeks",
            milestones: ["Morning mindfulness", "Mindful eating", "Mindful communication", "Mindful work"]
        ),
        GoalTemplate(
            title: "Self-Compassion Development",
            description: "Learn to treat yourself with kindness and understanding",
            category: .selfCompassion,
            icon: "heart.circle",
            duration: "4 weeks",
            milestones: ["Recognize self-criticism", "Practice self-kindness", "Develop self-forgiveness", "Integrate compassion"]
        )
    ]
}

// MARK: - Goal Setting View Model
@MainActor
class GoalSettingViewModel: ObservableObject {
    @Published var activeGoals: [EmotionalGoal] = []
    @Published var completedGoals: [EmotionalGoal] = []
    @Published var templateGoals: [EmotionalGoal] = [] // Track goals created from templates
    @Published var showingGoalCreation = false
    @Published var selectedGoal: EmotionalGoal?
    @Published var selectedCategory: GoalCategory?
    
    let goalTemplates = GoalTemplate.defaultTemplates
    
    // MARK: - Computed Properties
    var overallProgress: Double {
        guard !activeGoals.isEmpty else { return 0 }
        let totalProgress = activeGoals.map { $0.progress }.reduce(0, +)
        return totalProgress / Double(activeGoals.count)
    }
    
    var completionRate: Double {
        let totalGoals = activeGoals.count + completedGoals.count
        guard totalGoals > 0 else { return 0 }
        return Double(completedGoals.count) / Double(totalGoals)
    }
    
    var weeklyActivity: Double {
        // Calculate based on recent goal updates
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentlyUpdated = activeGoals.filter { goal in
            // This would check last update time in a real implementation
            return true
        }
        return min(Double(recentlyUpdated.count) / Double(max(activeGoals.count, 1)), 1.0)
    }
    
    // MARK: - Public Methods
    func loadGoals() {
        // Load from CoachingService
        if let coachingService = CoachingService.shared as? CoachingService {
            let allGoals = coachingService.userGoals
            activeGoals = allGoals.filter { !$0.isCompleted && !$0.isTemplate }
            completedGoals = allGoals.filter { $0.isCompleted && !$0.isTemplate }
            templateGoals = allGoals.filter { $0.isTemplate }
        }
    }
    
    func getGoalCount(for category: GoalCategory) -> Int {
        return activeGoals.filter { $0.category == category }.count
    }
    
    func createGoalFromTemplate(_ template: GoalTemplate) {
        let milestones = template.milestones.enumerated().map { index, title in
            GoalMilestone(
                title: title,
                description: "Complete milestone \(index + 1)",
                targetProgress: Double(index + 1) / Double(template.milestones.count)
            )
        }
        
        let targetDate = Calendar.current.date(byAdding: .day, value: getDaysFromDuration(template.duration), to: Date())
        
        let goal = EmotionalGoal(
            title: template.title,
            description: template.description,
            category: template.category,
            targetDate: targetDate,
            milestones: milestones,
            isTemplate: true // Mark as template goal
        )
        
        Task {
            await CoachingService.shared.createGoal(goal)
            loadGoals()
        }
    }
    
    func deleteTemplateGoal(_ goal: EmotionalGoal) {
        Task {
            await CoachingService.shared.deleteGoal(goal.id)
            loadGoals()
        }
    }
    
    func deleteGoal(_ goal: EmotionalGoal) {
        Task {
            await CoachingService.shared.deleteGoal(goal.id)
            loadGoals()
        }
    }
    
    func markMilestoneComplete(_ goal: EmotionalGoal, milestoneId: UUID) {
        Task {
            await CoachingService.shared.markMilestoneComplete(goal.id, milestoneId: milestoneId)
            await MainActor.run {
                loadGoals()
            }
        }
    }
    
    func addMilestone(_ goal: EmotionalGoal, title: String, description: String, targetProgress: Double) {
        Task {
            await CoachingService.shared.addMilestone(goal.id, title: title, description: description, targetProgress: targetProgress)
            await MainActor.run {
                loadGoals()
            }
        }
    }
    
    func updateGoalProgress(_ goal: EmotionalGoal, progress: Double) {
        Task {
            await CoachingService.shared.updateGoalProgress(goal.id, progress: progress)
            await MainActor.run {
                loadGoals()
            }
        }
    }
    
    func updateGoalProgressAndMilestones(_ goal: EmotionalGoal, progress: Double, completedMilestones: [UUID]) {
        Task {
            // Update progress
            await CoachingService.shared.updateGoalProgress(goal.id, progress: progress)
            
            // Update completed milestones
            for milestoneId in completedMilestones {
                await CoachingService.shared.markMilestoneComplete(goal.id, milestoneId: milestoneId)
            }
            
            // Reload goals after all updates are complete to ensure milestones are preserved
            await MainActor.run {
                CoachingService.shared.loadGoals()
                loadGoals()
            }
        }
    }
    
    // MARK: - Private Methods
    private func getDaysFromDuration(_ duration: String) -> Int {
        if duration.contains("week") {
            let weeks = Int(duration.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 4
            return weeks * 7
        } else if duration.contains("day") {
            return Int(duration.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 30
        }
        return 30 // Default
    }
}

// MARK: - Preview
struct GoalSettingView_Previews: PreviewProvider {
    static var previews: some View {
        GoalSettingView()
            .environmentObject(ThemeManager())
            .environmentObject(CoachingService.shared)
    }
}


