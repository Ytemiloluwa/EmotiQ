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
enum EmotionIntensity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 1.0
        }
    }
}

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
    let confidence: Double
    let emotionScores: [EmotionCategory: Double]
    let audioQuality: AudioQuality
    let sessionDuration: TimeInterval
    
    init(timestamp: Date = Date(), primaryEmotion: EmotionCategory, confidence: Double, emotionScores: [EmotionCategory: Double], audioQuality: AudioQuality, sessionDuration: TimeInterval) {
        self.id = UUID()
        self.timestamp = timestamp
        self.primaryEmotion = primaryEmotion
        self.confidence = confidence
        self.emotionScores = emotionScores
        self.audioQuality = audioQuality
        self.sessionDuration = sessionDuration
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
}

// MARK: - Audio Quality Assessment
enum AudioQuality: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "xmark.circle"
        }
    }
    
    var reliabilityScore: Double {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.8
        case .fair: return 0.6
        case .poor: return 0.3
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


