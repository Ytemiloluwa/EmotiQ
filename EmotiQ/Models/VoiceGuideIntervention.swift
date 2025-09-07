//
//  VoiceGuideIntervention.swift
//  EmotiQ
//
//  Created by Temiloluwa on 07-09-2025.
//

import Foundation

// MARK: - Voice-Guided Intervention Models

struct VoiceGuidedIntervention: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let category: InterventionCategory
    let estimatedDuration: TimeInterval
    let steps: [InterventionStep]
    let voicePrompts: [VoicePrompt]
    let targetEmotions: [EmotionType]
    let difficulty: InterventionDifficulty
    let icon: String
    let backgroundColor: String
    
    var formattedDuration: String {
        let minutes = Int(estimatedDuration / 60)
        return "\(minutes) min"
    }
    
    init(title: String, description: String, category: InterventionCategory, estimatedDuration: TimeInterval, steps: [InterventionStep], voicePrompts: [VoicePrompt], targetEmotions: [EmotionType], difficulty: InterventionDifficulty, icon: String, backgroundColor: String) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.estimatedDuration = estimatedDuration
        self.steps = steps
        self.voicePrompts = voicePrompts
        self.targetEmotions = targetEmotions
        self.difficulty = difficulty
        self.icon = icon
        self.backgroundColor = backgroundColor
    }
}

struct InterventionStep: Identifiable, Codable {
    let id: UUID
    let title: String
    let instruction: String
    let duration: TimeInterval
    let voicePromptId: String?
    let requiresUserInput: Bool
    let stepType: StepType
    
    enum StepType: String, Codable, CaseIterable {
        case instruction = "instruction"
        case breathing = "breathing"
        case reflection = "reflection"
        case movement = "movement"
        case visualization = "visualization"
        case affirmation = "affirmation"
    }
    
    init(title: String, instruction: String, duration: TimeInterval, voicePromptId: String?, requiresUserInput: Bool, stepType: StepType) {
        self.id = UUID()
        self.title = title
        self.instruction = instruction
        self.duration = duration
        self.voicePromptId = voicePromptId
        self.requiresUserInput = requiresUserInput
        self.stepType = stepType
    }
}

struct VoicePrompt: Identifiable, Codable {
    let id: String
    let text: String
    let pauseDuration: TimeInterval
    let emotionalTone: EmotionalTone
    let speed: VoiceSpeed
    
    enum EmotionalTone: String, Codable, CaseIterable {
        case calm = "calm"
        case energetic = "energetic"
        case compassionate = "compassionate"
        case confident = "confident"
        case soothing = "soothing"
        case motivational = "motivational"
    }
    
    enum VoiceSpeed: String, Codable, CaseIterable {
        case slow = "slow"
        case normal = "normal"
        case fast = "fast"
    }
}

enum InterventionDifficulty: String, Codable, CaseIterable {
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
    
    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "orange"
        case .advanced: return "red"
        }
    }
}

// MARK: - Predefined Voice-Guided Interventions

extension VoiceGuidedIntervention {
    static let breathingExercises: [VoiceGuidedIntervention] = [
        VoiceGuidedIntervention(
            title: "4-7-8 Breathing",
            description: "A powerful technique for relaxation and sleep",
            category: .breathing,
            estimatedDuration: 240, // 4 minutes
            steps: [
                InterventionStep(
                    title: "Preparation",
                    instruction: "Find a comfortable position and close your eyes",
                    duration: 30,
                    voicePromptId: "prep_478",
                    requiresUserInput: false,
                    stepType: .instruction
                ),
                InterventionStep(
                    title: "Breathing Cycle",
                    instruction: "Inhale for 4, hold for 7, exhale for 8",
                    duration: 180,
                    voicePromptId: "cycle_478",
                    requiresUserInput: false,
                    stepType: .breathing
                ),
                InterventionStep(
                    title: "Reflection",
                    instruction: "Notice how your body feels now",
                    duration: 30,
                    voicePromptId: "reflect_478",
                    requiresUserInput: false,
                    stepType: .reflection
                )
            ],
            voicePrompts: [
                VoicePrompt(
                    id: "prep_478",
                    text: "Welcome to the 4-7-8 breathing exercise. Find a comfortable position, either sitting or lying down. Close your eyes and let your body relax.",
                    pauseDuration: 3.0,
                    emotionalTone: .calm,
                    speed: .slow
                ),
                VoicePrompt(
                    id: "cycle_478",
                    text: "Now, breathe in through your nose for 4 counts... Hold your breath for 7 counts... And exhale through your mouth for 8 counts. Let's continue this rhythm together.",
                    pauseDuration: 2.0,
                    emotionalTone: .soothing,
                    speed: .slow
                ),
                VoicePrompt(
                    id: "reflect_478",
                    text: "Take a moment to notice how your body feels now. You've just completed a powerful relaxation technique. Carry this sense of calm with you.",
                    pauseDuration: 2.0,
                    emotionalTone: .compassionate,
                    speed: .normal
                )
            ],
            targetEmotions: [.fear, .fear, .fear], // anxious, stressed, overwhelmed -> fear
            difficulty: .beginner,
            icon: "lungs.fill",
            backgroundColor: "blue"
        ),
        
        VoiceGuidedIntervention(
            title: "Box Breathing",
            description: "Equal breathing for focus and balance",
            category: .breathing,
            estimatedDuration: 300, // 5 minutes
            steps: [
                InterventionStep(
                    title: "Setup",
                    instruction: "Sit comfortably with your back straight",
                    duration: 30,
                    voicePromptId: "setup_box",
                    requiresUserInput: false,
                    stepType: .instruction
                ),
                InterventionStep(
                    title: "Box Breathing",
                    instruction: "Inhale 4, hold 4, exhale 4, hold 4",
                    duration: 240,
                    voicePromptId: "cycle_box",
                    requiresUserInput: false,
                    stepType: .breathing
                ),
                InterventionStep(
                    title: "Integration",
                    instruction: "Feel the balance and focus you've created",
                    duration: 30,
                    voicePromptId: "integrate_box",
                    requiresUserInput: false,
                    stepType: .reflection
                )
            ],
            voicePrompts: [
                VoicePrompt(
                    id: "setup_box",
                    text: "Welcome to box breathing. Sit comfortably with your back straight and feet flat on the floor. This technique will help you find balance and focus.",
                    pauseDuration: 2.0,
                    emotionalTone: .confident,
                    speed: .normal
                ),
                VoicePrompt(
                    id: "cycle_box",
                    text: "Breathe in for 4 counts... Hold for 4... Exhale for 4... Hold empty for 4. Like drawing a box with your breath. Let's continue this steady rhythm.",
                    pauseDuration: 1.0,
                    emotionalTone: .calm,
                    speed: .normal
                ),
                VoicePrompt(
                    id: "integrate_box",
                    text: "Excellent work. You've created a sense of balance and focus through your breath. This centered feeling is always available to you.",
                    pauseDuration: 2.0,
                    emotionalTone: .confident,
                    speed: .normal
                )
            ],
            targetEmotions: [.fear, .fear, .fear], // anxious, scattered, overwhelmed -> fear
            difficulty: .intermediate,
            icon: "square",
            backgroundColor: "green"
        )
    ]
    
    static let emotionalPrompts: [VoiceGuidedIntervention] = [
        VoiceGuidedIntervention(
            title: "Gratitude Reflection",
            description: "Shift your focus to positive aspects of life",
            category: .mindfulness, // emotional -> mindfulness
            estimatedDuration: 180, // 3 minutes
            steps: [
                InterventionStep(
                    title: "Centering",
                    instruction: "Take a few deep breaths and center yourself",
                    duration: 30,
                    voicePromptId: "center_gratitude",
                    requiresUserInput: false,
                    stepType: .instruction
                ),
                InterventionStep(
                    title: "Gratitude Questions",
                    instruction: "Reflect on what you're grateful for",
                    duration: 120,
                    voicePromptId: "questions_gratitude",
                    requiresUserInput: true,
                    stepType: .reflection
                ),
                InterventionStep(
                    title: "Integration",
                    instruction: "Feel the warmth of gratitude in your heart",
                    duration: 30,
                    voicePromptId: "integrate_gratitude",
                    requiresUserInput: false,
                    stepType: .affirmation
                )
            ],
            voicePrompts: [
                VoicePrompt(
                    id: "center_gratitude",
                    text: "Let's take a moment to connect with gratitude. Take a few deep breaths and allow yourself to settle into this moment.",
                    pauseDuration: 3.0,
                    emotionalTone: .compassionate,
                    speed: .slow
                ),
                VoicePrompt(
                    id: "questions_gratitude",
                    text: "What are three things you're genuinely grateful for today? They can be big or small. Take your time to really feel the appreciation for each one.",
                    pauseDuration: 15.0,
                    emotionalTone: .compassionate,
                    speed: .normal
                ),
                VoicePrompt(
                    id: "integrate_gratitude",
                    text: "Feel the warmth of gratitude filling your heart. This feeling of appreciation is a gift you can give yourself anytime.",
                    pauseDuration: 2.0,
                    emotionalTone: .compassionate,
                    speed: .slow
                )
            ],
            targetEmotions: [.sadness, .anger, .anger], // sad -> sadness, angry/frustrated -> anger
            difficulty: .beginner,
            icon: "heart.fill",
            backgroundColor: "pink"
        ),
        
        VoiceGuidedIntervention(
            title: "Self-Compassion Check",
            description: "Treat yourself with kindness and understanding",
            category: .mindfulness, // emotional -> mindfulness
            estimatedDuration: 240, // 4 minutes
            steps: [
                InterventionStep(
                    title: "Recognition",
                    instruction: "Acknowledge what you're experiencing",
                    duration: 60,
                    voicePromptId: "recognize_compassion",
                    requiresUserInput: true,
                    stepType: .reflection
                ),
                InterventionStep(
                    title: "Self-Kindness",
                    instruction: "Offer yourself the same kindness you'd give a friend",
                    duration: 120,
                    voicePromptId: "kindness_compassion",
                    requiresUserInput: true,
                    stepType: .reflection
                ),
                InterventionStep(
                    title: "Affirmation",
                    instruction: "Receive words of comfort and support",
                    duration: 60,
                    voicePromptId: "affirm_compassion",
                    requiresUserInput: false,
                    stepType: .affirmation
                )
            ],
            voicePrompts: [
                VoicePrompt(
                    id: "recognize_compassion",
                    text: "Right now, you're experiencing something difficult. Take a moment to acknowledge what you're feeling without judgment. It's okay to feel this way.",
                    pauseDuration: 10.0,
                    emotionalTone: .compassionate,
                    speed: .slow
                ),
                VoicePrompt(
                    id: "kindness_compassion",
                    text: "How would you comfort a good friend who was experiencing what you're going through right now? What words of kindness would you offer them? Now, offer those same words to yourself.",
                    pauseDuration: 15.0,
                    emotionalTone: .compassionate,
                    speed: .normal
                ),
                VoicePrompt(
                    id: "affirm_compassion",
                    text: "You are worthy of kindness and understanding, especially from yourself. You're doing the best you can with what you have right now, and that's enough.",
                    pauseDuration: 3.0,
                    emotionalTone: .compassionate,
                    speed: .slow
                )
            ],
            targetEmotions: [.sadness, .sadness, .anger, .anger], // ashamed -> sadness, frustrated -> anger
            difficulty: .intermediate,
            icon: "hands.sparkles.fill",
            backgroundColor: "purple"
        )
    ]
    
    static let quickRelief: [VoiceGuidedIntervention] = [
        VoiceGuidedIntervention(
            title: "5-4-3-2-1 Grounding",
            description: "Quickly ground yourself in the present moment",
            category: .mindfulness, // grounding -> mindfulness
            estimatedDuration: 120, // 2 minutes
            steps: [
                InterventionStep(
                    title: "Grounding Exercise",
                    instruction: "Use your senses to connect with the present",
                    duration: 120,
                    voicePromptId: "grounding_54321",
                    requiresUserInput: true,
                    stepType: .instruction
                )
            ],
            voicePrompts: [
                VoicePrompt(
                    id: "grounding_54321",
                    text: "Let's ground yourself in this moment. Look around and name 5 things you can see... 4 things you can touch... 3 things you can hear... 2 things you can smell... and 1 thing you can taste. Take your time with each one.",
                    pauseDuration: 5.0,
                    emotionalTone: .calm,
                    speed: .normal
                )
            ],
            targetEmotions: [.fear, .fear, .fear], // anxious, overwhelmed, panicked -> fear
            difficulty: .beginner,
            icon: "eye.fill",
            backgroundColor: "teal"
        )
    ]
    
    static let allInterventions: [VoiceGuidedIntervention] =
        breathingExercises + emotionalPrompts + quickRelief
}

