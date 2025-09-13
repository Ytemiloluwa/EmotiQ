//
//  CompletedGoalView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import SwiftUI
import CoreData
import Combine

// MARK: - Completed Goal View
struct CompletedGoalView: View {
    @StateObject private var viewModel = CompletedGoalViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.cyan.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if viewModel.completedGoals.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.completedGoals) { goal in
                                CompletedGoalCard(goal: goal)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Tab bar spacing
                    }
                }
            }
            .navigationTitle("Completed Goals")
            .navigationBarTitleDisplayMode(.large)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Done") {
//                        dismiss()
//                    }
//                }
//            }
            .onAppear {
                viewModel.loadCompletedGoals()
            }
        }
    }
}

// MARK: - Completed Goal Card
struct CompletedGoalCard: View {
    let goal: CompletedGoalData
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text(goal.category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(goal.category.color.opacity(0.2))
                        .foregroundColor(goal.category.color)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("100%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Completed")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.primaryText)
                }
            }
            
            // Description
            Text(goal.description)
                .font(.body)
                .foregroundColor(ThemeColors.primaryText)
                .lineLimit(3)
            
            // Statistics
            HStack(spacing: 20) {
                StatisticItem(
                    title: "Days Active",
                    value: "\(goal.daysActive)",
                    icon: "calendar"
                )
                
                StatisticItem(
                    title: "Milestones",
                    value: "\(goal.completedMilestones)/\(goal.totalMilestones)",
                    icon: "flag.fill"
                )
                
                StatisticItem(
                    title: "Created",
                    value: goal.createdDateString,
                    icon: "plus.circle"
                )
            }
            
            // Completion date
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Text("Completed on \(goal.completedDateString)")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
            }
            
            // Milestones section
            if !goal.milestones.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Milestones Achieved")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    ForEach(goal.milestones.sorted(by: { $0.targetProgress < $1.targetProgress })) { milestone in
                        HStack {
                            Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(milestone.isCompleted ? .green : .gray)
                                .font(.caption)
                            
                            Text(milestone.title)
                                .font(.subheadline)
                                .foregroundColor(ThemeColors.primaryText)
                            
                            Spacer()
                            
                            if milestone.isCompleted {
                                Text("\(Int(milestone.targetProgress * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ThemeColors.secondaryBackground)
                .shadow(
                    color: themeManager.isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(goal.category.color, lineWidth: 1.5)
        )
    }
}

// MARK: - Statistic Item
struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(ThemeColors.accent)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(ThemeColors.primaryText)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Completed Goals Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Text("Start setting and achieving your emotional wellness goals to see them here!")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Completed Goal Data Model
struct CompletedGoalData: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let category: GoalCategory
    let createdAt: Date
    let completedAt: Date
    let daysActive: Int
    let completedMilestones: Int
    let totalMilestones: Int
    let milestones: [MilestoneData]
    
    var createdDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
    
    var completedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: completedAt)
    }
}

struct MilestoneData: Identifiable {
    let id: UUID
    let title: String
    let targetProgress: Double
    let isCompleted: Bool
}

// MARK: - Completed Goal View Model
@MainActor
class CompletedGoalViewModel: ObservableObject {
    @Published var completedGoals: [CompletedGoalData] = []
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
    }
    
    func loadCompletedGoals() {
        guard let user = persistenceController.getCurrentUser() else {
     
            return
        }
        
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND isCompleted == YES", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GoalEntity.completedAt, ascending: false)]
        
        do {
            let goalEntities = try persistenceController.container.viewContext.fetch(request)
            completedGoals = goalEntities.compactMap { entity -> CompletedGoalData? in
                guard let id = entity.id,
                      let title = entity.title,
                      let description = entity.goalDescription,
                      let categoryString = entity.category,
                      let createdAt = entity.createdAt,
                      let completedAt = entity.completedAt else {
                    return nil
                }
                
                let milestones = (entity.milestones?.allObjects as? [MilestoneEntity])?.compactMap { milestoneEntity -> MilestoneData? in
                    guard let milestoneId = milestoneEntity.id,
                          let milestoneTitle = milestoneEntity.title else {
                        return nil
                    }
                    
                    return MilestoneData(
                        id: milestoneId,
                        title: milestoneTitle,
                        targetProgress: milestoneEntity.targetProgress,
                        isCompleted: milestoneEntity.isCompleted
                    )
                } ?? []
                
                let completedMilestones = milestones.filter { $0.isCompleted }.count
                let daysActive = Calendar.current.dateComponents([.day], from: createdAt, to: completedAt).day ?? 0
                
                guard let goalCategory = GoalCategory(rawValue: categoryString) else {
                    return nil
                }
                
                return CompletedGoalData(
                    id: id,
                    title: title,
                    description: description,
                    category: goalCategory,
                    createdAt: createdAt,
                    completedAt: completedAt,
                    daysActive: max(daysActive, 1),
                    completedMilestones: completedMilestones,
                    totalMilestones: milestones.count,
                    milestones: milestones
                )
            }
            
       
        } catch {
         
            completedGoals = []
        }
    }
    
    private func setupNotifications() {
        // Listen for goal completion
        NotificationCenter.default.publisher(for: .goalCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadCompletedGoals()
            }
            .store(in: &cancellables)
        
        // Listen for milestone completion
        NotificationCenter.default.publisher(for: .milestoneCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadCompletedGoals()
            }
            .store(in: &cancellables)
    }
    
}



// MARK: - Preview
struct CompletedGoalView_Previews: PreviewProvider {
    static var previews: some View {
        CompletedGoalView()
            .environmentObject(ThemeManager())
    }
}
