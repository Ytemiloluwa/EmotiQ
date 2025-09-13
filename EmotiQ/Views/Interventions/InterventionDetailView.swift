//
//  InterventionDetailView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import SwiftUI
import Combine
import UIKit
import CoreData

// MARK: - Intervention Detail View
// P1 models/helpers co-located for now for faster integration
fileprivate struct SessionStep: Identifiable, Equatable {
    enum SessionStepType { case generic, breathing }
    let id = UUID()
    let text: String
    let durationSec: Int
    let type: SessionStepType
    let breathing: (inhale: Int, hold: Int, exhale: Int)?
    static func == (lhs: SessionStep, rhs: SessionStep) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.durationSec == rhs.durationSec && lhs.typeCase == rhs.typeCase && lhs.breathingEq(rhs.breathing)
    }
    private var typeCase: Int { type == .breathing ? 1 : 0 }
    private func breathingEq(_ other: (inhale: Int, hold: Int, exhale: Int)?) -> Bool {
        switch (breathing, other) {
        case (nil, nil): return true
        case let (a?, b?): return a.inhale == b.inhale && a.hold == b.hold && a.exhale == b.exhale
        default: return false
        }
    }
}

final class InterventionCompletionStore {
    private let context: NSManagedObjectContext
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) { self.context = context }
    func recordCompletion(intervention: QuickIntervention, duration: Int, stepsCompleted: Int, totalSteps: Int, completedAt: Date = Date()) throws -> (streak: Int, isMilestone: Bool, objectID: NSManagedObjectID?) {
        let entity = InterventionCompletionEntity(context: context)
        entity.id = UUID()
        entity.title = intervention.title
        entity.interventionTitle = intervention.title
        entity.interventionType = intervention.category.displayName
        entity.category = intervention.category.displayName
        entity.completedAt = completedAt
        entity.duration = Int32(duration)
        entity.stepsCompleted = Int16(stepsCompleted)
        entity.totalSteps = Int16(totalSteps)
        try context.save()
        let streak = try computeCurrentStreak(referenceDate: completedAt)
        let isMilestone = streak == 7 || streak == 30
        return (streak, isMilestone, entity.objectID)
    }
    func computeCurrentStreak(referenceDate: Date = Date()) throws -> Int {
        let fetch: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
        let start = Calendar.current.date(byAdding: .day, value: -35, to: referenceDate) ?? referenceDate
        fetch.predicate = NSPredicate(format: "completedAt >= %@ AND completedAt <= %@", start as NSDate, referenceDate as NSDate)
        fetch.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        let results = try context.fetch(fetch)
        var set = Set<Date>()
        for item in results {
            if let d = item.completedAt { set.insert(Calendar.current.startOfDay(for: d)) }
        }
        let today = Calendar.current.startOfDay(for: referenceDate)
        var streak = 0
        var cursor = today
        while set.contains(cursor) {
            streak += 1
            if let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) { cursor = prev } else { break }
        }
        return streak
    }

    func countCompletionsThisWeek(forTitle title: String) throws -> Int {
        let fetch: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
        let cal = Calendar.current
        let today = Date()
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        fetch.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "interventionTitle == %@", title),
            NSPredicate(format: "completedAt >= %@", startOfWeek as NSDate),
            NSPredicate(format: "completedAt <= %@", today as NSDate)
        ])
        return try context.count(for: fetch)
    }
}



struct InterventionDetailView: View {
    let intervention: QuickIntervention
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var sessionViewModel = InterventionSessionViewModel()
    @State private var showCompletionSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColors.primaryBackground
                    .ignoresSafeArea()
                
                if sessionViewModel.isActive {
                    // Active session view
                    InterventionSessionView(
                        intervention: intervention,
                        sessionViewModel: sessionViewModel,
                        onComplete: {
                            viewModel.completeIntervention(intervention)
                            showCompletionSheet = true
                        }
                    )
                } else {
                    // Preparation view
                    InterventionPreparationView(
                        intervention: intervention,
                        sessionViewModel: sessionViewModel
                    )
                }
            }
            .navigationTitle(intervention.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColors.secondaryText)
                }
            }
            .onAppear {
                sessionViewModel.observeLifecycle()
                sessionViewModel.loadSavedProgress(for: intervention)
            }
            .onDisappear {
                sessionViewModel.persistIfNeeded()
            }
            .sheet(isPresented: $showCompletionSheet) {
                InterventionCompletionSheet(
                    intervention: intervention,
                    onDone: {
                        showCompletionSheet = false
                        dismiss()
                    },
                    onSubmitFeedback: { tags in
                        sessionViewModel.submitFeedbackTags(tags)
                    }
                )
                .environmentObject(themeManager)
            }
        }
    }
}

// MARK: - Intervention Preparation View
struct InterventionPreparationView: View {
    let intervention: QuickIntervention
    @ObservedObject var sessionViewModel: InterventionSessionViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Header
                InterventionHeaderCard(intervention: intervention)
                
                // MARK: - Benefits
                BenefitsSection(benefits: intervention.benefits)
                
                // MARK: - Instructions Preview
                InstructionsPreviewSection(instructions: intervention.instructions)
                
                // MARK: - Preparation Tips
                PreparationTipsSection(category: intervention.category)
                
                // MARK: - Start Button
                StartInterventionButton(
                    intervention: intervention,
                    sessionViewModel: sessionViewModel
                )
                
                // MARK: - Completed Interventions
                CompletedInterventionsSection(interventionTitle: intervention.title)
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Intervention Header Card
struct InterventionHeaderCard: View {
    let intervention: QuickIntervention
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var streakCount: Int = 0
    @State private var weeklyCount: Int = 0
    private let store = InterventionCompletionStore()
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon and basic info
            HStack {
                Image(systemName: intervention.icon)
                    .font(.system(size: 50))
                    .foregroundColor(intervention.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(intervention.title)
                        .font(.title2.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text(intervention.category.displayName)
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(ThemeColors.accent)
                        
                        Text("\(intervention.estimatedDuration) minutes")
                            .font(.subheadline)
                            .fontDesign(.rounded)
                            .foregroundColor(ThemeColors.primaryText)
                    }
                }
                
                Spacer()
            }
            
            // Description
            Text(intervention.description)
                .font(.body)
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            // Category badge
            HStack {
                Text(intervention.category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(intervention.color.opacity(0.2))
                    .foregroundColor(intervention.color)
                    .clipShape(Capsule())
                
                Spacer()
                
                HStack(spacing: 8) {
                    ProgressRingView(progress: min(Double(weeklyCount)/7.0, 1.0), label: "\(weeklyCount)/7", color: intervention.color)
                        .frame(width: 34, height: 34)
                    Text("🔥 \(streakCount)")
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundColor(ThemeColors.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ThemeColors.primaryBackground)
                        .clipShape(Capsule())
                    if streakCount >= 7 {
                        Text(streakCount >= 30 ? "🏆 30" : "🎖️ 7")
                            .font(.caption.weight(.semibold))
                            .fontDesign(.rounded)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(intervention.color.opacity(0.2))
                            .foregroundColor(intervention.color)
                            .clipShape(Capsule())
                    }
                    Text(headerHelpfulText)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
        }
        .padding()
        .themedCard()
        .onAppear {
            if let streak = try? store.computeCurrentStreak() { streakCount = streak }
            if let count = try? store.countCompletionsThisWeek(forTitle: intervention.title) { weeklyCount = count }
        }
    }

    private var headerHelpfulText: String {
        let store = UserDefaults.standard
        let like = store.integer(forKey: "iv_helpful_like_\(intervention.title)")
        let dislike = store.integer(forKey: "iv_helpful_dislike_\(intervention.title)")
        let total = like + dislike
        guard total > 0 else { return "New" }
        let pct = Int(round(Double(like) / Double(total) * 100))
        return "\(pct)% helpful"
    }
}

// MARK: - Benefits Section
struct BenefitsSection: View {
    let benefits: [String]
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Benefits")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(benefits, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ThemeColors.success)
                            .font(.body)
                        
                        Text(benefit)
                            .font(.body)
                            .fontDesign(.rounded)
                            .foregroundColor(ThemeColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .themedCard()
        }
    }
}

// MARK: - Instructions Preview Section
struct InstructionsPreviewSection: View {
    let instructions: [String]
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What You'll Do")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(ThemeColors.accent)
                            .clipShape(Circle())
                        
                        Text(instruction)
                            .font(.body)
                            .fontDesign(.rounded)
                            .foregroundColor(ThemeColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .themedCard()
        }
    }
}

// MARK: - Preparation Tips Section
struct PreparationTipsSection: View {
    let category: InterventionCategory
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preparation Tips")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(preparationTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(ThemeColors.warning)
                            .font(.body)
                        
                        Text(tip)
                            .font(.body)
                            .fontDesign(.rounded)
                            .foregroundColor(ThemeColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .themedCard()
        }
    }
    
    private var preparationTips: [String] {
        switch category {
        case .breathing:
            return [
                "Find a comfortable seated position",
                "Ensure you won't be interrupted",
                "Loosen any tight clothing",
                "Have water nearby if needed"
            ]
        case .mindfulness:
            return [
                "Choose a quiet space",
                "Turn off notifications",
                "Sit comfortably with good posture",
                "Set an intention for your practice"
            ]
        case .movement:
            return [
                "Wear comfortable clothing",
                "Clear some space around you",
                "Have a yoga mat or towel if available",
                "Listen to your body's limits"
            ]
        case .cognitive:
            return [
                "Have a journal or notes app ready",
                "Find a quiet thinking space",
                "Be honest and open with yourself",
                "Remember there are no wrong answers"
            ]
        case .social:
            return [
                "Think of specific people in your life",
                "Open your heart to compassion",
                "Start with easier relationships",
                "Be patient with the process"
            ]
        case .creativity:
            return [
                "Gather any materials you might need",
                "Let go of perfectionism",
                "Embrace playfulness and curiosity",
                "Focus on the process, not the outcome"
            ]
        case .stressManagement:
            return [
                "Acknowledge that stress is normal",
                "Focus on what you can control",
                "Be gentle with yourself",
                "Remember this is practice, not perfection"
            ]
        case .energyBoost:
            return [
                "Ensure you're well-hydrated",
                "Stand up if you've been sitting",
                "Take a few deep breaths first",
                "Set an energizing intention"
            ]
        }
    }
}

// MARK: - Start Intervention Button
struct StartInterventionButton: View {
    let intervention: QuickIntervention
    @ObservedObject var sessionViewModel: InterventionSessionViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            if sessionViewModel.hasSavedProgress(for: intervention) {
                Button(action: {
                    HapticManager.shared.buttonPress(.primary)
                    sessionViewModel.resumeSession(intervention)
                }) {
                    HStack {
                        Image(systemName: "gobackward")
                        Text("Resume Session")
                    }
                    .font(.headline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [intervention.color, intervention.color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
            Button(action: {
                HapticManager.shared.buttonPress(.standard)
                sessionViewModel.startSession(intervention)
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text(sessionViewModel.hasSavedProgress(for: intervention) ? "Start Over" : "Start \(intervention.title)")
                }
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [intervention.color, intervention.color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Intervention Session View
struct InterventionSessionView: View {
    let intervention: QuickIntervention
    @ObservedObject var sessionViewModel: InterventionSessionViewModel
    let onComplete: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 32) {
            // Progress indicator
            SessionProgressView(sessionViewModel: sessionViewModel)
            
            // Current instruction
            CurrentInstructionView(
                instruction: sessionViewModel.currentInstruction,
                color: intervention.color
            )
            
            // Timer display
            if sessionViewModel.showTimer {
                if sessionViewModel.isBreathingStep {
                    BreathingTimerView(
                        phase: sessionViewModel.breathingPhase,
                        seconds: sessionViewModel.breathingPhaseRemaining,
                        color: intervention.color
                    )
                } else {
                    TimerDisplayView(
                        timeRemaining: sessionViewModel.timeRemaining,
                        totalTime: sessionViewModel.totalTime,
                        color: intervention.color
                    )
                }
            }
            
            // Controls
            SessionControlsView(
                sessionViewModel: sessionViewModel,
                onComplete: onComplete,
                color: intervention.color
            )
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Session Progress View
struct SessionProgressView: View {
    @ObservedObject var sessionViewModel: InterventionSessionViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Step \(sessionViewModel.currentStep + 1) of \(sessionViewModel.totalSteps)")
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundColor(ThemeColors.secondaryText)
                
                Spacer()
                
                Text("\(Int(sessionViewModel.progress * 100))% Complete")
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            ProgressView(value: sessionViewModel.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: ThemeColors.accent))
                .scaleEffect(y: 1.5)
        }
    }
}

// MARK: - Current Instruction View
struct CurrentInstructionView: View {
    let instruction: String
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Current Step")
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.secondaryText)
                .textCase(.uppercase)
                .tracking(1)
            
            Text(instruction)
                .font(.title2.weight(.medium))
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(themeManager.isDarkMode ? 0.2 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Timer Display View
struct TimerDisplayView: View {
    let timeRemaining: Int
    let totalTime: Int
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Time Remaining")
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.secondaryText)
            
            Text(formatTime(timeRemaining))
                .font(.system(size: 48, weight: .regular, design: .rounded))
                .foregroundColor(color)
            
            ProgressView(value: Double(totalTime - timeRemaining), total: Double(totalTime))
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 2)
        }
        .padding()
        .themedCard()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Breathing Timer View
struct BreathingTimerView: View {
    let phase: InterventionSessionViewModel.BreathingPhase?
    let seconds: Int
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text(phaseTitle)
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.secondaryText)
            
            Text("\(seconds)s")
                .font(.system(size: 48, weight: .regular, design: .rounded))
                .foregroundColor(color)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 2)
        }
        .padding()
        .themedCard()
    }
    
    private var phaseTitle: String {
        switch phase {
        case .inhale?: return "Inhale"
        case .hold1?: return "Hold"
        case .exhale?: return "Exhale"
        case .hold2?: return "Hold"
        default: return "Breathing"
        }
    }
    
    private var phaseTotal: Double {
        switch phase {
        case .inhale?: return 4
        case .hold1?: return 4
        case .exhale?: return 4
        case .hold2?: return 4
        default: return 4
        }
    }
    
    private var progress: Double {
        guard seconds >= 0 else { return 0 }
        return Double(4 - min(seconds, 4)) / phaseTotal
    }
}

// MARK: - Session Controls View
struct SessionControlsView: View {
    @ObservedObject var sessionViewModel: InterventionSessionViewModel
    let onComplete: () -> Void
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Previous button
            Button(action: {
                sessionViewModel.previousStep()
            }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title)
                    .foregroundColor(sessionViewModel.canGoPrevious ? color : ThemeColors.secondaryText)
            }
            .disabled(!sessionViewModel.canGoPrevious)
            
            // Play/Pause button
            Button(action: {
                sessionViewModel.togglePlayPause()
            }) {
                Image(systemName: sessionViewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 60, weight: .regular, design: .rounded))
                    .foregroundColor(color)
            }
            
            // Next/Complete button
            Button(action: {
                if sessionViewModel.isLastStep {
                    sessionViewModel.completeSession()
                    onComplete()
                } else {
                    sessionViewModel.nextStep()
                }
            }) {
                Image(systemName: sessionViewModel.isLastStep ? "checkmark.circle.fill" : "chevron.right.circle.fill")
                    .font(.title)
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - Completion Sheet
struct InterventionCompletionSheet: View {
    let intervention: QuickIntervention
    let onDone: () -> Void
    var onSubmitFeedback: ([String]) -> Void = { _ in }
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selected: Set<String> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundColor(ThemeColors.success)
                
                Text("Great job!")
                    .font(.title.weight(.semibold))
                    .fontDesign(.rounded)
                
                Text("You completed \(intervention.title)")
                    .font(.body)
                    .fontDesign(.rounded)
                    .foregroundColor(ThemeColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    ForEach(["Helpful", "Soothing", "Too long", "Not helpful"], id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .fontDesign(.rounded)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selected.contains(tag) ? ThemeColors.accent : ThemeColors.accent.opacity(0.12))
                            .foregroundColor(selected.contains(tag) ? .white : ThemeColors.accent)
                            .clipShape(Capsule())
                            .onTapGesture { if selected.contains(tag) { selected.remove(tag) } else { selected.insert(tag) } }
                    }
                }
                .padding(.top, 8)
                
                Spacer()
                
                Button(action: { onSubmitFeedback(Array(selected)); onDone() }) {
                    Text("Done")
                        .font(.headline.weight(.semibold))
                        .fontDesign(.rounded)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ThemeColors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Completed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Completed Section View
struct CompletedSectionView: View {
    let section: (section: String, items: [InterventionCompletionEntity])
    let interventionTitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.section)
                .font(.caption.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.secondaryText)
            ForEach(section.items, id: \.objectID) { item in
                CompletedItemView(item: item, interventionTitle: interventionTitle)
            }
        }
    }
}

// MARK: - Completed Item View
struct CompletedItemView: View {
    let item: InterventionCompletionEntity
    let interventionTitle: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(ThemeColors.success)
            Text(item.interventionTitle ?? interventionTitle)
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.primaryText)
            Spacer()
            if item.duration > 0 {
                Text("\(item.duration/60)m")
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundColor(ThemeColors.secondaryText)
            }
        }
        .padding(10)
        .background(ThemeColors.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Progress Ring
struct ProgressRingView: View {
    let progress: Double
    let label: String
    let color: Color
    var body: some View {
        ZStack {
            Circle()
                .stroke(ThemeColors.cardGradient, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(ThemeColors.primaryText)
        }
    }
}

// MARK: - Intervention Session View Model
@MainActor
class InterventionSessionViewModel: ObservableObject {
    @Published var isActive = false
    @Published var isPaused = false
    @Published var currentStep = 0
    @Published var timeRemaining = 0
    @Published var showTimer = false
    @Published var canResume = false
    
    private var intervention: QuickIntervention?
    private var timer: Timer?
    private var steps: [SessionStep] = []
    private var stepDuration = 30 // Fallback
    private var endAt: Date?
    private var cancellables = Set<AnyCancellable>()
    private let completionStore = InterventionCompletionStore()
    private var lastCompletionObjectID: NSManagedObjectID?
    enum BreathingPhase { case inhale, hold1, exhale, hold2 }
    @Published var breathingPhase: BreathingPhase? = nil
    @Published var breathingPhaseRemaining: Int = 0
    
    var totalSteps: Int { steps.count }
    
    var currentInstruction: String {
        guard currentStep < steps.count else { return "Complete" }
        if isBreathingStep, let pattern = steps[currentStep].breathing {
            switch breathingPhase {
            case .inhale?: return "Inhale for \(pattern.inhale)"
            case .hold1?: return "Hold for \(pattern.hold)"
            case .exhale?: return "Exhale for \(pattern.exhale)"
            case .hold2?: return "Hold for \(pattern.hold)"
            default: return steps[currentStep].text
            }
        }
        return steps[currentStep].text
    }
    
    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }
    
    var totalTime: Int { steps.isEmpty ? stepDuration : steps[currentStep].durationSec }
    
    var canGoPrevious: Bool {
        currentStep > 0
    }
    
    var isLastStep: Bool {
        currentStep >= totalSteps - 1
    }
    
    func startSession(_ intervention: QuickIntervention) {
        self.intervention = intervention
        isActive = true
        currentStep = 0
        // Build steps from instructions with sensible defaults
        self.steps = intervention.instructions.map { text in
            if intervention.category == .breathing {
                return SessionStep(text: text, durationSec: 60, type: .breathing, breathing: (inhale: 4, hold: 4, exhale: 4))
            } else {
                return SessionStep(text: text, durationSec: 30, type: .generic, breathing: nil)
            }
        }
        showTimer = true
        HapticManager.shared.buttonPress(.primary)
        
        if showTimer {
            startStepTimer()
        }
        saveProgress()
        log("session_started")
    }
    
    func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        currentStep += 1
        HapticManager.shared.selection()
        
        if showTimer {
            startStepTimer()
        }
        saveProgress()
        log("step_next_\(currentStep)")
    }
    
    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
        HapticManager.shared.selection()
        
        if showTimer {
            startStepTimer()
        }
        saveProgress()
        log("step_prev_\(currentStep)")
    }
    
    func togglePlayPause() {
        isPaused.toggle()
        
        if isPaused {
            timer?.invalidate()
            saveProgress()
        } else if showTimer {
            startStepTimer()
        }
        log(isPaused ? "paused" : "resumed")
    }
    
    func completeSession() {
        timer?.invalidate()
        isActive = false
        currentStep = 0
        clearProgress()
        HapticManager.shared.celebration(.goalCompleted)
        let durationSpent = (steps.isEmpty ? stepDuration : steps[0].durationSec) * max(currentStep, 1)
        if let iv = intervention {
            do {
                let result = try completionStore.recordCompletion(
                    intervention: iv,
                    duration: durationSpent,
                    stepsCompleted: currentStep,
                    totalSteps: totalSteps
                )
                lastCompletionObjectID = result.objectID
                Task { @MainActor in
                    await OneSignalService.shared.sendStreakNotification(streak: result.streak, interventionTitle: iv.title, isMilestone: result.isMilestone)
                }
            } catch {
               
            }
        }
        log("completed")
    }
    
    private func startStepTimer() {
        timer?.invalidate()
        let duration = steps.isEmpty ? stepDuration : steps[currentStep].durationSec
        endAt = Date().addingTimeInterval(TimeInterval(duration))
        updateTimeRemaining()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateTimeRemaining()
            if self.isBreathingStep {
                self.advanceBreathingPhaseTick()
            }
            if self.timeRemaining <= 0 {
                self.timer?.invalidate()
                if !self.isLastStep {
                    self.nextStep()
                }
            }
        }
        if isBreathingStep { startBreathingCycle() } else { breathingPhase = nil }
    }
    
    private func updateTimeRemaining() {
        let remaining = Int(max(0, (endAt ?? Date()).timeIntervalSinceNow))
        timeRemaining = remaining
    }
    
    // MARK: - Persistence
    private var store: UserDefaults { .standard }
    private var keyPrefix: String { "intervention_session_" }
    
    func hasSavedProgress(for intervention: QuickIntervention) -> Bool {
        let title = intervention.title
        return store.string(forKey: keyPrefix + "title") == title && store.bool(forKey: keyPrefix + "active")
    }
    
    func resumeSession(_ intervention: QuickIntervention) {
        loadSavedProgress(for: intervention)
        if isActive && showTimer { startStepTimer() }
        HapticManager.shared.buttonPress(.primary)
        log("resumed_button")
    }
    
    func loadSavedProgress(for intervention: QuickIntervention) {
        guard store.string(forKey: keyPrefix + "title") == intervention.title,
              store.bool(forKey: keyPrefix + "active") else { return }
        self.intervention = intervention
        self.steps = intervention.instructions.map { SessionStep(text: $0, durationSec: 30, type: intervention.category == .breathing ? .breathing : .generic, breathing: intervention.category == .breathing ? (4,4,4) : nil) }
        self.isActive = store.bool(forKey: keyPrefix + "active")
        self.currentStep = min(store.integer(forKey: keyPrefix + "step"), max(steps.count - 1, 0))
        self.showTimer = true
        let endAtInterval = store.double(forKey: keyPrefix + "endAt")
        if endAtInterval > 0 { self.endAt = Date(timeIntervalSince1970: endAtInterval) }
        updateTimeRemaining()
        canResume = true
    }

    var isBreathingStep: Bool {
        guard currentStep < steps.count else { return false }
        return steps[currentStep].type == .breathing
    }

    private func startBreathingCycle() {
        guard isBreathingStep, let pattern = steps[currentStep].breathing else { return }
        breathingPhase = .inhale
        breathingPhaseRemaining = pattern.inhale
    }

    private func advanceBreathingPhaseTick() {
        guard isBreathingStep, let pattern = steps[currentStep].breathing else { return }
        if breathingPhaseRemaining > 0 {
            breathingPhaseRemaining -= 1
            return
        }
        switch breathingPhase {
        case .inhale:
            breathingPhase = .hold1
            breathingPhaseRemaining = pattern.hold
        case .hold1:
            breathingPhase = .exhale
            breathingPhaseRemaining = pattern.exhale
        case .exhale:
            breathingPhase = .hold2
            breathingPhaseRemaining = pattern.hold
        case .hold2:
            breathingPhase = .inhale
            breathingPhaseRemaining = pattern.inhale
        case .none:
            breathingPhase = .inhale
            breathingPhaseRemaining = pattern.inhale
        }
    }
    
    func saveProgress() {
        guard let intervention = intervention else { return }
        store.set(true, forKey: keyPrefix + "active")
        store.set(intervention.title, forKey: keyPrefix + "title")
        store.set(currentStep, forKey: keyPrefix + "step")
        store.set(showTimer, forKey: keyPrefix + "showTimer")
        store.set(endAt?.timeIntervalSince1970 ?? 0, forKey: keyPrefix + "endAt")
    }
    
    func clearProgress() {
        ["active","title","step","showTimer","endAt"].forEach { store.removeObject(forKey: keyPrefix + $0) }
        canResume = false
    }
    
    func persistIfNeeded() {
        if isActive { saveProgress() }
        timer?.invalidate()
    }
    
    // MARK: - Lifecycle
    func observeLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.persistIfNeeded() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isActive, self.showTimer else { return }
                self.startStepTimer()
            }
            .store(in: &cancellables)
    }

    func submitFeedbackTags(_ tags: [String]) {
        guard let iv = intervention else { return }
        Task { @MainActor in
            await OneSignalService.shared.sendFeedback(tags: tags, interventionTitle: iv.title)
        }
        if let objectID = lastCompletionObjectID {
            do {
                let context = PersistenceController.shared.container.viewContext
                if let obj = try context.existingObject(with: objectID) as? InterventionCompletionEntity {
                    if let tag = tags.first {
                        switch tag.lowercased() {
                        case "helpful": obj.effectivenessRating = 5
                        case "soothing": obj.effectivenessRating = 4
                        case "too long": obj.effectivenessRating = 2
                        case "not helpful": obj.effectivenessRating = 1
                        default: break
                        }
                        obj.notes = tags.joined(separator: ",")
                        try context.save()
                    }
                }
            } catch {
             
            }
        }
    }
    
    // MARK: - Analytics (lightweight)
    private func log(_ name: String) {
   
    }
}

// MARK: - Preview
struct InterventionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleIntervention = QuickIntervention(
            title: "5-4-3-2-1 Grounding",
            description: "Ground yourself using your five senses",
            category: .mindfulness,
            icon: "hand.raised.fill",
            color: .green,
            estimatedDuration: 3,
            instructions: [
                "Notice 5 things you can see",
                "Notice 4 things you can touch",
                "Notice 3 things you can hear",
                "Notice 2 things you can smell",
                "Notice 1 thing you can taste"
            ],
            benefits: ["Reduces anxiety", "Increases present-moment awareness", "Calms the nervous system"]
        )
        
        InterventionDetailView(
            intervention: sampleIntervention,
            viewModel: MicroInterventionsViewModel()
        )
        .environmentObject(ThemeManager())
    }
}

struct CompletedInterventionsSection: View {
    let interventionTitle: String
    @State private var entries: [(section: String, items: [InterventionCompletionEntity])] = []
    private let context = PersistenceController.shared.container.viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed Sessions")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundColor(ThemeColors.primaryText)
            if entries.isEmpty {
                Text("No sessions yet. Your completions will appear here.")
                    .font(.subheadline)
                    .fontDesign(.rounded)
                    .foregroundColor(ThemeColors.secondaryText)
            } else {
                VStack(spacing: 12) {
                    ForEach(entries, id: \.section) { section in
                        CompletedSectionView(section: section, interventionTitle: interventionTitle)
                    }
                }
            }
        }
        .padding()
        .themedCard()
        .onAppear { reload() }
    }
    
    private func reload() {
        let fetch: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
        fetch.predicate = NSPredicate(format: "interventionTitle == %@", interventionTitle)
        fetch.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        do {
            let items = try context.fetch(fetch)
            let grouped = Dictionary(grouping: items) { item -> String in
                friendlyDate(item.completedAt)
            }
            entries = grouped.keys.sorted(by: friendlyDateSort).map { key in
                (section: key, items: grouped[key] ?? [])
            }
        } catch {
            entries = []
        }
    }
    
    private func friendlyDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day, days < 7 {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE"
            return fmt.string(from: date)
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/dd/yyyy"
        return fmt.string(from: date)
    }
    
    private func friendlyDateSort(_ a: String, _ b: String) -> Bool {
        let order: [String: Int] = ["Today": 0, "Yesterday": 1]
        let aVal = order[a] ?? 2
        let bVal = order[b] ?? 2
        if aVal != bVal { return aVal < bVal }
        // For weekday or date strings, we can't reliably parse here; keep original fetch order
        return true
    }
}

