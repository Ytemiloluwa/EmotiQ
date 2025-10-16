//
//  VoiceGuidedInterventionView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//


import Foundation
import SwiftUI
import CoreData

struct VoiceGuidedInterventionView: View {
    let intervention: VoiceGuidedIntervention?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var interventionService = VoiceGuidedInterventionService.shared
    
    @State private var selectedTab: InterventionTab = .breathingExercises
    @State private var selectedIntervention: VoiceGuidedIntervention?
    @State private var currentStep = 0
    @State private var showingCompletion = false
    @State private var effectivenessRating = 0
    @State private var sessionStartTime = Date()
    @State private var breathingPhase: BreathingPhase = .inhale
    @State private var breathingTimer: Timer?
    @State private var breathingProgress: Double = 0
    @State private var showingVoiceSetup = false
    @State private var phaseScheduled = false
    
    enum InterventionTab: String, CaseIterable {
        case breathingExercises = "Breathing"
        case emotionalPrompts = "Emotional"
        // case quickRelief = "Quick Relief" // Commented out to reduce ElevenLabs credit consumption
        
        var displayName: String {
            switch self {
            case .breathingExercises: return "Breathing"
            case .emotionalPrompts: return "Emotional"
            // case .quickRelief: return "Quick Relief" // Commented out
            }
        }
        
        var interventions: [VoiceGuidedIntervention] {
            switch self {
            case .breathingExercises: return VoiceGuidedIntervention.breathingExercises
            case .emotionalPrompts: return VoiceGuidedIntervention.emotionalPrompts
            // case .quickRelief: return VoiceGuidedIntervention.quickRelief // Commented out
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

    private var selectedBreathingType: BreathingExerciseType? {
        guard let title = selectedIntervention?.title.lowercased(), selectedIntervention?.category == .breathing else { return nil }
        if title.contains("4-7-8") { return .fourSevenEight }
        if title.contains("box") { return .boxBreathing }
        if title.contains("equal") { return .equalBreathing }
        if title.contains("coherent") { return .coherentBreathing }
        if title.contains("bellows") { return .bellowsBreath }
        return .boxBreathing
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                ThemeColors.primaryBackground
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
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if selectedIntervention != nil {
                            // Back to list inside the same view
                            selectedIntervention = nil
                            interventionService.stop()
                            stopBreathingTimer()
                            currentStep = 0
                            effectivenessRating = 0
                        } else {
                            // Pop to previous screen (Coaching)
                            HapticManager.shared.selection()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(ThemeColors.accent)
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
            .navigationDestination(isPresented: $showingVoiceSetup) {
                VoiceCloningSetupView()
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
            ThemeColors.primaryBackground
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
                    if selectedBreathingType == .boxBreathing {
                        squareBreathingVisualization
                    } else {
                        breathingVisualization
                    }
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
                    .overlay(
                        Circle()
                            .stroke(breathingPhase.color.opacity(0.25), lineWidth: 8)
                            .blur(radius: 8)
                            .opacity(Double(interventionService.audioLevel) * 0.8)
                    )
                    .shadow(color: breathingPhase.color.opacity(0.35), radius: 20 + 20 * Double(interventionService.audioLevel), x: 0, y: 0)
                    .animation(.easeInOut(duration: getBreathingDuration()), value: breathingProgress)
                
                // Phase instruction
                VStack(spacing: 8) {
                    Text(breathingPhase.instruction)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(String(format: "%.0f", max(0, getBreathingDuration() - breathingProgress * getBreathingDuration())))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .onChange(of: breathingPhase) { _, _ in
                    HapticManager.shared.selection()
                }
            }
            

            VStack(spacing: 10) {
                Text(phasePrimaryText())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                    .transition(.opacity)
                    .animation(.easeInOut, value: breathingPhase)
                
                Text(phaseSecondaryText())
                    .font(.subheadline)
                    .foregroundColor(ThemeColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .animation(.easeInOut, value: breathingPhase)
                
                if let script = interventionService.currentScript,
                   interventionService.currentSegment < script.segments.count {
                    Text(script.segments[interventionService.currentSegment].text)
                        .font(.footnote)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .padding(.top, 2)
                        .transition(.opacity)
                        .animation(.easeInOut, value: interventionService.currentSegment)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ThemeColors.secondaryBackground)
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
        )
        .onChange(of: interventionService.currentTime) { _, _ in
            syncBreathingToAudio()
        }
    }
    
    private func syncBreathingToAudio() {
            guard let type = selectedBreathingType else { return }
            // Map current audio segment index to phase when script provides explicit cues
            // Fallback: drive progress smoothly based on phase durations
            let duration = getBreathingDuration()
            let increment = duration > 0 ? 0.1 / duration : 1.0
            switch breathingPhase {
            case .inhale:
                if !phaseScheduled { HapticManager.shared.breathingSync(phase: .inhale, duration: getBreathingDuration()) }
                phaseScheduled = false
                breathingProgress = min(1.0, breathingProgress + increment)
                if breathingProgress >= 1.0 { breathingPhase = .hold }
            case .hold:
                if !phaseScheduled {
                    phaseScheduled = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        breathingPhase = .exhale
                        phaseScheduled = false
                    }
                }
            case .exhale:
                if !phaseScheduled { HapticManager.shared.breathingSync(phase: .exhale, duration: getBreathingDuration()) }
                phaseScheduled = false
                breathingProgress = max(0.0, breathingProgress - increment)
                if breathingProgress <= 0.0 { breathingPhase = .pause }
            case .pause:
                if !phaseScheduled {
                    phaseScheduled = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        breathingPhase = .inhale
                        phaseScheduled = false
                    }
                }
            }
        }

        private func phasePrimaryText() -> String {
            switch breathingPhase {
            case .inhale:
                return "Breathe in slowly"
            case .hold:
                return "Hold gently"
            case .exhale:
                return "Breathe out fully"
            case .pause:
                return "Rest"
            }
        }
        
        private func phaseSecondaryText() -> String {
            let remaining = max(0, Int(ceil(getBreathingDuration() - breathingProgress * getBreathingDuration())))
            switch breathingPhase {
            case .inhale:
                return "Fill your belly • \(remaining)s"
            case .hold:
                return "Soften your shoulders • \(remaining)s"
            case .exhale:
                return "Relax your jaw • \(remaining)s"
            case .pause:
                return "Notice the calm • \(remaining)s"
            }
        }

    // MARK: - Square Breathing Visualization (Box Breathing)
    private var squareBreathingVisualization: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(breathingPhase.color.opacity(0.4), lineWidth: 4)
                    .frame(width: 220, height: 220)
                // Moving dot along the square path, synced with phase/progress
                GeometryReader { geo in
                    let size = min(geo.size.width, geo.size.height)
                    let inset: CGFloat = 12
                    let side = size - inset * 2
                    let pos = dotPosition(side: side, inset: inset)
                    Circle()
                        .fill(breathingPhase.color)
                        .frame(width: 14, height: 14)
                        .position(x: pos.x + inset, y: pos.y + inset)
                }
                .frame(width: 220, height: 220)
                
                VStack(spacing: 6) {
                    Text(labelForPhase())
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    Text("\(Int(ceil(getBreathingDuration() * (phaseScheduled ? 0 : 1))))s")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
            
            HStack(spacing: 16) {
                phaseChip("Inhale", .inhale)
                phaseChip("Hold", .hold)
                phaseChip("Exhale", .exhale)
                phaseChip("Hold", .pause)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ThemeColors.secondaryBackground)
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
        )
    }
    
    private func phaseChip(_ text: String, _ phase: BreathingPhase) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(breathingPhase == phase ? breathingPhase.color.opacity(0.2) : ThemeColors.secondaryBackground)
            .foregroundColor(breathingPhase == phase ? breathingPhase.color : ThemeColors.primaryText)
            .clipShape(Capsule())
    }
    
    private func labelForPhase() -> String {
        switch breathingPhase {
        case .inhale: return "Inhale"
        case .hold: return "Hold"
        case .exhale: return "Exhale"
        case .pause: return "Hold"
        }
    }
    
    private func dotPosition(side: CGFloat, inset: CGFloat) -> CGPoint {
        // Map phase and progress [0..1] to square perimeter coordinates
        let p = max(0, min(1, breathingProgress))
        switch breathingPhase {
        case .inhale:
            // Bottom-left to top-left
            return CGPoint(x: 0, y: side - side * p)
        case .hold:
            // Top-left to top-right
            return CGPoint(x: side * p, y: 0)
        case .exhale:
            // Top-right to bottom-right
            return CGPoint(x: side, y: side * p)
        case .pause:
            // Bottom-right to bottom-left
            return CGPoint(x: side - side * p, y: side)
        }
    }
    
    // MARK: - Audio Controls Section
    
    private var audioControlsSection: some View {
        VStack(spacing: 16) {
            
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
                    if interventionService.isPlaying {
                        interventionService.pause()
                    } else {
                        playCurrentStep()
                    }
                } label: {
                    Image(systemName: interventionService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(selectedIntervention != nil ? getInterventionColor(selectedIntervention!.category) : .blue)
                        .shadow(color: (selectedIntervention != nil ? getInterventionColor(selectedIntervention!.category) : .blue).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .hapticFeedback(.primary)
                .scaleEffect(interventionService.isPlaying ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: interventionService.isPlaying)
                .disabled(!ElevenLabsService.shared.isVoiceCloned)
                .opacity(ElevenLabsService.shared.isVoiceCloned ? 1.0 : 0.6)
                
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
        
        // Pre-generate and cache all audio for this intervention
        Task {
            try? await interventionService.prewarmCache(for: selectedIntervention)
        }
        
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
                    try await interventionService.playSegment(
                        text: voicePrompt.text,
                        emotion: .neutral
                    )
                }
            } catch ElevenLabsError.noVoiceProfile {
                // User doesn't have voice profile set up
               
                HapticManager.shared.notification(.warning)
                
                // Show user-friendly guidance
                await MainActor.run {
        
                    showingVoiceSetup = true
                }
            } catch {
              
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
        interventionService.stop()
        stopBreathingTimer()
        dismiss()
        
        HapticManager.shared.buttonPress(.subtle)
    }
    
    private func completeIntervention() {
        // Save completion data to Core Data
        guard let selectedIntervention = selectedIntervention else { return }
        
        let completion = InterventionCompletionEntity(context: viewContext)
        completion.id = UUID()
        completion.interventionId = selectedIntervention.id
        completion.interventionTitle = selectedIntervention.title
        completion.interventionType = selectedIntervention.category.rawValue
        completion.category = selectedIntervention.category.rawValue
        completion.duration = Int32(Date().timeIntervalSince(sessionStartTime))
        completion.effectivenessRating = Int16(effectivenessRating)
        completion.stepsCompleted = Int16(currentStep + 1)
        completion.totalSteps = Int16(selectedIntervention.steps.count)
        completion.completedAt = Date()
        completion.wasVoiceGuided = true
        completion.notes = "Completed via VoiceGuidedInterventionView"
        
        // Save to Core Data
        do {
            try viewContext.save()
            
            
            // Track completion with OneSignal
            Task {
                await trackInterventionCompletion(selectedIntervention)
                await OneSignalService.shared.tagCompletionAndTriggerIAM(
                    interventionTitle: selectedIntervention.title,
                    category: selectedIntervention.category.rawValue,
                    durationSeconds: Int(Date().timeIntervalSince(sessionStartTime)),
                    rating: effectivenessRating
                )
            }
            
        } catch {
           
        }
        
        dismiss()
        HapticManager.shared.celebration(.goalCompleted)
    }
    
    private func trackInterventionCompletion(_ intervention: VoiceGuidedIntervention) async {
        // Send completion event to OneSignal for analytics and follow-up
        let completionData: [String: Any] = [
            "event_type": "intervention_completed",
            "intervention_id": intervention.id.uuidString,
            "intervention_title": intervention.title,
            "intervention_category": intervention.category.rawValue,
            "duration_seconds": Int(Date().timeIntervalSince(sessionStartTime)),
            "effectiveness_rating": effectivenessRating,
            "steps_completed": currentStep + 1,
            "total_steps": intervention.steps.count,
            "was_voice_guided": true,
            "completion_timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Convert completionData to String values for OneSignal
        let stringData = completionData.mapValues { value in
            if let stringValue = value as? String {
                return stringValue
            } else {
                return String(describing: value)
            }
        }
        
        // Send to OneSignal for user behavior tracking
        await OneSignalService.shared.sendIndividualNotification(
            NotificationContent(
                title: "🎉 Great job!",
                body: "You completed \(intervention.title). How are you feeling now?",
                actionButtons: [
                    NotificationActionButton(id: "feeling_good", text: "Feeling Better"),
                    NotificationActionButton(id: "need_more", text: "Need More Help")
                ],
                customData: stringData,
                categoryIdentifier: "intervention_completion",
                sound: .default,
                badge: 0,
                userInfo: stringData
            )
        )
        
    }
    
    // MARK: - Breathing Timer
    
    private func startBreathingTimer() {
        stopBreathingTimer()
        
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                updateBreathingAnimation()
            }
        }
        // Ensure timer runs on main run loop
        if let timer = breathingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopBreathingTimer() {
        breathingTimer?.invalidate()
        breathingTimer = nil
    }
    
    private func updateBreathingAnimation() {
        let duration = getBreathingDuration()
        let increment = duration > 0 ? 0.1 / duration : 1.0
        switch breathingPhase {
        case .inhale:
            phaseScheduled = false
            breathingProgress += increment
            if breathingProgress >= 1.0 {
                breathingProgress = 1.0
                breathingPhase = .hold
            }
        case .hold:
            if duration <= 0 {
                breathingPhase = .exhale
                phaseScheduled = false
                return
            }
            if !phaseScheduled {
                phaseScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    Task { @MainActor in
                        breathingPhase = .exhale
                        phaseScheduled = false
                    }
                }
            }
        case .exhale:
            phaseScheduled = false
            breathingProgress -= increment
            if breathingProgress <= 0.0 {
                breathingProgress = 0.0
                breathingPhase = .pause
            }
        case .pause:
            if duration <= 0 {
                breathingPhase = .inhale
                phaseScheduled = false
                return
            }
            if !phaseScheduled {
                phaseScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    Task { @MainActor in
                        breathingPhase = .inhale
                        phaseScheduled = false
                    }
                }
            }
        }
    }
    
    private func getBreathingDuration() -> Double {
        let technique = selectedBreathingType
        switch technique {
        case .boxBreathing:
            switch breathingPhase { case .inhale: return 4; case .hold: return 4; case .exhale: return 4; case .pause: return 4 }
        case .fourSevenEight:
            switch breathingPhase { case .inhale: return 4; case .hold: return 7; case .exhale: return 8; case .pause: return 1 }
        case .equalBreathing:
            switch breathingPhase { case .inhale: return 6; case .hold: return 0; case .exhale: return 6; case .pause: return 0 }
        case .coherentBreathing:
            switch breathingPhase { case .inhale: return 5; case .hold: return 0; case .exhale: return 5; case .pause: return 0 }
        case .bellowsBreath:
            switch breathingPhase { case .inhale: return 1; case .hold: return 0; case .exhale: return 1; case .pause: return 0 }
        case .none:
            switch breathingPhase { case .inhale: return 4; case .hold: return 7; case .exhale: return 8; case .pause: return 1 }
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

