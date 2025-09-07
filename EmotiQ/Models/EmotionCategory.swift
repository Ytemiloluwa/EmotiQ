//
//  EmotionCategory.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import Foundation
import SwiftUI

// MARK: - Emotion Category Model
/// Represents the 7 core emotion categories used in EmotiQ's analysis system
/// Based on psychological research and optimized for voice analysis accuracy
enum EmotionCategory: String, CaseIterable, Identifiable {
    case joy = "joy"
    case sadness = "sadness"
    case anger = "anger"
    case fear = "fear"
    case surprise = "surprise"
    case disgust = "disgust"
    case neutral = "neutral"
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    var displayName: String {
        switch self {
        case .joy: return "Joy"
        case .sadness: return "Sadness"
        case .anger: return "Anger"
        case .fear: return "Fear"
        case .surprise: return "Surprise"
        case .disgust: return "Disgust"
        case .neutral: return "Neutral"
        }
    }
    
    var emoji: String {
        switch self {
        case .joy: return "😊"
        case .sadness: return "😢"
        case .anger: return "😠"
        case .fear: return "😰"
        case .surprise: return "😲"
        case .disgust: return "🤢"
        case .neutral: return "😐"
        }
    }
    
    var hexcolor: Color {
        switch self {
        case .joy: return .yellow
        case .sadness: return .blue
        case .anger: return .red
        case .fear: return .purple
        case .surprise: return .orange
        case .disgust: return .green
        case .neutral: return .gray
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .joy: return [.yellow, .orange]
        case .sadness: return [.blue, .indigo]
        case .anger: return [.red, .pink]
        case .fear: return [.purple, .indigo]
        case .surprise: return [.orange, .yellow]
        case .disgust: return [.green, .mint]
        case .neutral: return [.gray, .secondary]
        }
    }
    
    // MARK: - Coaching Properties
    var description: String {
        switch self {
        case .joy:
            return "A positive emotional state characterized by happiness, contentment, and satisfaction."
        case .sadness:
            return "A natural emotional response to loss, disappointment, or challenging situations."
        case .anger:
            return "An intense emotional response often triggered by frustration, injustice, or threat."
        case .fear:
            return "A protective emotional response to perceived danger or uncertainty."
        case .surprise:
            return "A brief emotional response to unexpected events or new information."
        case .disgust:
            return "An emotional response to something unpleasant or morally objectionable."
        case .neutral:
            return "A balanced emotional state without strong positive or negative feelings."
        }
    }
    
    var coachingTip: String {
        switch self {
        case .joy:
            return "Embrace this positive energy! Consider sharing your joy with others or using this momentum for creative activities."
        case .sadness:
            return "It's okay to feel sad. Allow yourself to process these emotions and consider reaching out to supportive friends or family."
        case .anger:
            return "Take deep breaths and pause before reacting. Consider what triggered this feeling and how you might address it constructively."
        case .fear:
            return "Acknowledge your fear without judgment. Break down what you're afraid of into smaller, manageable parts."
        case .surprise:
            return "Stay curious about this unexpected moment. Surprise can lead to new opportunities and learning experiences."
        case .disgust:
            return "Notice what's causing this reaction. Sometimes disgust signals important boundaries or values that need attention."
        case .neutral:
            return "This balanced state is perfect for reflection and planning. Consider setting intentions for how you'd like to feel."
        }
    }
    
    /// Enhanced coaching recommendations based on intensity level and sub-emotion
    func getEnhancedCoaching(intensity: EmotionIntensity, subEmotion: SubEmotion) -> EnhancedCoaching {
        let baseStrategy = getIntensitySpecificStrategy(intensity: intensity)
        let subEmotionGuidance = getSubEmotionGuidance(subEmotion: subEmotion, intensity: intensity)
        let actionSteps = getActionSteps(emotion: self, intensity: intensity, subEmotion: subEmotion)
        
        return EnhancedCoaching(
            primaryStrategy: baseStrategy,
            subEmotionGuidance: subEmotionGuidance,
            actionSteps: actionSteps,
            urgencyLevel: getUrgencyLevel(intensity: intensity),
            timeframe: getRecommendedTimeframe(intensity: intensity),
            followUpSuggestions: getFollowUpSuggestions(emotion: self, intensity: intensity)
        )
    }
    
    private func getIntensitySpecificStrategy(intensity: EmotionIntensity) -> String {
        switch (self, intensity) {
        // Joy strategies
        case (.joy, .low):
            return "Gently nurture this positive feeling through small acts of self-care and appreciation."
        case (.joy, .medium):
            return "Celebrate this wonderful feeling! Share it with loved ones and use this energy for meaningful activities."
        case (.joy, .high):
            return "Channel this intense joy mindfully. Consider creative expression or planning exciting future goals while staying grounded."
            
        // Sadness strategies
        case (.sadness, .low):
            return "Acknowledge this gentle sadness. Practice self-compassion and allow yourself to feel without judgment."
        case (.sadness, .medium):
            return "Honor your sadness with healthy processing. Consider journaling, talking to someone you trust, or gentle physical activity."
        case (.sadness, .high):
            return "This intense sadness needs attention. Reach out for support, consider professional help if persistent, and focus on basic self-care."
            
        // Anger strategies
        case (.anger, .low):
            return "Notice this irritation calmly. Use it as information about your boundaries and needs."
        case (.anger, .medium):
            return "Channel this anger constructively. Exercise, express your needs clearly, or work on problem-solving."
        case (.anger, .high):
            return "This intense anger needs immediate healthy outlets. Take a break, use physical exercise, practice deep breathing, and consider talking to someone."
            
        // Fear strategies
        case (.fear, .low):
            return "Acknowledge this concern gently. Use grounding techniques and rational thinking to assess the situation."
        case (.fear, .medium):
            return "Address this fear with courage. Break down what's worrying you and take small, manageable steps forward."
        case (.fear, .high):
            return "This intense fear needs immediate attention. Focus on safety, use deep breathing, and consider seeking support or professional help."
            
        // Other emotions...
        default:
            return coachingTip
        }
    }
    
    private func getSubEmotionGuidance(subEmotion: SubEmotion, intensity: EmotionIntensity) -> String {
        let intensityModifier = intensity == .high ? "intense " : intensity == .low ? "gentle " : ""
        return "Your \(intensityModifier)\(subEmotion.displayName.lowercased()) suggests specific needs for support and growth."
    }
    
    private func getActionSteps(emotion: EmotionCategory, intensity: EmotionIntensity, subEmotion: SubEmotion) -> [String] {
        switch intensity {
        case .low:
            return ["Take gentle, mindful action", "Practice self-awareness", "Use this as learning opportunity"]
        case .medium:
            return ["Take deliberate action today", "Reach out for support if needed", "Monitor your emotional state"]
        case .high:
            return ["Take immediate action", "Seek support now", "Focus on safety and wellbeing", "Consider professional help"]
        }
    }
    
    private func getUrgencyLevel(intensity: EmotionIntensity) -> UrgencyLevel {
        switch intensity {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
    
    private func getRecommendedTimeframe(intensity: EmotionIntensity) -> String {
        switch intensity {
        case .low: return "Take gentle action over the next few days"
        case .medium: return "Address this within the next 24 hours"
        case .high: return "Take immediate action now"
        }
    }
    
    private func getFollowUpSuggestions(emotion: EmotionCategory, intensity: EmotionIntensity) -> [String] {
        let baseFollowUps = [
            "Check in with yourself regularly",
            "Notice patterns in your emotional responses",
            "Practice self-compassion"
        ]
        
        if intensity == .high {
            return baseFollowUps + [
                "Consider professional support if feelings persist",
                "Monitor your emotional wellbeing closely"
            ]
        }
        
        return baseFollowUps
    }
    
    var affirmation: String {
        switch self {
        case .joy:
            return "I embrace joy and allow it to fill my heart with gratitude and positivity."
        case .sadness:
            return "I honor my feelings and trust that this sadness will pass, making room for healing and growth."
        case .anger:
            return "I acknowledge my anger and choose to respond with wisdom and compassion."
        case .fear:
            return "I am brave and capable of facing my fears with courage and self-compassion."
        case .surprise:
            return "I welcome unexpected moments as opportunities for growth and new experiences."
        case .disgust:
            return "I trust my instincts and honor my boundaries while remaining open to understanding."
        case .neutral:
            return "I appreciate this moment of balance and use it to center myself and set positive intentions."
        }
    }
    
    // MARK: - Analysis Properties
    var intensity: EmotionIntensity {
        switch self {
        case .joy, .anger, .fear:
            return .high
        case .sadness, .surprise, .disgust:
            return .medium
        case .neutral:
            return .low
        }
    }
    
    var valence: EmotionValence {
        switch self {
        case .joy, .surprise:
            return .positive
        case .sadness, .anger, .fear, .disgust:
            return .negative
        case .neutral:
            return .neutral
        }
    }
}

// MARK: - Supporting Enums

enum EmotionValence: String, CaseIterable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    
    var displayName: String {
        switch self {
        case .positive: return "Positive"
        case .negative: return "Negative"
        case .neutral: return "Neutral"
        }
    }
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .negative: return .red
        case .neutral: return .gray
        }
    }
}

// MARK: - Emotion Analysis Result
struct EmotionAnalysisResult: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let primaryEmotion: EmotionCategory
    let subEmotion: SubEmotion
    let intensity: EmotionIntensity
    let confidence: Double
    let emotionScores: [EmotionCategory: Double]
    let subEmotionScores: [SubEmotion: Double]
    let audioQuality: AudioQuality
    let sessionDuration: TimeInterval
    
    // PRODUCTION: Real audio features extracted during analysis
    let audioFeatures: ProductionAudioFeatures?
    
    init(timestamp: Date = Date(), primaryEmotion: EmotionCategory, subEmotion: SubEmotion, intensity: EmotionIntensity, confidence: Double, emotionScores: [EmotionCategory: Double], subEmotionScores: [SubEmotion: Double], audioQuality: AudioQuality, sessionDuration: TimeInterval, audioFeatures: ProductionAudioFeatures? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.primaryEmotion = primaryEmotion
        self.subEmotion = subEmotion
        self.intensity = intensity
        self.confidence = confidence
        self.emotionScores = emotionScores
        self.subEmotionScores = subEmotionScores
        self.audioQuality = audioQuality
        self.sessionDuration = sessionDuration
        self.audioFeatures = audioFeatures
    }
    
    // Computed properties
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    var isHighConfidence: Bool {
        confidence >= 0.7
    }
    
    var secondaryEmotions: [(EmotionCategory, Double)] {
        emotionScores
            .filter { $0.key != primaryEmotion }
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map { ($0.key, $0.value) }
    }
    
    // MARK: - Equatable Implementation
    static func == (lhs: EmotionAnalysisResult, rhs: EmotionAnalysisResult) -> Bool {
        return lhs.id == rhs.id &&
               lhs.timestamp == rhs.timestamp &&
               lhs.primaryEmotion == rhs.primaryEmotion &&
               lhs.subEmotion == rhs.subEmotion &&
               lhs.intensity == rhs.intensity &&
               lhs.confidence == rhs.confidence &&
               lhs.audioQuality == rhs.audioQuality &&
               lhs.sessionDuration == rhs.sessionDuration
    }
}



// MARK: - Enhanced Coaching System

/// Enhanced coaching recommendations with intensity and sub-emotion awareness
struct EnhancedCoaching {
    let primaryStrategy: String
    let subEmotionGuidance: String
    let actionSteps: [String]
    let urgencyLevel: UrgencyLevel
    let timeframe: String
    let followUpSuggestions: [String]
}

/// Urgency levels for coaching interventions
enum UrgencyLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Urgent Attention"
        case .medium: return "Important Notice"
        case .high: return "Gentle Reminder"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .orange
        case .medium: return .yellow
        case .high: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "heart.fill"
        case .medium: return "brain.head.profile"
        case .high: return "bolt.fill"
        }
    }
}

// MARK: - Sub-Emotions and Intensity Levels

/// Sub-emotions provide granular categorization within main emotion categories
enum SubEmotion: String, CaseIterable, Identifiable {
    // Joy sub-emotions
    case happiness = "happiness"
    case excitement = "excitement"
    case contentment = "contentment"
    case euphoria = "euphoria"
    case optimism = "optimism"
    case gratitude = "gratitude"
    
    // Sadness sub-emotions
    case melancholy = "melancholy"
    case grief = "grief"
    case disappointment = "disappointment"
    case loneliness = "loneliness"
    case despair = "despair"
    case sorrow = "sorrow"
    
    // Anger sub-emotions
    case frustration = "frustration"
    case irritation = "irritation"
    case rage = "rage"
    case resentment = "resentment"
    case indignation = "indignation"
    case hostility = "hostility"
    
    // Fear sub-emotions
    case anxiety = "anxiety"
    case worry = "worry"
    case nervousness = "nervousness"
    case panic = "panic"
    case dread = "dread"
    case apprehension = "apprehension"
    
    // Surprise sub-emotions
    case amazement = "amazement"
    case astonishment = "astonishment"
    case bewilderment = "bewilderment"
    case curiosity = "curiosity"
    case confusion = "confusion"
    case wonder = "wonder"
    
    // Disgust sub-emotions
    case contempt = "contempt"
    case aversion = "aversion"
    case repulsion = "repulsion"
    case revulsion = "revulsion"
    case loathing = "loathing"
    case distaste = "distaste"
    
    // Neutral variations
    case calm = "calm"
    case balanced = "balanced"
    case stable = "stable"
    case peaceful = "peaceful"
    case composed = "composed"
    case indifferent = "indifferent"
    
    var id: String { rawValue }
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var parentEmotion: EmotionCategory {
        switch self {
        case .happiness, .excitement, .contentment, .euphoria, .optimism, .gratitude:
            return .joy
        case .melancholy, .grief, .disappointment, .loneliness, .despair, .sorrow:
            return .sadness
        case .frustration, .irritation, .rage, .resentment, .indignation, .hostility:
            return .anger
        case .anxiety, .worry, .nervousness, .panic, .dread, .apprehension:
            return .fear
        case .amazement, .astonishment, .bewilderment, .curiosity, .confusion, .wonder:
            return .surprise
        case .contempt, .aversion, .repulsion, .revulsion, .loathing, .distaste:
            return .disgust
        case .calm, .balanced, .stable, .peaceful, .composed, .indifferent:
            return .neutral
        }
    }
    
    var emoji: String {
        switch self {
        case .happiness: return "😊"
        case .excitement: return "🤩"
        case .contentment: return "😌"
        case .euphoria: return "🥳"
        case .optimism: return "😄"
        case .gratitude: return "🙏"
            
        case .melancholy: return "😔"
        case .grief: return "😭"
        case .disappointment: return "😞"
        case .loneliness: return "😢"
        case .despair: return "😰"
        case .sorrow: return "😿"
            
        case .frustration: return "😤"
        case .irritation: return "😒"
        case .rage: return "🤬"
        case .resentment: return "😠"
        case .indignation: return "😡"
        case .hostility: return "👿"
            
        case .anxiety: return "😟"
        case .worry: return "😧"
        case .nervousness: return "😬"
        case .panic: return "😱"
        case .dread: return "😨"
        case .apprehension: return "😰"
            
        case .amazement: return "😯"
        case .astonishment: return "😲"
        case .bewilderment: return "😵"
        case .curiosity: return "🤔"
        case .confusion: return "😕"
        case .wonder: return "😮"
            
        case .contempt: return "😏"
        case .aversion: return "🤢"
        case .repulsion: return "🤮"
        case .revulsion: return "😖"
        case .loathing: return "🤭"
        case .distaste: return "😒"
            
        case .calm: return "😌"
        case .balanced: return "😐"
        case .stable: return "🙂"
        case .peaceful: return "😇"
        case .composed: return "😊"
        case .indifferent: return "😑"
        }
    }
}

/// Emotion intensity levels for granular analysis
enum EmotionIntensity: String, CaseIterable, Identifiable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .orange
        case .medium: return .yellow
        case .high: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "1.circle.fill"
        case .medium: return "2.circle.fill"
        case .high: return "3.circle.fill"
        }
    }
    
    var threshold: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 1.0
        }
    }
    
    var multiplier: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 1.0
        }
    }
    
    static func from(score: Double) -> EmotionIntensity {
        if score <= 0.3 {
            return .low
        } else if score <= 0.6 {
            return .medium
        } else {
            return .high
        }
    }
}

// MARK: - Emotion Trend Analysis
struct EmotionTrend: Identifiable {
    let id = UUID()
    let emotion: EmotionCategory
    let trend: TrendDirection
    let changePercentage: Double
    let timeframe: TrendTimeframe
}

enum TrendDirection: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
    
    var displayName: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        }
    }
    
    var icon: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .increasing: return .green
        case .decreasing: return .red
        case .stable: return .blue
        }
    }
}

enum TrendTimeframe: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "Today"
        case .weekly: return "This Week"
        case .monthly: return "This Month"
        }
    }
}

