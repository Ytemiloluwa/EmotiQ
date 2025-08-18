//
//  MicroInterventionsView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Micro Interventions View
struct MicroInterventionsView: View {
    @StateObject private var viewModel = MicroInterventionsViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Header
                        MicroInterventionsHeaderView()
                        
                        // MARK: - Quick Relief Section
                        QuickReliefSection(viewModel: viewModel)
                        
                        // MARK: - Breathing Exercises
                        BreathingExercisesSection(viewModel: viewModel)
                        
                        // MARK: - Emotional Prompts
                        EmotionalPromptsSection(viewModel: viewModel)
                        
                        // MARK: - Mindfulness Moments
                        MindfulnessMomentsSection(viewModel: viewModel)
                        
                        // MARK: - Recent Activity
                        if !viewModel.recentInterventions.isEmpty {
                            RecentActivitySection(viewModel: viewModel)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Quick Relief")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColors.accent)
                }
            }
            .sheet(item: $viewModel.selectedIntervention) { intervention in
                InterventionDetailView(intervention: intervention, viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadInterventions()
            }
        }
    }
}

// MARK: - Micro Interventions Header
struct MicroInterventionsHeaderView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Emotional Relief")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Take a moment to reset and recharge with these micro-interventions")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ThemeColors.accent)
            }
        }
        .padding()
        .themedCard()
    }
}

// MARK: - Quick Relief Section
struct QuickReliefSection: View {
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Instant Relief")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.quickReliefInterventions, id: \.id) { intervention in
                    QuickReliefCard(intervention: intervention, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Quick Relief Card
struct QuickReliefCard: View {
    let intervention: QuickIntervention
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            viewModel.selectedIntervention = intervention
        }) {
            VStack(spacing: 12) {
                Image(systemName: intervention.icon)
                    .font(.title)
                    .foregroundColor(intervention.color)
                
                Text(intervention.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(intervention.durationText)
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text("4.8")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(intervention.color.opacity(themeManager.isDarkMode ? 0.2 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(intervention.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Breathing Exercises Section
struct BreathingExercisesSection: View {
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Breathing Exercises")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Button("View All") {
                    // Show all breathing exercises
                }
                .font(.caption)
                .foregroundColor(ThemeColors.accent)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.breathingExercises, id: \.id) { exercise in
                        BreathingExerciseCard(exercise: exercise, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

// MARK: - Breathing Exercise Card
struct BreathingExerciseCard: View {
    let exercise: BreathingExercise
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            viewModel.startBreathingExercise(exercise)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: exercise.icon)
                        .font(.title2)
                        .foregroundColor(exercise.color)
                    
                    Spacer()
                    
                    Text("\(exercise.duration) min")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Text(exercise.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                    .lineLimit(2)
                
                Text(exercise.description)
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                    .lineLimit(3)
                
                HStack {
                    Text(exercise.technique)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(exercise.color.opacity(0.2))
                        .foregroundColor(exercise.color)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text(exercise.difficulty.displayName)
                        .font(.caption2)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
            .frame(width: 200)
            .padding()
            .themedCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Emotional Prompts Section
struct EmotionalPromptsSection: View {
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emotional Prompts")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(spacing: 12) {
                ForEach(viewModel.emotionalPrompts.prefix(3), id: \.id) { prompt in
                    EmotionalPromptCard(prompt: prompt, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Emotional Prompt Card
struct EmotionalPromptCard: View {
    let prompt: EmotionalPrompt
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: prompt.icon)
                    .font(.title3)
                    .foregroundColor(prompt.category.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text(prompt.category.displayName)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(ThemeColors.accent)
                }
            }
            
            Text(prompt.question)
                .font(.body)
                .foregroundColor(ThemeColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reflection Guide:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    ForEach(prompt.reflectionGuide, id: \.self) { guide in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(prompt.category.color)
                            
                            Text(guide)
                                .font(.caption)
                                .foregroundColor(ThemeColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    HStack {
                        Spacer()
                        
                        Button("Start Reflection") {
                            viewModel.startPromptReflection(prompt)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(prompt.category.color)
                        .clipShape(Capsule())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .themedCard()
    }
}

// MARK: - Mindfulness Moments Section
struct MindfulnessMomentsSection: View {
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mindfulness Moments")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.mindfulnessMoments, id: \.id) { moment in
                    MindfulnessMomentCard(moment: moment, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Mindfulness Moment Card
struct MindfulnessMomentCard: View {
    let moment: MindfulnessMoment
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            viewModel.startMindfulnessMoment(moment)
        }) {
            VStack(spacing: 8) {
                Image(systemName: moment.icon)
                    .font(.title2)
                    .foregroundColor(moment.color)
                
                Text(moment.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("\(moment.duration)s")
                    .font(.caption2)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(moment.color.opacity(themeManager.isDarkMode ? 0.2 : 0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    @ObservedObject var viewModel: MicroInterventionsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(spacing: 8) {
                ForEach(viewModel.recentInterventions.prefix(5), id: \.id) { intervention in
                    RecentActivityRow(intervention: intervention)
                }
            }
            .padding()
            .themedCard()
        }
    }
}

// MARK: - Recent Activity Row
struct RecentActivityRow: View {
    let intervention: CompletedIntervention
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: intervention.category.icon)
                .font(.title3)
                .foregroundColor(intervention.category.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(intervention.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                
                Text(intervention.completedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            Spacer()
            
            Text("\(intervention.duration) min")
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
            
            if let effectiveness = intervention.effectiveness {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= effectiveness ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Models

struct BreathingExercise: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let technique: String
    let duration: Int // in minutes
    let icon: String
    let color: Color
    let difficulty: Difficulty
    let instructions: [BreathingInstruction]
    
    enum Difficulty: String, CaseIterable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
        
        var displayName: String {
            switch self {
            case .beginner: return "Beginner"
            case .intermediate: return "Intermediate"
            case .advanced: return "Advanced"
            }
        }
    }
}

struct BreathingInstruction {
    let phase: BreathingPhase
    let duration: Int // in seconds
    let instruction: String
}

enum BreathingPhase: String, CaseIterable {
    case inhale = "inhale"
    case hold = "hold"
    case exhale = "exhale"
    case pause = "pause"
    
    var displayName: String {
        switch self {
        case .inhale: return "Inhale"
        case .hold: return "Hold"
        case .exhale: return "Exhale"
        case .pause: return "Pause"
        }
    }
    
    var icon: String {
        switch self {
        case .inhale: return "arrow.up.circle"
        case .hold: return "pause.circle"
        case .exhale: return "arrow.down.circle"
        case .pause: return "stop.circle"
        }
    }
}

struct EmotionalPrompt: Identifiable {
    let id = UUID()
    let title: String
    let question: String
    let category: PromptCategory
    let icon: String
    let reflectionGuide: [String]
    let estimatedDuration: Int // in minutes
}

enum PromptCategory: String, CaseIterable {
    case selfAwareness = "self_awareness"
    case gratitude = "gratitude"
    case selfCompassion = "self_compassion"
    case values = "values"
    case growth = "growth"
    case relationships = "relationships"
    
    var displayName: String {
        switch self {
        case .selfAwareness: return "Self-Awareness"
        case .gratitude: return "Gratitude"
        case .selfCompassion: return "Self-Compassion"
        case .values: return "Values"
        case .growth: return "Growth"
        case .relationships: return "Relationships"
        }
    }
    
    var color: Color {
        switch self {
        case .selfAwareness: return .purple
        case .gratitude: return .green
        case .selfCompassion: return .pink
        case .values: return .blue
        case .growth: return .orange
        case .relationships: return .cyan
        }
    }
}

struct MindfulnessMoment: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let duration: Int // in seconds
    let icon: String
    let color: Color
    let instructions: [String]
}

// MARK: - Micro Interventions View Model
@MainActor
class MicroInterventionsViewModel: ObservableObject {
    @Published var selectedIntervention: QuickIntervention?
    @Published var recentInterventions: [CompletedIntervention] = []
    @Published var isBreathingExerciseActive = false
    @Published var currentBreathingExercise: BreathingExercise?
    
    // MARK: - Data Properties
    let quickReliefInterventions: [QuickIntervention] = [
        QuickIntervention(
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
        ),
        QuickIntervention(
            title: "Box Breathing",
            description: "Calm your mind with structured breathing",
            category: .breathing,
            icon: "lungs.fill",
            color: .blue,
            estimatedDuration: 5,
            instructions: [
                "Inhale for 4 counts",
                "Hold for 4 counts",
                "Exhale for 4 counts",
                "Hold for 4 counts",
                "Repeat the cycle"
            ],
            benefits: ["Reduces stress", "Improves focus", "Balances nervous system"]
        ),
        QuickIntervention(
            title: "Progressive Relaxation",
            description: "Release tension from your body",
            category: .movement,
            icon: "figure.mind.and.body",
            color: .purple,
            estimatedDuration: 8,
            instructions: [
                "Start with your toes",
                "Tense each muscle group for 5 seconds",
                "Release and notice the relaxation",
                "Move up through your body",
                "End with your face and scalp"
            ],
            benefits: ["Reduces physical tension", "Promotes relaxation", "Improves body awareness"]
        ),
        QuickIntervention(
            title: "Loving-Kindness",
            description: "Send compassion to yourself and others",
            category: .social,
            icon: "heart.fill",
            color: .pink,
            estimatedDuration: 6,
            instructions: [
                "Start with yourself: 'May I be happy'",
                "Extend to loved ones",
                "Include neutral people",
                "Send to difficult people",
                "Embrace all beings"
            ],
            benefits: ["Increases self-compassion", "Improves relationships", "Reduces negative emotions"]
        )
    ]
    
    let breathingExercises: [BreathingExercise] = [
        BreathingExercise(
            title: "4-7-8 Breathing",
            description: "A powerful technique for relaxation and sleep",
            technique: "4-7-8",
            duration: 4,
            icon: "moon.fill",
            color: .indigo,
            difficulty: .beginner,
            instructions: [
                BreathingInstruction(phase: .inhale, duration: 4, instruction: "Breathe in through your nose"),
                BreathingInstruction(phase: .hold, duration: 7, instruction: "Hold your breath"),
                BreathingInstruction(phase: .exhale, duration: 8, instruction: "Exhale through your mouth")
            ]
        ),
        BreathingExercise(
            title: "Equal Breathing",
            description: "Balance your nervous system with equal inhales and exhales",
            technique: "Sama Vritti",
            duration: 5,
            icon: "equal.circle",
            color: .teal,
            difficulty: .beginner,
            instructions: [
                BreathingInstruction(phase: .inhale, duration: 4, instruction: "Inhale slowly and deeply"),
                BreathingInstruction(phase: .exhale, duration: 4, instruction: "Exhale slowly and completely")
            ]
        ),
        BreathingExercise(
            title: "Energizing Breath",
            description: "Boost your energy and alertness",
            technique: "Bellows Breath",
            duration: 3,
            icon: "bolt.fill",
            color: .orange,
            difficulty: .intermediate,
            instructions: [
                BreathingInstruction(phase: .inhale, duration: 1, instruction: "Quick, sharp inhale"),
                BreathingInstruction(phase: .exhale, duration: 1, instruction: "Quick, sharp exhale")
            ]
        )
    ]
    
    let emotionalPrompts: [EmotionalPrompt] = [
        EmotionalPrompt(
            title: "Gratitude Reflection",
            question: "What are three things you're genuinely grateful for today, and why do they matter to you?",
            category: .gratitude,
            icon: "heart.text.square",
            reflectionGuide: [
                "Think beyond material things",
                "Consider relationships and experiences",
                "Notice small, everyday moments",
                "Reflect on how these things impact your life"
            ],
            estimatedDuration: 5
        ),
        EmotionalPrompt(
            title: "Self-Compassion Check",
            question: "How would you comfort a good friend who was experiencing what you're going through right now?",
            category: .selfCompassion,
            icon: "heart.circle",
            reflectionGuide: [
                "Notice your inner critic",
                "Imagine speaking to a dear friend",
                "Use kind, understanding words",
                "Offer yourself the same compassion"
            ],
            estimatedDuration: 7
        ),
        EmotionalPrompt(
            title: "Values Exploration",
            question: "What values are most important to you, and how are you living them today?",
            category: .values,
            icon: "star.circle",
            reflectionGuide: [
                "Identify your core values",
                "Consider recent actions and decisions",
                "Notice alignment or misalignment",
                "Plan how to better honor your values"
            ],
            estimatedDuration: 10
        )
    ]
    
    let mindfulnessMoments: [MindfulnessMoment] = [
        MindfulnessMoment(
            title: "Body Scan",
            description: "Quick awareness of physical sensations",
            duration: 60,
            icon: "figure.mind.and.body",
            color: .purple,
            instructions: [
                "Close your eyes and breathe naturally",
                "Start at the top of your head",
                "Notice sensations without judgment",
                "Move slowly down through your body"
            ]
        ),
        MindfulnessMoment(
            title: "Sound Awareness",
            description: "Listen to the world around you",
            duration: 30,
            icon: "ear",
            color: .blue,
            instructions: [
                "Sit comfortably and close your eyes",
                "Notice sounds near and far",
                "Don't label or judge the sounds",
                "Simply observe and listen"
            ]
        ),
        MindfulnessMoment(
            title: "Breath Focus",
            description: "Simple breath awareness",
            duration: 45,
            icon: "lungs",
            color: .green,
            instructions: [
                "Focus on your natural breath",
                "Notice the sensation of breathing",
                "When mind wanders, gently return",
                "No need to change your breath"
            ]
        )
    ]
    
    // MARK: - Public Methods
    
    func loadInterventions() {
        // Load recent interventions from CoachingService
        recentInterventions = CoachingService.shared.completedInterventions
    }
    
    func startBreathingExercise(_ exercise: BreathingExercise) {
        currentBreathingExercise = exercise
        isBreathingExerciseActive = true
        // This would trigger the breathing exercise interface
    }
    
    func startPromptReflection(_ prompt: EmotionalPrompt) {
        // This would open a reflection interface
        print("Starting reflection: \(prompt.title)")
    }
    
    func startMindfulnessMoment(_ moment: MindfulnessMoment) {
        // This would start a guided mindfulness session
        print("Starting mindfulness: \(moment.title)")
    }
    
    func completeIntervention(_ intervention: QuickIntervention) {
        Task {
            await CoachingService.shared.recordInterventionCompletion(intervention)
            loadInterventions()
        }
    }
}

// MARK: - Preview
struct MicroInterventionsView_Previews: PreviewProvider {
    static var previews: some View {
        MicroInterventionsView()
            .environmentObject(ThemeManager())
    }
}

