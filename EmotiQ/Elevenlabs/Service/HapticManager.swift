//
//  HapticManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import UIKit
import CoreHaptics
import SwiftUI

// MARK: - Haptic Manager
@MainActor
class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    @Published var isHapticsEnabled = true
    
    private var hapticEngine: CHHapticEngine?
    private let impactFeedback = UIImpactFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    private init() {
        setupHapticEngine()
        loadHapticPreferences()
    }
    
    // MARK: - Setup
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
        
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
          
                do {
                    try self?.hapticEngine?.start()
                } catch {
             
                }
            }
            
            // Handle engine stopped
            hapticEngine?.stoppedHandler = { reason in
          
            }
            
        } catch {
            
        }
    }
    
    private func loadHapticPreferences() {
        isHapticsEnabled = UserDefaults.standard.bool(forKey: "haptics_enabled")
        if UserDefaults.standard.object(forKey: "haptics_enabled") == nil {
            isHapticsEnabled = true // Default to enabled
        }
    }
    
    func saveHapticPreferences() {
        UserDefaults.standard.set(isHapticsEnabled, forKey: "haptics_enabled")
    }
    
    // MARK: - Basic Haptic Feedback
    
    /// Trigger impact haptic feedback
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isHapticsEnabled else { return }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Trigger notification haptic feedback
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticsEnabled else { return }
        
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(type)
    }
    
    /// Trigger selection haptic feedback
    func selection() {
        guard isHapticsEnabled else { return }
        
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Emotional Haptic Patterns
    
    /// Haptic pattern for different emotions
    func emotionalFeedback(for emotion: EmotionType) {
        guard isHapticsEnabled else { return }
        
        switch emotion {
        case .joy:
            playJoyfulPattern()
        case .sadness:
            playSadnessPattern()
        case .anger:
            playAngerPattern()
        case .fear:
            playFearPattern()
        case .surprise:
            playSurprisePattern()
        case .disgust:
            playDisgustPattern()
        case .neutral:
            playNeutralPattern()
        }
    }
    
    private func playJoyfulPattern() {
        // Uplifting, bouncy pattern
        let pattern = [
            (intensity: Float(0.6), sharpness: Float(0.8), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(0.8), sharpness: Float(0.9), duration: 0.15),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(1.0), sharpness: Float(1.0), duration: 0.2)
        ]
        playCustomPattern(pattern)
    }
    
    private func playSadnessPattern() {
        // Gentle, slow pattern
        let pattern = [
            (intensity: Float(0.3), sharpness: Float(0.2), duration: 0.3),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.1),
            (intensity: Float(0.4), sharpness: Float(0.3), duration: 0.4),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.2),
            (intensity: Float(0.2), sharpness: Float(0.1), duration: 0.5)
        ]
        playCustomPattern(pattern)
    }
    
    private func playAngerPattern() {
        // Sharp, intense pattern
        let pattern = [
            (intensity: Float(1.0), sharpness: Float(1.0), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.02),
            (intensity: Float(1.0), sharpness: Float(1.0), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.02),
            (intensity: Float(0.8), sharpness: Float(0.9), duration: 0.15)
        ]
        playCustomPattern(pattern)
    }
    
    private func playFearPattern() {
        // Quick, nervous pattern
        let pattern = [
            (intensity: Float(0.4), sharpness: Float(0.8), duration: 0.05),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.03),
            (intensity: Float(0.5), sharpness: Float(0.9), duration: 0.05),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.03),
            (intensity: Float(0.6), sharpness: Float(1.0), duration: 0.05),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.1),
            (intensity: Float(0.3), sharpness: Float(0.7), duration: 0.1)
        ]
        playCustomPattern(pattern)
    }
    
    private func playSurprisePattern() {
        // Sudden, then settling pattern
        let pattern = [
            (intensity: Float(1.0), sharpness: Float(1.0), duration: 0.05),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.1),
            (intensity: Float(0.6), sharpness: Float(0.4), duration: 0.2),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(0.3), sharpness: Float(0.2), duration: 0.3)
        ]
        playCustomPattern(pattern)
    }
    
    private func playDisgustPattern() {
        // Uncomfortable, irregular pattern
        let pattern = [
            (intensity: Float(0.5), sharpness: Float(0.3), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.08),
            (intensity: Float(0.3), sharpness: Float(0.5), duration: 0.12),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.15),
            (intensity: Float(0.4), sharpness: Float(0.2), duration: 0.2)
        ]
        playCustomPattern(pattern)
    }
    
    private func playNeutralPattern() {
        // Balanced, steady pattern
        let pattern = [
            (intensity: Float(0.5), sharpness: Float(0.5), duration: 0.15),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(0.5), sharpness: Float(0.5), duration: 0.15)
        ]
        playCustomPattern(pattern)
    }
    
    // MARK: - Breathing Sync Haptics
    
    /// Haptic pattern synchronized with breathing exercises
    func breathingSync(phase: BreathingPhase, duration: TimeInterval) {
        guard isHapticsEnabled else { return }
        
        switch phase {
        case .inhale:
            playBreathingInhalePattern(duration: duration)
        case .hold:
            playBreathingHoldPattern(duration: duration)
        case .exhale:
            playBreathingExhalePattern(duration: duration)
        case .pause:
            playBreathingPausePattern(duration: duration)
        }
    }
    
    private func playBreathingInhalePattern(duration: TimeInterval) {
        // Gradually increasing intensity
        let steps = Int(duration * 10) // 10 steps per second
        var events: [CHHapticEvent] = []
        
        for i in 0..<steps {
            let time = TimeInterval(i) * 0.1
            let intensity = Float(i) / Float(steps) * 0.6 // Max 0.6 intensity
            
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: time,
                duration: 0.1
            )
            events.append(event)
        }
        
        playHapticEvents(events)
    }
    
    private func playBreathingExhalePattern(duration: TimeInterval) {
        // Gradually decreasing intensity
        let steps = Int(duration * 10)
        var events: [CHHapticEvent] = []
        
        for i in 0..<steps {
            let time = TimeInterval(i) * 0.1
            let intensity = Float(steps - i) / Float(steps) * 0.6
            
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: time,
                duration: 0.1
            )
            events.append(event)
        }
        
        playHapticEvents(events)
    }
    
    private func playBreathingHoldPattern(duration: TimeInterval) {
        // Steady, gentle vibration
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0,
            duration: duration
        )
        
        playHapticEvents([event])
    }
    
    private func playBreathingPausePattern(duration: TimeInterval) {
        // Very light, intermittent pulses
        var events: [CHHapticEvent] = []
        let pulseInterval = 0.5
        let pulseCount = Int(duration / pulseInterval)
        
        for i in 0..<pulseCount {
            let time = TimeInterval(i) * pulseInterval
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                ],
                relativeTime: time
            )
            events.append(event)
        }
        
        playHapticEvents(events)
    }
    
    // MARK: - Achievement Celebrations
    
    /// Celebratory haptic pattern for achievements
    func celebration(_ type: CelebrationType) {
        guard isHapticsEnabled else { return }
        
        switch type {
        case .goalCompleted:
            playGoalCompletionPattern()
        case .streakAchieved:
            playStreakPattern()
        case .levelUp:
            playLevelUpPattern()
        case .dailyGoalMet:
            playDailyGoalPattern()
        case .weeklyGoalMet:
            playWeeklyGoalPattern()
        case .perfectWeek:
            playPerfectWeekPattern()
        }
    }
    
    private func playGoalCompletionPattern() {
        // Triumphant, building pattern
        let pattern = [
            (intensity: Float(0.4), sharpness: Float(0.6), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(0.6), sharpness: Float(0.8), duration: 0.15),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(0.8), sharpness: Float(0.9), duration: 0.2),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(1.0), sharpness: Float(1.0), duration: 0.3)
        ]
        playCustomPattern(pattern)
    }
    
    private func playStreakPattern() {
        // Rhythmic, consistent pattern
        let pattern = [
            (intensity: Float(0.6), sharpness: Float(0.8), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.1),
            (intensity: Float(0.6), sharpness: Float(0.8), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.1),
            (intensity: Float(0.6), sharpness: Float(0.8), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.1),
            (intensity: Float(0.8), sharpness: Float(1.0), duration: 0.2)
        ]
        playCustomPattern(pattern)
    }
    
    private func playLevelUpPattern() {
        // Ascending, powerful pattern
        let pattern = [
            (intensity: Float(0.3), sharpness: Float(0.4), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.03),
            (intensity: Float(0.5), sharpness: Float(0.6), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.03),
            (intensity: Float(0.7), sharpness: Float(0.8), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.03),
            (intensity: Float(1.0), sharpness: Float(1.0), duration: 0.25)
        ]
        playCustomPattern(pattern)
    }
    
    private func playDailyGoalPattern() {
        // Satisfying completion pattern
        let pattern = [
            (intensity: Float(0.5), sharpness: Float(0.7), duration: 0.15),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(0.7), sharpness: Float(0.8), duration: 0.2)
        ]
        playCustomPattern(pattern)
    }
    
    private func playWeeklyGoalPattern() {
        // Extended celebration pattern
        let pattern = [
            (intensity: Float(0.4), sharpness: Float(0.6), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(0.6), sharpness: Float(0.7), duration: 0.15),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(0.8), sharpness: Float(0.9), duration: 0.2),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.1),
            (intensity: Float(0.5), sharpness: Float(0.6), duration: 0.3)
        ]
        playCustomPattern(pattern)
    }
    
    private func playPerfectWeekPattern() {
        // Epic celebration pattern
        let pattern = [
            (intensity: Float(0.3), sharpness: Float(0.5), duration: 0.08),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.02),
            (intensity: Float(0.5), sharpness: Float(0.7), duration: 0.08),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.02),
            (intensity: Float(0.7), sharpness: Float(0.8), duration: 0.1),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.02),
            (intensity: Float(0.9), sharpness: Float(0.9), duration: 0.12),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.05),
            (intensity: Float(1.0), sharpness: Float(1.0), duration: 0.3),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.1),
            (intensity: Float(0.6), sharpness: Float(0.7), duration: 0.2)
        ]
        playCustomPattern(pattern)
    }
    
    // MARK: - UI Interaction Haptics
    
    /// Addictive button press haptic
    func buttonPress(_ style: ButtonPressStyle = .standard) {
        guard isHapticsEnabled else { return }
        
        switch style {
        case .standard:
            impact(.light)
        case .primary:
            impact(.medium)
        case .destructive:
            impact(.heavy)
        case .subtle:
            selection()
        case .satisfying:
            playSatisfyingButtonPress()
        }
    }
    
    private func playSatisfyingButtonPress() {
        let pattern = [
            (intensity: Float(0.8), sharpness: Float(0.9), duration: 0.05),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.02),
            (intensity: Float(0.4), sharpness: Float(0.5), duration: 0.08)
        ]
        playCustomPattern(pattern)
    }
    
    /// Navigation transition haptic
    func navigationTransition() {
        guard isHapticsEnabled else { return }
        
        let pattern = [
            (intensity: Float(0.3), sharpness: Float(0.6), duration: 0.05),
            (intensity: Float(0.0), sharpness: Float(0.0), duration: 0.03),
            (intensity: Float(0.5), sharpness: Float(0.4), duration: 0.1)
        ]
        playCustomPattern(pattern)
    }
    
    /// Tab switch haptic
    func tabSwitch() {
        guard isHapticsEnabled else { return }
        selection()
    }
    
    /// Scroll feedback haptic
    func scrollFeedback() {
        guard isHapticsEnabled else { return }
        
        let pattern = [
            (intensity: Float(0.2), sharpness: Float(0.8), duration: 0.03)
        ]
        playCustomPattern(pattern)
    }
    
    // MARK: - Custom Pattern Playback
    
    private func playCustomPattern(_ pattern: [(intensity: Float, sharpness: Float, duration: TimeInterval)]) {
        guard let engine = hapticEngine else {
            // Fallback to basic haptics
            impact(.medium)
            return
        }
        
        var events: [CHHapticEvent] = []
        var currentTime: TimeInterval = 0
        
        for step in pattern {
            if step.intensity > 0 {
                let event = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: step.intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: step.sharpness)
                    ],
                    relativeTime: currentTime,
                    duration: step.duration
                )
                events.append(event)
            }
            currentTime += step.duration
        }
        
        playHapticEvents(events)
    }
    
    private func playHapticEvents(_ events: [CHHapticEvent]) {
        guard let engine = hapticEngine, !events.isEmpty else { return }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
        
            // Fallback to basic haptic
            impact(.medium)
        }
    }
}

// MARK: - Data Models

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

enum CelebrationType {
    case goalCompleted
    case streakAchieved
    case levelUp
    case dailyGoalMet
    case weeklyGoalMet
    case perfectWeek
}

enum ButtonPressStyle {
    case standard
    case primary
    case destructive
    case subtle
    case satisfying
}

// MARK: - SwiftUI Integration

extension View {
    /// Add haptic feedback to button presses
    func hapticFeedback(_ style: ButtonPressStyle = .standard) -> some View {
        self.onTapGesture {
            HapticManager.shared.buttonPress(style)
        }
    }
    
    /// Add haptic feedback with custom action
    func hapticFeedback(_ style: ButtonPressStyle = .standard, action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            HapticManager.shared.buttonPress(style)
            action()
        }
    }
}

