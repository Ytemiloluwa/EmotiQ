//
//  GoalCreationView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import SwiftUI

// MARK: - Goal Creation View
struct GoalCreationView: View {
    @ObservedObject var viewModel: GoalSettingViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: GoalCategory = .emotionalAwareness
    @State private var hasTargetDate = false
    @State private var targetDate = Date() // Default to current date
    @State private var milestones: [String] = [""]
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Header
                        GoalCreationHeaderView()
                        
                        // MARK: - Basic Information
                        BasicInformationSection(
                            title: $title,
                            description: $description,
                            selectedCategory: $selectedCategory
                        )
                        
                        // MARK: - Target Date
                        TargetDateSection(
                            hasTargetDate: $hasTargetDate,
                            targetDate: $targetDate
                        )
                        
                        // MARK: - Milestones
                        MilestonesSection(milestones: $milestones)
                        
                        // MARK: - Create Button
                        CreateGoalButton(action: createGoal)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Create Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColors.secondaryText)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK") { }
            } message: {
                Text(validationMessage)
            }
            .onAppear {
                if let category = viewModel.selectedCategory {
                    selectedCategory = category
                    viewModel.selectedCategory = nil
                }
            }
        }
    }
    
    private func createGoal() {
        // Validate input
        guard validateInput() else { return }
        
        // Create milestones
        let goalMilestones : [GoalMilestone] = milestones.enumerated().compactMap { (index, title) in
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return GoalMilestone(
                title: title,
                description: "Milestone \(index + 1)",
                targetProgress: Double(index + 1) / Double(milestones.count)
            )
        }
        
        // Create goal
        let goal = EmotionalGoal(
            title: title,
            description: description,
            category: selectedCategory,
            targetDate: hasTargetDate ? targetDate : nil,
            milestones: goalMilestones
        )
        
        // Save goal
        Task {
            await CoachingService.shared.createGoal(goal)
            await MainActor.run {
                viewModel.loadGoals()
                dismiss()
            }
        }
    }
    
    private func validateInput() -> Bool {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "Please enter a goal title"
            showingValidationError = true
            return false
        }
        
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "Please enter a goal description"
            showingValidationError = true
            return false
        }
        
        if hasTargetDate && targetDate <= Date() {
            validationMessage = "Target date must be in the future"
            showingValidationError = true
            return false
        }
        
        return true
    }
}

// MARK: - Goal Creation Header
struct GoalCreationHeaderView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Your Goal")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Define a meaningful objective for your emotional growth")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ThemeColors.accent)
            }
        }
        .padding()
        .themedCard()
    }
}

// MARK: - Basic Information Section
struct BasicInformationSection: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var selectedCategory: GoalCategory
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(spacing: 16) {
                // Title Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal Title")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    TextField("Enter your goal title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                }
                
                // Description Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    TextField("Describe what you want to achieve", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .font(.body)
                }
                
                // Category Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(GoalCategory.allCases, id: \.self) { category in
                                CategorySelectionButton(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            .padding()
            .themedCard()
        }
    }
}

// MARK: - Category Selection Button
struct CategorySelectionButton: View {
    let category: GoalCategory
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : ThemeColors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 80, height: 80)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color : category.color.opacity(themeManager.isDarkMode ? 0.2 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(category.color, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Target Date Section
struct TargetDateSection: View {
    @Binding var hasTargetDate: Bool
    @Binding var targetDate: Date
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Target Date")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(spacing: 16) {
                Toggle("Set a target date", isOn: $hasTargetDate)
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.primaryText)
                
                if hasTargetDate {
                    DatePicker(
                        "Target Date",
                        selection: $targetDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .font(.body)
                }
            }
            .padding()
            .themedCard()
        }
    }
}

// MARK: - Milestones Section
struct MilestonesSection: View {
    @Binding var milestones: [String]
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Milestones")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Button("Add Milestone") {
                    milestones.append("")
                }
                .font(.caption)
                .foregroundColor(ThemeColors.accent)
            }
            
            VStack(spacing: 12) {
                ForEach(milestones.indices, id: \.self) { index in
                    HStack {
                        TextField("Milestone \(index + 1)", text: $milestones[index])
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                        
                        if milestones.count > 1 {
                            Button(action: {
                                milestones.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(ThemeColors.error)
                                    .font(.title3)
                            }
                        }
                    }
                }
            }
            .padding()
            .themedCard()
        }
    }
}

// MARK: - Create Goal Button
struct CreateGoalButton: View {
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Create Goal")
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
    }
}

// MARK: - Preview
struct GoalCreationView_Previews: PreviewProvider {
    static var previews: some View {
        GoalCreationView(viewModel: GoalSettingViewModel())
            .environmentObject(ThemeManager())
    }
}

