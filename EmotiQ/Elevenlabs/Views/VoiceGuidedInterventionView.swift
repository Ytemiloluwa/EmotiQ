//
//  VoiceGuidedInterventionView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI

struct VoiceGuidedInterventionView: View {
    let intervention: VoiceGuidedIntervention?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var audioPlayer = CachedAudioPlayer()
    @StateObject private var interventionService = VoiceGuidedInterventionService.shared
    
    @State private var selectedTab: InterventionTab = .breathingExercises
    @State private var selectedIntervention: VoiceGuidedIntervention?
    @State private var currentStep = 0
    @State private var isPlaying = false
    @State private var showingCompletion = false
    @State private var effectivenessRating = 0
    @State private var sessionStartTime = Date()
    @State private var breathingPhase: BreathingPhase = .inhale
    @State private var breathingTimer: Timer?
    @State private var breathingProgress: Double = 0
    
    enum InterventionTab: String, CaseIterable {
        case breathingExercises = "Breathing"
        case emotionalPrompts = "Emotional"
        case quickRelief = "Quick Relief"
        
        var displayName: String {
            switch self {
            case .breathingExercises: return "Breathing"
            case .emotionalPrompts: return "Emotional"
            case .quickRelief: return "Quick Relief"
            }
        }
        
        var interventions: [VoiceGuidedIntervention] {
            switch self {
            case .breathingExercises: return VoiceGuidedIntervention.breathingExercises
            case .emotionalPrompts: return VoiceGuidedIntervention.emotionalPrompts
            case .quickRelief: return VoiceGuidedIntervention.quickRelief
            }
        }
    }
    
    enum BreathingPhase {
        case inhale, hold, exhale, pause
        
        var instruction: String {
            switch self {
            case .inhale: return "Breathe In"
            case .hold: return "Hold"
            case .exhale: return "Breathe Out"
            case .pause: return "Pause"
            }
        }
        
        var color: Color {
            switch self {
            case .inhale: return .blue
            case .hold: return .purple
            case .exhale: return .green
            case .pause: return .gray
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                ThemeColors.backgroundGradient
                .ignoresSafeArea()
                
                if let selectedIntervention = selectedIntervention {
                    // Show detailed intervention view
                    interventionDetailView(for: selectedIntervention)
                } else {
                    // Show intervention selection view
                    interventionSelectionView
                }
            }
            .navigationTitle(selectedIntervention?.title ?? "Voice Guided Reliefs")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(selectedIntervention != nil)
            .toolbar {
                if selectedIntervention != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            selectedIntervention = nil
                            audioPlayer.stop()
                            stopBreathingTimer()
                            currentStep = 0
                            isPlaying = false
                            effectivenessRating = 0
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(ThemeColors.primaryText)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCompletion) {
                if let selectedIntervention = selectedIntervention {
                    InterventionCompletionView(
                        intervention: selectedIntervention,
                        duration: Date().timeIntervalSince(sessionStartTime),
                        rating: $effectivenessRating,
                        onComplete: completeIntervention
                    )
                }
            }
            .onAppear {
                if let providedIntervention = intervention {
                    selectedIntervention = providedIntervention
                    sessionStartTime = Date()
                    startIntervention()
                }
            }
            .onDisappear {
                stopBreathingTimer()
            }
        }
    }
    
    // MARK: - Intervention Selection View
    
    private var interventionSelectionView: some View {
        VStack(spacing: 0) {
            // Segmented Control
            segmentedControlSection
            
            // Intervention List
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(selectedTab.interventions) { intervention in
                        InterventionCardView(intervention: intervention) {
                            selectedIntervention = intervention
                            sessionStartTime = Date()
                            startIntervention()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Segmented Control Section
    
    private var segmentedControlSection: some View {
        VStack(spacing: 16) {
            // Title
            Text("Choose your voice guided relief")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ThemeColors.primaryText)
                .padding(.top, 20)
            
            // Segmented Control
            Picker("Intervention Type", selection: $selectedTab) {
                ForEach(InterventionTab.allCases, id: \.self) { tab in
                    Text(tab.displayName)
                        .tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
        .background(
            ThemeColors.backgroundGradient
                .ignoresSafeArea(.all, edges: .top)
        )
    }
    
    // MARK: - Intervention Detail View
    
    private func interventionDetailView(for intervention: VoiceGuidedIntervention) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection(for: intervention)
                
                // Progress Indicator
                progressSection
                
                // Main Content
                if intervention.category == .breathing {
                    breathingVisualization
                } else {
                    contentSection(for: intervention)
                }
                
                // Audio Controls
                audioControlsSection
                
                // Navigation Controls
                navigationControlsSection(for: intervention)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Header Section
    
    private func headerSection(for intervention: VoiceGuidedIntervention) -> some View {
        VStack(spacing: 16) {
            // Intervention Icon
            Image(systemName: intervention.icon)
                .font(.system(size: 48))
                .foregroundColor(getInterventionColor(intervention.category))
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(getInterventionColor(intervention.category).opacity(0.2))
                        .shadow(color: getInterventionColor(intervention.category).opacity(0.3), radius: 15, x: 0, y: 8)
                )
            
            VStack(spacing: 8) {
                Text(intervention.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeColors.primaryText)
                    .multilineTextAlignment(.center)
                
                Text(intervention.description)
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            if let selectedIntervention = selectedIntervention {
                // Step Progress
                HStack {
                    Text("Step \(currentStep + 1) of \(selectedIntervention.steps.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    Spacer()
                    
                    Text(formatDuration(Date().timeIntervalSince(sessionStartTime)))
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                // Progress Bar
                ProgressView(value: Double(currentStep + 1), total: Double(selectedIntervention.steps.count))
                    .tint(getInterventionColor(selectedIntervention.category))
                    .scaleEffect(y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColors.secondaryBackground.opacity(0.7))
        )
    }
    
    // MARK: - Content Section
    
    private func contentSection(for intervention: VoiceGuidedIntervention) -> some View {
        VStack(spacing: 20) {
            if currentStep < intervention.steps.count {
                let step = intervention.steps[currentStep]
                
                VStack(spacing: 16) {
                    // Step Title
                    Text(step.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    // Step Content
                    Text(step.instruction)
                        .font(.body)
                        .foregroundColor(ThemeColors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ThemeColors.secondaryBackground)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
            }
        }
    }
    
    // MARK: - Breathing Visualization
    
    private var breathingVisualization: some View {
        VStack(spacing: 32) {
            // Breathing Circle
            ZStack {
                // Outer ring
                Circle()
                    .stroke(breathingPhase.color.opacity(0.3), lineWidth: 4)
                    .frame(width: 200, height: 200)
                
                // Animated breathing circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                breathingPhase.color.opacity(0.8),
                                breathingPhase.color.opacity(0.4)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: breathingProgress * 160 + 40, height: breathingProgress * 160 + 40)
                    .animation(.easeInOut(duration: getBreathingDuration()), value: breathingProgress)
                
                // Phase instruction
                VStack(spacing: 8) {
                    Text(breathingPhase.instruction)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(String(format: "%.0f", breathingProgress * getBreathingDuration()))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Breathing Instructions
            VStack(spacing: 12) {
                Text("Follow the circle with your breath")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                
                Text("Circle grows: Inhale • Circle shrinks: Exhale")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ThemeColors.secondaryBackground)
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
        )
    }
    
    // MARK: - Audio Controls Section
    
    private var audioControlsSection: some View {
        VStack(spacing: 16) {
            // Waveform Visualization
                                HStack(spacing: 2) {
                        ForEach(0..<30, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(
                                    isPlaying
                                    ? (selectedIntervention != nil ? getInterventionColor(selectedIntervention!.category).opacity(Double.random(in: 0.3...1.0)) : ThemeColors.secondaryText.opacity(0.3))
                                    : ThemeColors.secondaryText.opacity(0.3)
                                )
                                .frame(width: 3, height: CGFloat.random(in: 6...24))
                                .animation(
                                    .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.03),
                                    value: isPlaying
                                )
                        }
                    }
            .frame(height: 30)
            
            // Playback Controls
            HStack(spacing: 24) {
                // Previous Step
                Button {
                    previousStep()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(currentStep > 0 ? ThemeColors.primaryText : ThemeColors.secondaryText.opacity(0.5))
                }
                .disabled(currentStep == 0)
                .hapticFeedback(.standard)
                
                // Play/Pause
                Button {
                    if isPlaying {
                        audioPlayer.pause()
                    } else {
                        playCurrentStep()
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(selectedIntervention != nil ? getInterventionColor(selectedIntervention!.category) : .blue)
                        .shadow(color: (selectedIntervention != nil ? getInterventionColor(selectedIntervention!.category) : .blue).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .hapticFeedback(.primary)
                .scaleEffect(isPlaying ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
                .disabled(!ElevenLabsService.shared.isVoiceCloned)
                
                // Next Step
                Button {
                    nextStep()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor((selectedIntervention != nil && currentStep < selectedIntervention!.steps.count - 1) ? ThemeColors.primaryText : ThemeColors.secondaryText.opacity(0.5))
                }
                .disabled(selectedIntervention == nil || currentStep >= selectedIntervention!.steps.count - 1)
                .hapticFeedback(.standard)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ThemeColors.secondaryBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onReceive(audioPlayer.$isPlaying) { playing in
            isPlaying = playing
        }
    }
    
    // MARK: - Navigation Controls Section
    
    private func navigationControlsSection(for intervention: VoiceGuidedIntervention) -> some View {
        VStack(spacing: 16) {
            if currentStep >= intervention.steps.count - 1 {
                // Complete Button
                Button {
                    showingCompletion = true
                    HapticManager.shared.celebration(.goalCompleted)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Complete Session")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                getInterventionColor(intervention.category),
                                getInterventionColor(intervention.category).opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .hapticFeedback(.primary)
            } else {
                // Continue Button
                Button {
                    nextStep()
                } label: {
                    HStack {
                        Text("Continue")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                getInterventionColor(intervention.category),
                                getInterventionColor(intervention.category).opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .hapticFeedback(.primary)
            }
            
            // Skip Button
            Button {
                if currentStep < intervention.steps.count - 1 {
                    nextStep()
                } else {
                    showingCompletion = true
                }
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            .hapticFeedback(.standard)
        }
    }
    
    // MARK: - Visual Aid View (Removed - not needed for current implementation)
    
    // MARK: - Actions
    
    private func startIntervention() {
        guard let selectedIntervention = selectedIntervention else { return }
        
        if selectedIntervention.category == .breathing {
            startBreathingTimer()
        }
        playCurrentStep()
    }
    
    private func playCurrentStep() {
        guard let selectedIntervention = selectedIntervention,
              currentStep < selectedIntervention.steps.count else { return }
        
        let step = selectedIntervention.steps[currentStep]
        
        Task {
            do {
                // Find the voice prompt for this step
                if let voicePromptId = step.voicePromptId,
                   let voicePrompt = selectedIntervention.voicePrompts.first(where: { $0.id == voicePromptId }) {
                    try await audioPlayer.playAudio(
                        text: voicePrompt.text,
                        emotion: .neutral
                    )
                }
            } catch ElevenLabsError.noVoiceProfile {
                // User doesn't have voice profile set up
                print("🔧 Voice profile required for voice guided intervention")
                HapticManager.shared.notification(.warning)
                // Could show an alert here to guide user to voice setup
            } catch {
                print("Failed to play step audio: \(error)")
                HapticManager.shared.notification(.error)
            }
        }
    }
    
    private func nextStep() {
        guard let selectedIntervention = selectedIntervention,
              currentStep < selectedIntervention.steps.count - 1 else { return }
        
        currentStep += 1
        playCurrentStep()
        
        HapticManager.shared.navigationTransition()
    }
    
    private func previousStep() {
        guard currentStep > 0 else { return }
        
        currentStep -= 1
        playCurrentStep()
        
        HapticManager.shared.navigationTransition()
    }
    
    private func exitIntervention() {
        audioPlayer.stop()
        stopBreathingTimer()
        dismiss()
        
        HapticManager.shared.buttonPress(.subtle)
    }
    
    private func completeIntervention() {
        // Save completion data
        Task {
            // TODO: Implement intervention completion tracking
            if let selectedIntervention = selectedIntervention {
                print("Intervention completed: \(selectedIntervention.title)")
            }
        }
        
        dismiss()
        HapticManager.shared.celebration(.goalCompleted)
    }
    
    // MARK: - Breathing Timer
    
    private func startBreathingTimer() {
        stopBreathingTimer()
        
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateBreathingAnimation()
        }
    }
    
    private func stopBreathingTimer() {
        breathingTimer?.invalidate()
        breathingTimer = nil
    }
    
    private func updateBreathingAnimation() {
        let duration = getBreathingDuration()
        let increment = 0.1 / duration
        
        switch breathingPhase {
        case .inhale:
            breathingProgress += increment
            if breathingProgress >= 1.0 {
                breathingProgress = 1.0
                breathingPhase = .hold
            }
            
        case .hold:
            // Hold for 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                breathingPhase = .exhale
            }
            
        case .exhale:
            breathingProgress -= increment
            if breathingProgress <= 0.0 {
                breathingProgress = 0.0
                breathingPhase = .pause
            }
            
        case .pause:
            // Pause for 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                breathingPhase = .inhale
            }
        }
    }
    
    private func getBreathingDuration() -> Double {
        // Default breathing pattern for 4-7-8 breathing
        switch breathingPhase {
        case .inhale: return 4.0
        case .hold: return 7.0
        case .exhale: return 8.0
        case .pause: return 1.0
        }
    }
    
    // MARK: - Helper Methods
    
    private func getInterventionColor(_ category: InterventionCategory) -> Color {
        switch category {
        case .breathing: return .blue
        case .mindfulness: return .green
        case .movement: return .orange
        case .cognitive: return .purple
        case .social: return .pink
        case .creativity: return .yellow
        case .stressManagement: return .red
        case .energyBoost: return .cyan
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Intervention Card View

struct InterventionCardView: View {
    let intervention: VoiceGuidedIntervention
    let onTap: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    // Icon
                    Image(systemName: intervention.icon)
                        .font(.system(size: 32))
                        .foregroundColor(getInterventionColor(intervention.category))
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(getInterventionColor(intervention.category).opacity(0.2))
                        )
                    
                    Spacer()
                    
                    // Duration and Category
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(intervention.formattedDuration)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeColors.secondaryText)
                        
                        Text(intervention.category.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                getInterventionColor(intervention.category).opacity(0.2)
                            )
                            .foregroundColor(getInterventionColor(intervention.category))
                            .clipShape(Capsule())
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(intervention.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                        .multilineTextAlignment(.leading)
                    
                    Text(intervention.description)
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                // Difficulty indicator
                HStack {
                    Text(intervention.difficulty.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(getDifficultyColor(intervention.difficulty))
                    
                    Spacer()
                    
                    Text("\(intervention.steps.count) steps")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemeColors.secondaryBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .hapticFeedback(.standard)
    }
    
    private func getInterventionColor(_ category: InterventionCategory) -> Color {
        switch category {
        case .breathing: return .blue
        case .mindfulness: return .green
        case .movement: return .orange
        case .cognitive: return .purple
        case .social: return .pink
        case .creativity: return .yellow
        case .stressManagement: return .red
        case .energyBoost: return .cyan
        }
    }
    
    private func getDifficultyColor(_ difficulty: InterventionDifficulty) -> Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

// MARK: - Intervention Completion View

struct InterventionCompletionView: View {
    let intervention: VoiceGuidedIntervention
    let duration: TimeInterval
    @Binding var rating: Int
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Celebration Header
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    
                                    Text("Session Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeColors.primaryText)
                    
                    Text("You completed \(intervention.title) in \(formatDuration(duration))")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                
                // Rating Section
                VStack(spacing: 24) {
                    Text("How effective was this session?")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                                HapticManager.shared.selection()
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundColor(star <= rating ? .yellow : ThemeColors.secondaryText.opacity(0.3))
                            }
                            .scaleEffect(star <= rating ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rating)
                        }
                    }
                    
                    if rating > 0 {
                        Text(getEffectivenessDescription(rating))
                            .font(.subheadline)
                            .foregroundColor(ThemeColors.primaryText)
                            .animation(.easeInOut, value: rating)
                    }
                }
                
                Spacer()
                
                // Complete Button
                Button {
                    onComplete()
                } label: {
                    Text("Complete")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .opacity(rating > 0 ? 1.0 : 0.6)
                }
                .disabled(rating == 0)
                .hapticFeedback(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColors.secondaryText)
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func getEffectivenessDescription(_ rating: Int) -> String {
        switch rating {
        case 1: return "Not helpful"
        case 2: return "Slightly helpful"
        case 3: return "Moderately helpful"
        case 4: return "Very helpful"
        case 5: return "Extremely helpful"
        default: return ""
        }
    }
}

#Preview {
    VoiceGuidedInterventionView(
        intervention: nil
    )
    .environmentObject(ThemeManager())
}
