//
//  CoachingModels.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import SwiftUI

// MARK: - Coaching Recommendation
struct CoachingRecommendation: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    let icon: String
    let color: Color
    let estimatedDuration: String?
    let priority: RecommendationPriority
    let createdAt: Date
    
    init(title: String, description: String, category: String, icon: String, color: Color, estimatedDuration: String? = nil, priority: RecommendationPriority = .medium) {
        self.title = title
        self.description = description
        self.category = category
        self.icon = icon
        self.color = color
        self.estimatedDuration = estimatedDuration
        self.priority = priority
        self.createdAt = Date()
    }
    
    // Custom coding for Color
    enum CodingKeys: String, CodingKey {
        case title, description, category, icon, estimatedDuration, priority, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        icon = try container.decode(String.self, forKey: .icon)
        estimatedDuration = try container.decodeIfPresent(String.self, forKey: .estimatedDuration)
        priority = try container.decode(RecommendationPriority.self, forKey: .priority)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        color = .purple // Default color for decoded items
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(icon, forKey: .icon)
        try container.encodeIfPresent(estimatedDuration, forKey: .estimatedDuration)
        try container.encode(priority, forKey: .priority)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

enum RecommendationPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - Quick Intervention
struct QuickIntervention: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let category: InterventionCategory
    let icon: String
    let color: Color
    let estimatedDuration: Int // in minutes
    let instructions: [String]
    let benefits: [String]
    
    init(title: String, description: String, category: InterventionCategory, icon: String, color: Color, estimatedDuration: Int, instructions: [String] = [], benefits: [String] = []) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.icon = icon
        self.color = color
        self.estimatedDuration = estimatedDuration
        self.instructions = instructions
        self.benefits = benefits
    }
    
    var durationText: String {
        return "\(estimatedDuration) min"
    }
    
    // Custom coding for Color
    enum CodingKeys: String, CodingKey {
        case title, description, category, icon, estimatedDuration, instructions, benefits
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID() // Generate new ID for decoded instance
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(InterventionCategory.self, forKey: .category)
        icon = try container.decode(String.self, forKey: .icon)
        estimatedDuration = try container.decode(Int.self, forKey: .estimatedDuration)
        instructions = try container.decode([String].self, forKey: .instructions)
        benefits = try container.decode([String].self, forKey: .benefits)
        color = category.color // Use category color
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(icon, forKey: .icon)
        try container.encode(estimatedDuration, forKey: .estimatedDuration)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(benefits, forKey: .benefits)
    }
}

enum InterventionCategory: String, Codable, CaseIterable {
    case breathing = "breathing"
    case mindfulness = "mindfulness"
    case movement = "movement"
    case cognitive = "cognitive"
    case social = "social"
    case creativity = "creativity"
    case stressManagement = "stress_management"
    case energyBoost = "energy_boost"
    
    var displayName: String {
        switch self {
        case .breathing: return "Breathing"
        case .mindfulness: return "Mindfulness"
        case .movement: return "Movement"
        case .cognitive: return "Cognitive"
        case .social: return "Social"
        case .creativity: return "Creativity"
        case .stressManagement: return "Stress Management"
        case .energyBoost: return "Energy Boost"
        }
    }
    
    var color: Color {
        switch self {
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
    
    var icon: String {
        switch self {
        case .breathing: return "lungs.fill"
        case .mindfulness: return "leaf.fill"
        case .movement: return "figure.walk"
        case .cognitive: return "brain.head.profile"
        case .social: return "person.2.fill"
        case .creativity: return "paintbrush.fill"
        case .stressManagement: return "heart.circle"
        case .energyBoost: return "bolt.fill"
        }
    }
}

// MARK: - Emotional Goal
struct EmotionalGoal: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let category: GoalCategory
    let targetDate: Date?
    let createdAt: Date
    var progress: Double // 0.0 to 1.0
    var isCompleted: Bool
    var completedAt: Date?
    var milestones: [GoalMilestone]
    var isTemplate: Bool // Flag to identify goals created from templates
    
    init(id: UUID = UUID(), title: String, description: String, category: GoalCategory, targetDate: Date? = nil, createdAt: Date = Date(), progress: Double = 0.0, isCompleted: Bool = false, completedAt: Date? = nil, milestones: [GoalMilestone] = [], isTemplate: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.progress = progress
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.milestones = milestones
        self.isTemplate = isTemplate
    }
    
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    var daysRemaining: Int? {
        guard let targetDate = targetDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: targetDate).day
        return max(days ?? 0, 0)
    }
    
    var isOverdue: Bool {
        guard let targetDate = targetDate else { return false }
        return Date() > targetDate && !isCompleted
    }
}

enum GoalCategory: String, Codable, CaseIterable {
    case emotionalAwareness = "emotional_awareness"
    case stressManagement = "stress_management"
    case relationships = "relationships"
    case selfCompassion = "self_compassion"
    case mindfulness = "mindfulness"
    case communication = "communication"
    case resilience = "resilience"
    case happiness = "happiness"
    
    var displayName: String {
        switch self {
        case .emotionalAwareness: return "Emotional Awareness"
        case .stressManagement: return "Stress Management"
        case .relationships: return "Relationships"
        case .selfCompassion: return "Self-Compassion"
        case .mindfulness: return "Mindfulness"
        case .communication: return "Communication"
        case .resilience: return "Resilience"
        case .happiness: return "Happiness"
        }
    }
    
    var color: Color {
        switch self {
        case .emotionalAwareness: return .purple
        case .stressManagement: return .blue
        case .relationships: return .pink
        case .selfCompassion: return .green
        case .mindfulness: return .teal
        case .communication: return .orange
        case .resilience: return .red
        case .happiness: return .yellow
        }
    }
    
    var icon: String {
        switch self {
        case .emotionalAwareness: return "brain.head.profile"
        case .stressManagement: return "heart.circle"
        case .relationships: return "person.2.fill"
        case .selfCompassion: return "heart.fill"
        case .mindfulness: return "leaf.fill"
        case .communication: return "bubble.left.and.bubble.right"
        case .resilience: return "shield.fill"
        case .happiness: return "sun.max.fill"
        }
    }
}

// MARK: - Goal Milestone
struct GoalMilestone: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let targetProgress: Double // 0.0 to 1.0
    var isCompleted: Bool
    var completedAt: Date?
    
    init(title: String, description: String, targetProgress: Double, isCompleted: Bool = false, completedAt: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.targetProgress = targetProgress
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
    
    init(id: UUID, title: String, description: String, targetProgress: Double, isCompleted: Bool = false, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.targetProgress = targetProgress
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

// MARK: - Completed Intervention
struct CompletedIntervention: Identifiable, Codable {
    let id: UUID
    let interventionId: UUID
    let title: String
    let category: InterventionCategory
    let completedAt: Date
    let duration: Int // actual duration in minutes
    var effectiveness: Int? // 1-5 rating
    var notes: String?
    
    init(id: UUID = UUID(), interventionId: UUID, title: String, category: InterventionCategory, completedAt: Date = Date(), duration: Int, effectiveness: Int? = nil, notes: String? = nil) {
        self.id = id
        self.interventionId = interventionId
        self.title = title
        self.category = category
        self.completedAt = completedAt
        self.duration = duration
        self.effectiveness = effectiveness
        self.notes = notes
    }
}

// MARK: - Coaching Program
struct CoachingProgram: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let category: GoalCategory
    let icon: String
    let color: Color
    let totalSessions: Int
    var completedSessions: Int
    let sessions: [CoachingSession]
    let estimatedWeeks: Int
    
    init(title: String, description: String, category: GoalCategory, icon: String, color: Color, totalSessions: Int, completedSessions: Int = 0, sessions: [CoachingSession] = [], estimatedWeeks: Int) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.icon = icon
        self.color = color
        self.totalSessions = totalSessions
        self.completedSessions = completedSessions
        self.sessions = sessions
        self.estimatedWeeks = estimatedWeeks
    }
    
    var progressPercentage: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(completedSessions) / Double(totalSessions)
    }
    
    var isCompleted: Bool {
        return completedSessions >= totalSessions
    }
    
    // Custom coding for Color
    enum CodingKeys: String, CodingKey {
        case title, description, category, icon, totalSessions, completedSessions, sessions, estimatedWeeks
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID() // Generate new ID for decoded instance
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(GoalCategory.self, forKey: .category)
        icon = try container.decode(String.self, forKey: .icon)
        totalSessions = try container.decode(Int.self, forKey: .totalSessions)
        completedSessions = try container.decode(Int.self, forKey: .completedSessions)
        sessions = try container.decode([CoachingSession].self, forKey: .sessions)
        estimatedWeeks = try container.decode(Int.self, forKey: .estimatedWeeks)
        color = category.color // Use category color
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(icon, forKey: .icon)
        try container.encode(totalSessions, forKey: .totalSessions)
        try container.encode(completedSessions, forKey: .completedSessions)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(estimatedWeeks, forKey: .estimatedWeeks)
    }
}

// MARK: - Coaching Session
struct CoachingSession: Identifiable, Codable {
    let id: UUID
    let sessionNumber: Int
    let title: String
    let description: String
    let objectives: [String]
    let activities: [SessionActivity]
    let estimatedDuration: Int // in minutes
    var isCompleted: Bool
    var completedAt: Date?
    var userRating: Int? // 1-5 stars
    var userNotes: String?
    
    init(sessionNumber: Int, title: String, description: String, objectives: [String], activities: [SessionActivity], estimatedDuration: Int, isCompleted: Bool = false, completedAt: Date? = nil, userRating: Int? = nil, userNotes: String? = nil) {
        self.id = UUID()
        self.sessionNumber = sessionNumber
        self.title = title
        self.description = description
        self.objectives = objectives
        self.activities = activities
        self.estimatedDuration = estimatedDuration
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.userRating = userRating
        self.userNotes = userNotes
    }
}

// MARK: - Session Activity
struct SessionActivity: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let type: ActivityType
    let estimatedDuration: Int // in minutes
    let instructions: [String]
    var isCompleted: Bool
    
    init(title: String, description: String, type: ActivityType, estimatedDuration: Int, instructions: [String], isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.type = type
        self.estimatedDuration = estimatedDuration
        self.instructions = instructions
        self.isCompleted = isCompleted
    }
}

enum ActivityType: String, Codable, CaseIterable {
    case reflection = "reflection"
    case exercise = "exercise"
    case meditation = "meditation"
    case journaling = "journaling"
    case breathing = "breathing"
    case visualization = "visualization"
    case practice = "practice"
    
    var displayName: String {
        switch self {
        case .reflection: return "Reflection"
        case .exercise: return "Exercise"
        case .meditation: return "Meditation"
        case .journaling: return "Journaling"
        case .breathing: return "Breathing"
        case .visualization: return "Visualization"
        case .practice: return "Practice"
        }
    }
    
    var icon: String {
        switch self {
        case .reflection: return "lightbulb"
        case .exercise: return "figure.walk"
        case .meditation: return "leaf.fill"
        case .journaling: return "book.fill"
        case .breathing: return "lungs.fill"
        case .visualization: return "eye.fill"
        case .practice: return "repeat"
        }
    }
}
