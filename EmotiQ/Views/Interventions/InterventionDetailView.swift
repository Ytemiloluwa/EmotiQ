//
//  InterventionDetailView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Intervention Detail View
struct InterventionDetailView: View {
    let intervention: QuickIntervention
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var sessionViewModel = InterventionSessionViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColors.backgroundGradient
                    .ignoresSafeArea()
                
                if sessionViewModel.isActive {
                    // Active session view
                    InterventionSessionView(
                        intervention: intervention,
                        sessionViewModel: sessionViewModel,
                        onComplete: {
                            viewModel.completeIntervention(intervention)
                            dismiss()
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
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon and basic info
            HStack {
                Image(systemName: intervention.icon)
                    .font(.system(size: 50))
                    .foregroundColor(intervention.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(intervention.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text(intervention.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(ThemeColors.accent)
                        
                        Text("\(intervention.estimatedDuration) minutes")
                            .font(.subheadline)
                            .foregroundColor(ThemeColors.primaryText)
                    }
                }
                
                Spacer()
            }
            
            // Description
            Text(intervention.description)
                .font(.body)
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
                
                // Rating display
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    Text("4.8")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
        }
        .padding()
        .themedCard()
    }
}

// MARK: - Benefits Section
struct BenefitsSection: View {
    let benefits: [String]
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Benefits")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(benefits, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ThemeColors.success)
                            .font(.body)
                        
                        Text(benefit)
                            .font(.body)
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
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(ThemeColors.accent)
                            .clipShape(Circle())
                        
                        Text(instruction)
                            .font(.body)
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
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(preparationTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(ThemeColors.warning)
                            .font(.body)
                        
                        Text(tip)
                            .font(.body)
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
        Button(action: {
            sessionViewModel.startSession(intervention)
        }) {
            HStack {
                Image(systemName: "play.circle.fill")
                Text("Start \(intervention.title)")
            }
            .font(.headline)
            .fontWeight(.semibold)
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
                TimerDisplayView(
                    timeRemaining: sessionViewModel.timeRemaining,
                    totalTime: sessionViewModel.totalTime,
                    color: intervention.color
                )
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
                    .foregroundColor(ThemeColors.secondaryText)
                
                Spacer()
                
                Text("\(Int(sessionViewModel.progress * 100))% Complete")
                    .font(.caption)
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
                .foregroundColor(ThemeColors.secondaryText)
                .textCase(.uppercase)
                .tracking(1)
            
            Text(instruction)
                .font(.title2)
                .fontWeight(.medium)
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
                .foregroundColor(ThemeColors.secondaryText)
            
            Text(formatTime(timeRemaining))
                .font(.system(size: 48, weight: .light, design: .monospaced))
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
                    .font(.system(size: 60))
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

// MARK: - Intervention Session View Model
@MainActor
class InterventionSessionViewModel: ObservableObject {
    @Published var isActive = false
    @Published var isPaused = false
    @Published var currentStep = 0
    @Published var timeRemaining = 0
    @Published var showTimer = false
    
    private var intervention: QuickIntervention?
    private var timer: Timer?
    private var stepDuration = 30 // Default step duration in seconds
    
    var totalSteps: Int {
        intervention?.instructions.count ?? 0
    }
    
    var currentInstruction: String {
        guard let intervention = intervention,
              currentStep < intervention.instructions.count else {
            return "Complete"
        }
        return intervention.instructions[currentStep]
    }
    
    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }
    
    var totalTime: Int {
        stepDuration
    }
    
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
        showTimer = intervention.category == .breathing || intervention.category == .mindfulness
        
        if showTimer {
            startStepTimer()
        }
    }
    
    func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        currentStep += 1
        
        if showTimer {
            startStepTimer()
        }
    }
    
    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
        
        if showTimer {
            startStepTimer()
        }
    }
    
    func togglePlayPause() {
        isPaused.toggle()
        
        if isPaused {
            timer?.invalidate()
        } else if showTimer {
            startStepTimer()
        }
    }
    
    func completeSession() {
        timer?.invalidate()
        isActive = false
        currentStep = 0
    }
    
    private func startStepTimer() {
        timer?.invalidate()
        timeRemaining = stepDuration
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timer?.invalidate()
                // Auto-advance to next step
                if !self.isLastStep {
                    self.nextStep()
                }
            }
        }
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

