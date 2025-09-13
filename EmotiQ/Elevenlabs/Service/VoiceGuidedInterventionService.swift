//
//  VoiceGuidedInterventionService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import AVFoundation
import Combine
import UIKit
import CoreHaptics
import AVFoundation

// MARK: - Voice Guided Intervention Service
@MainActor
class VoiceGuidedInterventionService: ObservableObject {
    static let shared = VoiceGuidedInterventionService()
    
    @Published var isPlaying = false
    @Published var currentSegment = 0
    @Published var totalSegments = 0
    @Published var playbackProgress: Double = 0.0
    @Published var currentInterventionType: InterventionType?
    @Published var currentScript: InterventionScript?
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private let elevenLabsService = ElevenLabsService.shared
    private var cancellables = Set<AnyCancellable>()
    private let cacheManager = AudioCacheManager.shared
    private var inFlight: [String: Task<URL, Error>] = [:]
    
    // Intervention content
    private let interventionScripts = InterventionScripts()
    
    private init() {}
    
    // MARK: - Voice-Guided Emotional Prompts
    
    /// Start voice-guided emotional prompt session
    func startEmotionalPromptSession(
        type: EmotionalPromptType,
        emotion: EmotionType
    ) async throws {
        currentInterventionType = .emotionalPrompt(type)
        
        let script = interventionScripts.getEmotionalPromptScript(type: type, emotion: emotion)
        currentScript = script
        Task { await prewarm(script) }
        try await playInterventionScript(script)
    }
    
    /// Start voice-guided breathing exercise
    func startBreathingExercise(
        type: BreathingExerciseType,
        duration: TimeInterval = 300 // 5 minutes default
    ) async throws {
        currentInterventionType = .breathing(type)
        
        let script = interventionScripts.getBreathingScript(type: type, duration: duration)
        currentScript = script
        Task { await prewarm(script) }
        try await playInterventionScript(script)
    }
    
    /// Start voice-guided grounding exercise
    func startGroundingExercise(
        type: GroundingExerciseType
    ) async throws {
        currentInterventionType = .grounding(type)
        
        let script = interventionScripts.getGroundingScript(type: type)
        currentScript = script
        Task { await prewarm(script) }
        try await playInterventionScript(script)
    }
    
    // MARK: - Playback Control
    
    /// Play intervention script with voice guidance
    private func playInterventionScript(_ script: InterventionScript) async throws {
        totalSegments = script.segments.count
        currentSegment = 0
        
        for (index, segment) in script.segments.enumerated() {
            currentSegment = index
            playbackProgress = Double(index) / Double(totalSegments)
            
            try await playSegment(segment)
            
            // Wait for pause duration if specified
            if segment.pauseDuration > 0 {
                try await Task.sleep(nanoseconds: UInt64(segment.pauseDuration * 1_000_000_000))
            }
        }
        
        // Session complete
        playbackProgress = 1.0
        currentInterventionType = nil
        currentScript = nil
        HapticManager.shared.notification(.success)
    }
    
    /// Play individual segment with voice generation
    private func playSegment(_ segment: InterventionSegment) async throws {
        do {
            // Get the user's voice profile ID
            let userVoiceId = elevenLabsService.userVoiceProfile?.id
            
            guard let finalVoiceId = userVoiceId else {

                throw ElevenLabsError.noVoiceProfile
            }
            
            
            // First check cache - if found, play immediately (zero credits)
            if let cachedURL = await cacheManager.getCachedAudio(for: segment.text, emotion: segment.emotion, voiceId: finalVoiceId) {

                try await playAudio(from: cachedURL)
                return
            }
            
            // Generate cache key for in-flight tracking
            let cacheKey = "\(segment.text)_\(segment.emotion.rawValue)_\(finalVoiceId)"
            
            // Check if already generating this audio (prevent duplicate requests)
            if let task = inFlight[cacheKey] {

                let url = try await task.value
   
                try await playAudio(from: url)
                return
            }
            
            // Generate new audio and cache it
            let task = Task<URL, Error> { [weak self] in
                guard let self = self else { throw VoiceGuidedInterventionError.invalidScript }
                let audioData = try await self.elevenLabsService.generateSpeech(
                    text: segment.text,
                    voiceId: finalVoiceId,
                    emotion: segment.emotion,
                    settings: ElevenLabsViewModel.VoiceSettings(
                        stability: segment.stability,
                        similarityBoost: 0.8,
                        style: 0.2,
                        useSpeakerBoost: true
                    )
                )
                let cachedURL = try await self.cacheManager.cacheAudio(data: audioData, text: segment.text, emotion: segment.emotion, voiceId: finalVoiceId)
     
                return cachedURL
            }
            inFlight[cacheKey] = task
            defer { inFlight.removeValue(forKey: cacheKey) }
            let url = try await task.value
            
            try await playAudio(from: url)
            
        } catch ElevenLabsError.noVoiceProfile {

            throw ElevenLabsError.noVoiceProfile
            
        } catch {

            throw error
        }
    }

    // MARK: - Prewarm Cache
    private func prewarm(_ script: InterventionScript) async {

        var cachedCount = 0
        var generatedCount = 0
        
        // Get the user's voice profile ID
        let userVoiceId = elevenLabsService.userVoiceProfile?.id
        
        guard let finalVoiceId = userVoiceId else {
            return
        }
        
        for (index, segment) in script.segments.enumerated() {

            // Skip if already cached
            if await cacheManager.getCachedAudio(for: segment.text, emotion: segment.emotion, voiceId: finalVoiceId) != nil {
                cachedCount += 1

                continue
            }
            
            // Generate cache key for in-flight tracking
            let cacheKey = "\(segment.text)_\(segment.emotion.rawValue)_\(finalVoiceId)"
            
            // Skip if already generating
            if inFlight[cacheKey] != nil {
                continue
            }
            
            // Generate and cache audio

            let task = Task<URL, Error> { [weak self] in
                guard let self = self else { throw VoiceGuidedInterventionError.invalidScript }
                let audioData = try await self.elevenLabsService.generateSpeech(
                    text: segment.text,
                    voiceId: finalVoiceId,
                    emotion: segment.emotion,
                    settings: ElevenLabsViewModel.VoiceSettings(
                        stability: segment.stability,
                        similarityBoost: 0.8,
                        style: 0.2,
                        useSpeakerBoost: true
                    )
                )
                let cachedURL = try await self.cacheManager.cacheAudio(data: audioData, text: segment.text, emotion: segment.emotion, voiceId: finalVoiceId)
                return cachedURL
            }
            inFlight[cacheKey] = task
            _ = try? await task.value
            inFlight.removeValue(forKey: cacheKey)
            generatedCount += 1
    
        }
        
    }
    
    /// Play audio from URL
    private func playAudio(from url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = AudioPlayerDelegate { [weak self] success in
                    DispatchQueue.main.async {
                        self?.isPlaying = false
                        if success {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: VoiceGuidedInterventionError.playbackFailed)
                        }
                    }
                }
                
                isPlaying = true
                audioPlayer?.play()
                
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    
    /// Pause current playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
    }
    
    /// Resume playback
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    /// Stop current session
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        playbackTimer?.invalidate()
        currentInterventionType = nil
        currentSegment = 0
        playbackProgress = 0.0
    }
    
    /// Skip to next segment
    func skipToNext() {
        audioPlayer?.stop()
        // The playInterventionScript loop will continue to next segment
    }
    
    /// Skip to previous segment
    func skipToPrevious() {
        if currentSegment > 0 {
            currentSegment -= 1
            audioPlayer?.stop()
        }
    }
    
    // MARK: - Public API for VoiceGuidedInterventionView
    
    /// Play a single segment with caching (used by VoiceGuidedInterventionView)
    func playSegment(text: String, emotion: EmotionType) async throws {

        let segment = InterventionSegment(
            text: text,
            emotion: .neutral, // Use .neutral to match prewarm cache
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 0.0,
            hapticFeedback: nil
        )
        try await playSegment(segment)
    }
    
    /// Prewarm cache for a VoiceGuidedIntervention (used by VoiceGuidedInterventionView)
    func prewarmCache(for intervention: VoiceGuidedIntervention) async throws {

        
        // Convert VoiceGuidedIntervention to InterventionScript for prewarming
        let segments = intervention.voicePrompts.map { prompt in
            InterventionSegment(
                text: prompt.text,
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 0.0,
                hapticFeedback: nil
            )
        }
        
        let script = InterventionScript(
            title: intervention.title,
            description: intervention.description,
            estimatedDuration: TimeInterval(intervention.estimatedDuration * 60),
            segments: segments
        )
        
        await prewarm(script)

    }
}

// MARK: - Data Models

enum InterventionType {
    case emotionalPrompt(EmotionalPromptType)
    case breathing(BreathingExerciseType)
    case grounding(GroundingExerciseType)
    case mindfulness(MindfulnessType)
}

enum EmotionalPromptType: String, CaseIterable {
    case gratitude = "gratitude"
    case selfCompassion = "self_compassion"
    case valuesExploration = "values_exploration"
    case strengthsRecognition = "strengths_recognition"
    case emotionalProcessing = "emotional_processing"
    case futureVisioning = "future_visioning"
    
    var displayName: String {
        switch self {
        case .gratitude: return "Gratitude Reflection"
        case .selfCompassion: return "Self-Compassion Check"
        case .valuesExploration: return "Values Exploration"
        case .strengthsRecognition: return "Strengths Recognition"
        case .emotionalProcessing: return "Emotional Processing"
        case .futureVisioning: return "Future Visioning"
        }
    }
    
    var icon: String {
        switch self {
        case .gratitude: return "heart.fill"
        case .selfCompassion: return "hands.sparkles.fill"
        case .valuesExploration: return "star.fill"
        case .strengthsRecognition: return "trophy.fill"
        case .emotionalProcessing: return "brain.head.profile"
        case .futureVisioning: return "eye.fill"
        }
    }
}

enum BreathingExerciseType: String, CaseIterable {
    case boxBreathing = "box_breathing"
    case fourSevenEight = "4_7_8_breathing"
    case equalBreathing = "equal_breathing"
    case bellowsBreath = "bellows_breath"
    case coherentBreathing = "coherent_breathing"
    
    var displayName: String {
        switch self {
        case .boxBreathing: return "Box Breathing"
        case .fourSevenEight: return "4-7-8 Breathing"
        case .equalBreathing: return "Equal Breathing"
        case .bellowsBreath: return "Bellows Breath"
        case .coherentBreathing: return "Coherent Breathing"
        }
    }
    
    var description: String {
        switch self {
        case .boxBreathing: return "4-count breathing for balance and focus"
        case .fourSevenEight: return "Powerful technique for relaxation and sleep"
        case .equalBreathing: return "Balance your nervous system"
        case .bellowsBreath: return "Energizing breath for vitality"
        case .coherentBreathing: return "5-second rhythm for heart coherence"
        }
    }
}

enum GroundingExerciseType: String, CaseIterable {
    case fiveFourThreeTwoOne = "5_4_3_2_1"
    case bodyScan = "body_scan"
    case presentMoment = "present_moment"
    case earthConnection = "earth_connection"
    
    var displayName: String {
        switch self {
        case .fiveFourThreeTwoOne: return "5-4-3-2-1 Technique"
        case .bodyScan: return "Body Scan"
        case .presentMoment: return "Present Moment Awareness"
        case .earthConnection: return "Earth Connection"
        }
    }
}

enum MindfulnessType: String, CaseIterable {
    case bodyAwareness = "body_awareness"
    case thoughtObservation = "thought_observation"
    case emotionAcceptance = "emotion_acceptance"
    case lovingKindness = "loving_kindness"
    
    var displayName: String {
        switch self {
        case .bodyAwareness: return "Body Awareness"
        case .thoughtObservation: return "Thought Observation"
        case .emotionAcceptance: return "Emotion Acceptance"
        case .lovingKindness: return "Loving Kindness"
        }
    }
}

struct InterventionScript {
    let title: String
    let description: String
    let estimatedDuration: TimeInterval
    let segments: [InterventionSegment]
}

struct InterventionSegment {
    let text: String
    let emotion: EmotionType
    let speed: Double
    let stability: Double
    let pauseDuration: TimeInterval
    let hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle?
}

// MARK: - Intervention Scripts

class InterventionScripts {
    
    // MARK: - Emotional Prompt Scripts
    
    func getEmotionalPromptScript(type: EmotionalPromptType, emotion: EmotionType) -> InterventionScript {
        switch type {
        case .gratitude:
            return createGratitudeScript(emotion: emotion)
        case .selfCompassion:
            return createSelfCompassionScript(emotion: emotion)
        case .valuesExploration:
            return createValuesExplorationScript(emotion: emotion)
        case .strengthsRecognition:
            return createStrengthsRecognitionScript(emotion: emotion)
        case .emotionalProcessing:
            return createEmotionalProcessingScript(emotion: emotion)
        case .futureVisioning:
            return createFutureVisioningScript(emotion: emotion)
        }
    }
    
    private func createGratitudeScript(emotion: EmotionType) -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "Let's take a moment to explore gratitude together. Find a comfortable position and take a deep breath with me.",
                emotion: .neutral,
                speed: 0.9,
                stability: 0.8,
                pauseDuration: 3.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Think about three things you're genuinely grateful for today. They can be big or small, simple or profound.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 15.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Now, for each one, ask yourself: Why does this matter to you? How does it make you feel?",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 20.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Take a moment to really feel that gratitude in your body. Notice where you feel it - perhaps in your heart, your chest, or as a warm feeling throughout your body.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 15.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Carry this feeling of gratitude with you. You can return to these thoughts whenever you need a moment of positivity.",
                emotion: .joy,
                speed: 0.9,
                stability: 0.8,
                pauseDuration: 3.0,
                hapticFeedback: .medium
            )
        ]
        
        return InterventionScript(
            title: "Gratitude Reflection",
            description: "A guided exploration of gratitude to shift your perspective",
            estimatedDuration: 180, // 3 minutes
            segments: segments
        )
    }
    
    private func createSelfCompassionScript(emotion: EmotionType) -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "Right now, you might be experiencing some difficult emotions. That's completely human and okay.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 4.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Imagine a good friend was going through exactly what you're experiencing right now. What would you say to them?",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 20.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "How would you comfort them? What tone of voice would you use? What kind words would you offer?",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 15.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Now, can you offer yourself that same kindness? You deserve the same compassion you would give to someone you care about.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Place your hand on your heart and repeat after me: 'I am human. I am worthy of kindness. I am doing my best.'",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: .medium
            )
        ]
        
        return InterventionScript(
            title: "Self-Compassion Practice",
            description: "Learn to treat yourself with the same kindness you'd show a friend",
            estimatedDuration: 240, // 4 minutes
            segments: segments
        )
    }
    
    private func createValuesExplorationScript(emotion: EmotionType) -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "Let's explore what truly matters to you. Your values are your inner compass, guiding you toward a meaningful life.",
                emotion: .neutral,
                speed: 0.9,
                stability: 0.8,
                pauseDuration: 4.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Think about a time when you felt most proud of yourself. What were you doing? What values were you expressing?",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 20.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Now consider: What values are most important to you? Perhaps honesty, creativity, connection, growth, or service to others?",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 25.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "How are you living these values today? What's one small way you could honor your values more fully?",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 15.0,
                hapticFeedback: .light
            )
        ]
        
        return InterventionScript(
            title: "Values Exploration",
            description: "Connect with what matters most to you",
            estimatedDuration: 200, // 3.3 minutes
            segments: segments
        )
    }
    
    private func createStrengthsRecognitionScript(emotion: EmotionType) -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "You have unique strengths and qualities that make you who you are. Let's take time to recognize them.",
                emotion: .joy,
                speed: 0.9,
                stability: 0.8,
                pauseDuration: 4.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Think about a challenge you've overcome in the past. What strengths did you use? What qualities helped you through?",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 20.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "What do others appreciate about you? What compliments do you receive? What do people come to you for?",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 18.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Acknowledge these strengths. They are real, they are yours, and they will help you navigate whatever comes next.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: .medium
            )
        ]
        
        return InterventionScript(
            title: "Strengths Recognition",
            description: "Acknowledge your unique qualities and capabilities",
            estimatedDuration: 180, // 3 minutes
            segments: segments
        )
    }
    
    private func createEmotionalProcessingScript(emotion: EmotionType) -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "Emotions are information. They tell us something important about our experience. Let's listen to what yours are saying.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 5.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "What emotion are you feeling right now? Can you name it? Where do you feel it in your body?",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 15.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "What might this emotion be trying to tell you? What need or value might it be highlighting?",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 20.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Can you sit with this emotion without trying to change it? Just acknowledge it, like greeting an old friend.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 15.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Thank your emotion for the information it's providing. You don't have to act on it, but you can appreciate its message.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: .medium
            )
        ]
        
        return InterventionScript(
            title: "Emotional Processing",
            description: "Learn to listen to and understand your emotions",
            estimatedDuration: 240, // 4 minutes
            segments: segments
        )
    }
    
    private func createFutureVisioningScript(emotion: EmotionType) -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "Let's take a journey into your future self. Imagine yourself one year from now, living your best life.",
                emotion: .joy,
                speed: 0.9,
                stability: 0.8,
                pauseDuration: 5.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "What does your life look like? How do you spend your days? What brings you joy and fulfillment?",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 20.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "How do you feel in this future? What emotions dominate your experience? What has changed from today?",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 18.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "What's one small step you could take today to move toward this vision? What would your future self thank you for?",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 15.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Hold onto this vision. Let it inspire and guide you. Your future self is cheering you on.",
                emotion: .joy,
                speed: 0.9,
                stability: 0.8,
                pauseDuration: 5.0,
                hapticFeedback: .medium
            )
        ]
        
        return InterventionScript(
            title: "Future Visioning",
            description: "Connect with your aspirations and possibilities",
            estimatedDuration: 240, // 4 minutes
            segments: segments
        )
    }
    
    // MARK: - Breathing Exercise Scripts
    
    func getBreathingScript(type: BreathingExerciseType, duration: TimeInterval) -> InterventionScript {
        switch type {
        case .boxBreathing:
            return createBoxBreathingScript(duration: duration)
        case .fourSevenEight:
            return createFourSevenEightScript(duration: duration)
        case .equalBreathing:
            return createEqualBreathingScript(duration: duration)
        case .bellowsBreath:
            return createBellowsBreathScript(duration: duration)
        case .coherentBreathing:
            return createCoherentBreathingScript(duration: duration)
        }
    }
    
    private func createBoxBreathingScript(duration: TimeInterval) -> InterventionScript {
        let cycles = Int(duration / 16) // Each cycle is 16 seconds
        var segments: [InterventionSegment] = []
        
        // Introduction
        segments.append(InterventionSegment(
            text: "Welcome to box breathing. We'll breathe in a square pattern: inhale for 4, hold for 4, exhale for 4, hold for 4. Let's begin.",
            emotion: .neutral,
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 3.0,
            hapticFeedback: .light
        ))
        
        // Breathing cycles
        for cycle in 1...cycles {
            segments.append(contentsOf: [
                InterventionSegment(
                    text: "Breathe in... 2... 3... 4",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: .light
                ),
                InterventionSegment(
                    text: "Hold... 2... 3... 4",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: nil
                ),
                InterventionSegment(
                    text: "Breathe out... 2... 3... 4",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: .light
                ),
                InterventionSegment(
                    text: "Hold... 2... 3... 4",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: nil
                )
            ])
            
            // Encouragement every few cycles
            if cycle % 5 == 0 && cycle < cycles {
                segments.append(InterventionSegment(
                    text: "You're doing great. Keep following the rhythm.",
                    emotion: .joy,
                    speed: 0.8,
                    stability: 0.9,
                    pauseDuration: 1.0,
                    hapticFeedback: .medium
                ))
            }
        }
        
        // Conclusion
        segments.append(InterventionSegment(
            text: "Excellent work. Notice how you feel now compared to when we started. Take this sense of calm with you.",
            emotion: .joy,
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 3.0,
            hapticFeedback: .medium
        ))
        
        return InterventionScript(
            title: "Box Breathing",
            description: "4-count breathing for balance and focus",
            estimatedDuration: duration,
            segments: segments
        )
    }
    
    private func createFourSevenEightScript(duration: TimeInterval) -> InterventionScript {
        let cycles = Int(duration / 19) // Each cycle is 19 seconds
        var segments: [InterventionSegment] = []
        
        // Introduction
        segments.append(InterventionSegment(
            text: "This is the 4-7-8 breathing technique. Inhale for 4, hold for 7, exhale for 8. This powerful pattern promotes deep relaxation.",
            emotion: .neutral,
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 4.0,
            hapticFeedback: .light
        ))
        
        // Breathing cycles
        for cycle in 1...cycles {
            segments.append(contentsOf: [
                InterventionSegment(
                    text: "Inhale through your nose... 2... 3... 4",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: .light
                ),
                InterventionSegment(
                    text: "Hold your breath... 2... 3... 4... 5... 6... 7",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: nil
                ),
                InterventionSegment(
                    text: "Exhale through your mouth... 2... 3... 4... 5... 6... 7... 8",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 1.0,
                    hapticFeedback: .light
                )
            ])
        }
        
        // Conclusion
        segments.append(InterventionSegment(
            text: "Beautiful. Feel the deep relaxation spreading through your body. This technique is always available to you.",
            emotion: .joy,
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 3.0,
            hapticFeedback: .medium
        ))
        
        return InterventionScript(
            title: "4-7-8 Breathing",
            description: "Powerful technique for relaxation and sleep",
            estimatedDuration: duration,
            segments: segments
        )
    }
    
    private func createEqualBreathingScript(duration: TimeInterval) -> InterventionScript {
        let cycles = Int(duration / 12) // Each cycle is 12 seconds
        var segments: [InterventionSegment] = []
        
        // Introduction
        segments.append(InterventionSegment(
            text: "Equal breathing creates balance in your nervous system. We'll breathe in for 6 counts and out for 6 counts.",
            emotion: .neutral,
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 3.0,
            hapticFeedback: .light
        ))
        
        // Breathing cycles
        for cycle in 1...cycles {
            segments.append(contentsOf: [
                InterventionSegment(
                    text: "Breathe in... 2... 3... 4... 5... 6",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: .light
                ),
                InterventionSegment(
                    text: "Breathe out... 2... 3... 4... 5... 6",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: .light
                )
            ])
        }
        
        // Conclusion
        segments.append(InterventionSegment(
            text: "Perfect. Notice the balance and equilibrium you've created. Your nervous system is now more balanced.",
            emotion: .joy,
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 3.0,
            hapticFeedback: .medium
        ))
        
        return InterventionScript(
            title: "Equal Breathing",
            description: "Balance your nervous system with equal inhales and exhales",
            estimatedDuration: duration,
            segments: segments
        )
    }
    
    private func createBellowsBreathScript(duration: TimeInterval) -> InterventionScript {
        let cycles = Int(duration / 30) // Each cycle is 30 seconds
        var segments: [InterventionSegment] = []
        
        // Introduction
        segments.append(InterventionSegment(
            text: "Bellows breath is an energizing technique. We'll do rapid, rhythmic breathing to increase energy and alertness.",
            emotion: .joy,
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 3.0,
            hapticFeedback: .medium
        ))
        
        // Breathing cycles
        for cycle in 1...cycles {
            segments.append(InterventionSegment(
                text: "Begin rapid breathing now. In and out, in and out, keep the rhythm strong and steady.",
                emotion: .joy,
                speed: 0.9,
                stability: 0.8,
                pauseDuration: 20.0, // 20 seconds of rapid breathing
                hapticFeedback: .heavy
            ))
            
            segments.append(InterventionSegment(
                text: "Now breathe normally and rest. Feel the energy and vitality flowing through you.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: .light
            ))
        }
        
        // Conclusion
        segments.append(InterventionSegment(
            text: "Excellent! You've awakened your energy. Use this vitality to power through your day.",
            emotion: .joy,
            speed: 0.9,
            stability: 0.8,
            pauseDuration: 3.0,
            hapticFeedback: .heavy
        ))
        
        return InterventionScript(
            title: "Bellows Breath",
            description: "Energizing breath for vitality and alertness",
            estimatedDuration: duration,
            segments: segments
        )
    }
    
    private func createCoherentBreathingScript(duration: TimeInterval) -> InterventionScript {
        let cycles = Int(duration / 10) // Each cycle is 10 seconds
        var segments: [InterventionSegment] = []
        
        // Introduction
        segments.append(InterventionSegment(
            text: "Coherent breathing creates heart rhythm coherence. We'll breathe at 5 seconds in, 5 seconds out.",
            emotion: .neutral,
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 3.0,
            hapticFeedback: .light
        ))
        
        // Breathing cycles
        for cycle in 1...cycles {
            segments.append(contentsOf: [
                InterventionSegment(
                    text: "Breathe in... 2... 3... 4... 5",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: .light
                ),
                InterventionSegment(
                    text: "Breathe out... 2... 3... 4... 5",
                    emotion: .neutral,
                    speed: 0.6,
                    stability: 0.9,
                    pauseDuration: 0.0,
                    hapticFeedback: .light
                )
            ])
        }
        
        // Conclusion
        segments.append(InterventionSegment(
            text: "Wonderful. You've created coherence between your heart and mind. This is the rhythm of optimal wellbeing.",
            emotion: .joy,
            speed: 0.8,
            stability: 0.9,
            pauseDuration: 3.0,
            hapticFeedback: .medium
        ))
        
        return InterventionScript(
            title: "Coherent Breathing",
            description: "5-second rhythm for heart-mind coherence",
            estimatedDuration: duration,
            segments: segments
        )
    }
    
    // MARK: - Grounding Exercise Scripts
    
    func getGroundingScript(type: GroundingExerciseType) -> InterventionScript {
        switch type {
        case .fiveFourThreeTwoOne:
            return createFiveFourThreeTwoOneScript()
        case .bodyScan:
            return createBodyScanScript()
        case .presentMoment:
            return createPresentMomentScript()
        case .earthConnection:
            return createEarthConnectionScript()
        }
    }
    
    private func createFiveFourThreeTwoOneScript() -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "The 5-4-3-2-1 technique helps ground you in the present moment using your five senses. Let's begin.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 3.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "First, look around and name 5 things you can see. Take your time with each one.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 20.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Now, notice 4 things you can touch or feel. The texture of your clothes, the temperature of the air, the surface you're sitting on.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 15.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Listen carefully and identify 3 things you can hear. Maybe sounds from outside, your own breathing, or the hum of electronics.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 15.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Notice 2 things you can smell. Take a gentle breath in through your nose.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Finally, notice 1 thing you can taste. Perhaps the lingering taste of something you drank, or just the taste in your mouth right now.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Perfect. You're fully present now, grounded in this moment through your senses.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 3.0,
                hapticFeedback: .medium
            )
        ]
        
        return InterventionScript(
            title: "5-4-3-2-1 Grounding",
            description: "Ground yourself using all five senses",
            estimatedDuration: 300, // 5 minutes
            segments: segments
        )
    }
    
    private func createBodyScanScript() -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "Let's do a body scan to connect with your physical presence. Start by taking three deep breaths.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Begin at the top of your head. Notice any sensations - warmth, coolness, tension, or relaxation.",
                emotion: .neutral,
                speed: 0.7,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Move your attention to your forehead, your eyes, your jaw. Notice without trying to change anything.",
                emotion: .neutral,
                speed: 0.7,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Scan down to your neck and shoulders. Are they tense or relaxed? Just observe.",
                emotion: .neutral,
                speed: 0.7,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Continue down your arms to your hands. Notice the sensations in your fingers.",
                emotion: .neutral,
                speed: 0.7,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Move to your chest and heart area. Feel your breath moving in and out.",
                emotion: .neutral,
                speed: 0.7,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Scan your abdomen, your back, your hips. Notice how your body feels supported.",
                emotion: .neutral,
                speed: 0.7,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Finally, scan down your legs to your feet. Feel your connection to the ground.",
                emotion: .neutral,
                speed: 0.7,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Take a moment to appreciate your whole body. You are present, you are grounded, you are here.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 5.0,
                hapticFeedback: .medium
            )
        ]
        
        return InterventionScript(
            title: "Body Scan Grounding",
            description: "Connect with your physical presence through body awareness",
            estimatedDuration: 360, // 6 minutes
            segments: segments
        )
    }
    
    private func createPresentMomentScript() -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "This moment is the only moment that truly exists. Let's anchor ourselves here, now.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 4.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Notice that you are breathing. You don't have to control it, just observe this automatic miracle.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Right now, in this moment, you are safe. You are here. You are alive.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "The past is memory. The future is imagination. But this moment is real, and you are in it.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Whatever challenges exist, they are not here in this peaceful moment. You can return to this awareness anytime.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: .medium
            )
        ]
        
        return InterventionScript(
            title: "Present Moment Awareness",
            description: "Anchor yourself in the here and now",
            estimatedDuration: 180, // 3 minutes
            segments: segments
        )
    }
    
    private func createEarthConnectionScript() -> InterventionScript {
        let segments = [
            InterventionSegment(
                text: "Let's connect with the earth beneath you, feeling supported and grounded by this ancient presence.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 4.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Feel your feet on the ground, or your body in the chair. Notice how the earth supports you completely.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "Imagine roots growing from your body down into the earth, anchoring you, nourishing you.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 12.0,
                hapticFeedback: nil
            ),
            InterventionSegment(
                text: "Feel the stability and strength of the earth flowing up through these roots into your body.",
                emotion: .neutral,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 10.0,
                hapticFeedback: .light
            ),
            InterventionSegment(
                text: "You are connected to something vast and enduring. You belong here. You are supported.",
                emotion: .joy,
                speed: 0.8,
                stability: 0.9,
                pauseDuration: 8.0,
                hapticFeedback: .medium
            )
        ]
        
        return InterventionScript(
            title: "Earth Connection",
            description: "Feel supported and grounded by your connection to the earth",
            estimatedDuration: 200, // 3.3 minutes
            segments: segments
        )
    }
}

// MARK: - TTS Cache Utilities
final class TTSAudioCache {
    static let shared = TTSAudioCache()
    private init() {}
    private let fm = FileManager.default
    private var cacheDir: URL {
        let url = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("tts-cache")
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    func keyFor(text: String, emotion: String, speed: Double, stability: Double) -> String {
        let base = "\(emotion)|\(String(format: "%.2f", speed))|\(String(format: "%.2f", stability))|" + text
        return String(base.hashValue)
    }
    func path(for key: String) -> URL { cacheDir.appendingPathComponent(key + ".m4a") }
    func cachedURL(for key: String) -> URL? {
        let url = path(for: key)
        return fm.fileExists(atPath: url.path) ? url : nil
    }
    func storeToCache(sourceURL: URL, key: String) throws -> URL {
        let dest = path(for: key)
        if fm.fileExists(atPath: dest.path) { return dest }
        try fm.copyItem(at: sourceURL, to: dest)
        return dest
    }
}


// MARK: - Audio Player Delegate

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let completion: (Bool) -> Void
    
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion(flag)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        completion(false)
    }
}

// MARK: - Error Types

enum VoiceGuidedInterventionError: LocalizedError {
    case playbackFailed
    case audioGenerationFailed
    case invalidScript
    
    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            return "Audio playback failed"
        case .audioGenerationFailed:
            return "Failed to generate voice audio"
        case .invalidScript:
            return "Invalid intervention script"
        }
    }
}

