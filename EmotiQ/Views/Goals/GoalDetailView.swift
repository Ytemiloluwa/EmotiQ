//
//  GoalDetailView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import SwiftUI

// MARK: - Goal Detail View
struct GoalDetailView: View {
    let goal: EmotionalGoal
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingProgressUpdate = false
    @State private var newProgress: Double = 0
    @State private var showingDeleteConfirmation = false
    @State private var currentGoal: EmotionalGoal
    
    init(goal: EmotionalGoal, viewModel: GoalSettingViewModel) {
        self.goal = goal
        self.viewModel = viewModel
        self._currentGoal = State(initialValue: goal)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColors.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Goal Header
                        GoalDetailHeaderView(goal: currentGoal)
                        
                        // MARK: - Progress Section
                        ProgressSection(goal: currentGoal, viewModel: viewModel)
                        
                        // MARK: - Milestones Section
                        if !currentGoal.milestones.isEmpty {
                            MilestonesDetailSection(goal: currentGoal, viewModel: viewModel)
                        }
                        
                        // MARK: - Statistics Section
                        StatisticsSection(goal: currentGoal)
                        
                        // MARK: - Actions Section
                        ActionsSection(
                            goal: currentGoal,
                            showingProgressUpdate: $showingProgressUpdate,
                            showingDeleteConfirmation: $showingDeleteConfirmation
                        )
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle(goal.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColors.accent)
                }
            }
            .sheet(isPresented: $showingProgressUpdate) {
                ProgressUpdateView(
                    goal: currentGoal,
                    currentProgress: currentGoal.progress,
                    viewModel: viewModel,
                    onProgressUpdated: { updatedGoal in
                        currentGoal = updatedGoal
                    }
                )
            }
            .alert("Delete Goal", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteGoal(goal)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this goal? This action cannot be undone.")
            }
            .onAppear {
                currentGoal = goal
                newProgress = goal.progress
            }
        }
    }
}

// MARK: - Goal Detail Header
struct GoalDetailHeaderView: View {
    let goal: EmotionalGoal
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: goal.category.icon)
                    .font(.system(size: 40))
                    .foregroundColor(goal.category.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.category.displayName)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text(goal.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(goal.progressPercentage)%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(goal.progress >= 0.8 ? ThemeColors.success : goal.category.color)
                    
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
            
            Text(goal.description)
                .font(.body)
                .foregroundColor(ThemeColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            // Target Date Info
            if let targetDate = goal.targetDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(goal.isOverdue ? ThemeColors.error : ThemeColors.accent)
                    
                    Text("Target: \(targetDate, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(goal.isOverdue ? ThemeColors.error : ThemeColors.primaryText)
                    
                    if let daysRemaining = goal.daysRemaining {
                        Text("(\(daysRemaining) days remaining)")
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                    
                    Spacer()
                }
            }
            
            // Creation Date
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(ThemeColors.secondaryText)
                
                Text("Created \(goal.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                
                Spacer()
            }
        }
        .padding()
        .themedCard()
    }
}

// MARK: - Progress Section
struct ProgressSection: View {
    let goal: EmotionalGoal
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(spacing: 16) {
                // Progress Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Overall Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeColors.primaryText)
                        
                        Spacer()
                        
                        Text("\(goal.progressPercentage)%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(goal.category.color)
                    }
                    
                    ProgressView(value: goal.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: goal.category.color))
                        .scaleEffect(y: 2.0)
                }
                
                // Progress Visualization
                HStack(spacing: 12) {
                    ProgressCircle(
                        title: "Start",
                        isCompleted: goal.progress > 0,
                        color: goal.category.color
                    )
                    
                    ProgressLine(isCompleted: goal.progress > 0.25)
                    
                    ProgressCircle(
                        title: "25%",
                        isCompleted: goal.progress >= 0.25,
                        color: goal.category.color
                    )
                    
                    ProgressLine(isCompleted: goal.progress > 0.5)
                    
                    ProgressCircle(
                        title: "50%",
                        isCompleted: goal.progress >= 0.5,
                        color: goal.category.color
                    )
                    
                    ProgressLine(isCompleted: goal.progress > 0.75)
                    
                    ProgressCircle(
                        title: "75%",
                        isCompleted: goal.progress >= 0.75,
                        color: goal.category.color
                    )
                    
                    ProgressLine(isCompleted: goal.progress >= 1.0)
                    
                    ProgressCircle(
                        title: "Complete",
                        isCompleted: goal.progress >= 1.0,
                        color: ThemeColors.success
                    )
                }
            }
            .padding()
            .themedCard()
        }
    }
}

// MARK: - Progress Circle
struct ProgressCircle: View {
    let title: String
    let isCompleted: Bool
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isCompleted ? color : ThemeColors.secondaryBackground)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: 2)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(isCompleted ? 1 : 0)
                )
            
            Text(title)
                .font(.caption2)
                .foregroundColor(isCompleted ? ThemeColors.primaryText : ThemeColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Progress Line
struct ProgressLine: View {
    let isCompleted: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Rectangle()
            .fill(isCompleted ? ThemeColors.accent : ThemeColors.secondaryText.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Milestones Detail Section
struct MilestonesDetailSection: View {
    let goal: EmotionalGoal
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingAddMilestone = false
    @State private var localMilestones: [GoalMilestone]
    
    init(goal: EmotionalGoal, viewModel: GoalSettingViewModel) {
        self.goal = goal
        self.viewModel = viewModel
        self._localMilestones = State(initialValue: goal.milestones.sorted(by: { $0.targetProgress < $1.targetProgress }))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Milestones")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Text("\(localMilestones.filter { $0.isCompleted }.count)/\(localMilestones.count)")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                
//                Button(action: {
//                    showingAddMilestone = true
//                }) {
//                    Image(systemName: "plus.circle.fill")
//                        .foregroundColor(ThemeColors.accent)
//                        .font(.title3)
//                }
            }
            
            VStack(spacing: 12) {
                ForEach(localMilestones) { milestone in
                    MilestoneRow(
                        milestone: milestone,
                        goalProgress: goal.progress,
                        onMarkComplete: {
                            markMilestoneComplete(milestone)
                        }
                    )
                }
            }
            .padding()
            .themedCard()
        }
//        .sheet(isPresented: $showingAddMilestone) {
//            AddMilestoneView(goal: goal, viewModel: viewModel)
//        }
        .onChange(of: goal.milestones) { oldValue, newValue in
            localMilestones = newValue.sorted(by: { $0.targetProgress < $1.targetProgress })
        }
    }
    
    private func markMilestoneComplete(_ milestone: GoalMilestone) {
        // Immediately update local state
        if let index = localMilestones.firstIndex(where: { $0.id == milestone.id }) {
            localMilestones[index].isCompleted = true
            localMilestones[index].completedAt = Date()
        }
        
        // Update in viewModel
        viewModel.markMilestoneComplete(goal, milestoneId: milestone.id)
    }
}

// MARK: - Milestone Row
struct MilestoneRow: View {
    let milestone: GoalMilestone
    let goalProgress: Double
    let onMarkComplete: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var isAchievable: Bool {
        goalProgress >= milestone.targetProgress
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if isAchievable && !milestone.isCompleted {
                    onMarkComplete()
                }
            }) {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : (isAchievable ? "circle" : "circle.dashed"))
                    .foregroundColor(milestone.isCompleted ? ThemeColors.success : (isAchievable ? ThemeColors.accent : ThemeColors.secondaryText))
                    .font(.title3)
                    .overlay(
                        Circle()
                            .stroke(milestone.isCompleted ? ThemeColors.success : (isAchievable ? ThemeColors.accent : ThemeColors.secondaryText), lineWidth: 2)
                            .opacity(milestone.isCompleted ? 0 : 1)
                    )
                    .scaleEffect(milestone.isCompleted ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: milestone.isCompleted)
            }
            .disabled(!isAchievable || milestone.isCompleted)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                    .strikethrough(milestone.isCompleted)
                
                Text(milestone.description)
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                
                Text("Target: \(Int(milestone.targetProgress * 100))% progress")
                    .font(.caption2)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            Spacer()
            
            if milestone.isCompleted, let completedAt = milestone.completedAt {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Completed")
                        .font(.caption2)
                        .foregroundColor(ThemeColors.success)
                    
                    Text(completedAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            } else if isAchievable {
                Button("Mark Complete") {
                    onMarkComplete()
                }
                .font(.caption)
                .foregroundColor(ThemeColors.accent)
            }
        }
        .padding(.vertical, 4)
        .opacity(milestone.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Statistics Section
struct StatisticsSection: View {
    let goal: EmotionalGoal
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            HStack(spacing: 20) {
                StatisticCard(
                    title: "Days Active",
                    value: "\(daysSinceCreation)",
                    icon: "calendar",
                    color: ThemeColors.accent
                )
                
                StatisticCard(
                    title: "Milestones",
                    value: "\(goal.milestones.filter { $0.isCompleted }.count)/\(goal.milestones.count)",
                    icon: "flag.fill",
                    color: ThemeColors.success
                )
                
                if let daysRemaining = goal.daysRemaining {
                    StatisticCard(
                        title: "Days Left",
                        value: "\(daysRemaining)",
                        icon: "clock",
                        color: goal.isOverdue ? ThemeColors.error : ThemeColors.warning
                    )
                }
            }
            .padding()
            .themedCard()
        }
    }
    
    private var daysSinceCreation: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: goal.createdAt, to: Date()).day
        return max(days ?? 0, 0)
    }
}

// MARK: - Statistic Card
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ThemeColors.primaryText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Actions Section
struct ActionsSection: View {
    let goal: EmotionalGoal
    @Binding var showingProgressUpdate: Bool
    @Binding var showingDeleteConfirmation: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingProgressUpdate = true
            }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Update Progress")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ThemeColors.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Goal")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ThemeColors.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ThemeColors.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Progress Update View
struct ProgressUpdateView: View {
    let goal: EmotionalGoal
    let currentProgress: Double
    @ObservedObject var viewModel: GoalSettingViewModel
    let onProgressUpdated: (EmotionalGoal) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var newProgress: Double
    @State private var notes = ""
    
    init(goal: EmotionalGoal, currentProgress: Double, viewModel: GoalSettingViewModel, onProgressUpdated: @escaping (EmotionalGoal) -> Void) {
        self.goal = goal
        self.currentProgress = currentProgress
        self.viewModel = viewModel
        self.onProgressUpdated = onProgressUpdated
        self._newProgress = State(initialValue: currentProgress)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Update Progress")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(goal.title)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("Progress")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(Int(newProgress * 100))%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(goal.category.color)
                        }
                        
                        Slider(value: $newProgress, in: 0...1, step: 0.05)
                            .accentColor(goal.category.color)
                        
                        HStack {
                            Text("0%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("100%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.headline)
                        
                        TextField("Add any notes about your progress...", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: updateProgress) {
                    Text("Update Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(goal.category.color)
                        .cornerRadius(12)
                }
                .disabled(newProgress == currentProgress)
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updateProgress() {
        // Create updated goal with new progress and auto-complete milestones
        var updatedGoal = goal
        updatedGoal.progress = newProgress
        
        var completedMilestoneIds: [UUID] = []
        
        // Auto-complete milestones that have been reached
        for i in 0..<updatedGoal.milestones.count {
            if !updatedGoal.milestones[i].isCompleted && newProgress >= updatedGoal.milestones[i].targetProgress {
                updatedGoal.milestones[i].isCompleted = true
                updatedGoal.milestones[i].completedAt = Date()
                completedMilestoneIds.append(updatedGoal.milestones[i].id)
            }
        }
        
        // Update in viewModel with both progress and milestone completions
        if !completedMilestoneIds.isEmpty {
            viewModel.updateGoalProgressAndMilestones(goal, progress: newProgress, completedMilestones: completedMilestoneIds)
        } else {
            viewModel.updateGoalProgress(goal, progress: newProgress)
        }
        
        // Immediately update the UI
        onProgressUpdated(updatedGoal)
        
        dismiss()
    }
}

// MARK: - Preview
struct GoalDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleGoal = EmotionalGoal(
            title: "Daily Emotional Check-ins",
            description: "Build awareness by checking in with my emotions every day",
            category: .emotionalAwareness,
            targetDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            progress: 0.6,
            milestones: [
                GoalMilestone(title: "Week 1: Establish routine", description: "Complete daily check-ins for 7 days", targetProgress: 0.25, isCompleted: true),
                GoalMilestone(title: "Week 2: Identify patterns", description: "Notice emotional patterns", targetProgress: 0.5),
                GoalMilestone(title: "Week 3: Deepen awareness", description: "Understand triggers", targetProgress: 0.75),
                GoalMilestone(title: "Week 4: Integrate insights", description: "Apply learnings", targetProgress: 1.0)
            ]
        )
        
        GoalDetailView(goal: sampleGoal, viewModel: GoalSettingViewModel())
            .environmentObject(ThemeManager())
    }
}

