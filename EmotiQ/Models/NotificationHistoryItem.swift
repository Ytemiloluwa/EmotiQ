//
//  NotificationHistoryItem.swift
//  EmotiQ
//
//  Created by Temiloluwa on 09-09-2025.
//

import Foundation
import SwiftUI

struct NotificationHistoryItem: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let receivedAt: Date
    let type: NotificationHistoryType
    let isRead: Bool
    let emotionRawValue: String?
    let interventionRawValue: String?
    let customData: [String: String]?
    let priority: NotificationPriority
    
    var emotion: EmotionType? {
        guard let rawValue = emotionRawValue else { return nil }
        return EmotionType(rawValue: rawValue)
    }
    
    var intervention: OneSignaInterventionType? {
        guard let rawValue = interventionRawValue else { return nil }
        return OneSignaInterventionType(rawValue: rawValue)
    }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        receivedAt: Date = Date(),
        type: NotificationHistoryType,
        isRead: Bool = false,
        emotion: EmotionType? = nil,
        intervention: OneSignaInterventionType? = nil,
        customData: [String: String]? = nil,
        priority: NotificationPriority = .medium
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.receivedAt = receivedAt
        self.type = type
        self.isRead = isRead
        self.emotionRawValue = emotion?.rawValue
        self.interventionRawValue = intervention?.rawValue
        self.customData = customData
        self.priority = priority
    }
    
    func markAsRead() -> NotificationHistoryItem {
        return NotificationHistoryItem(
            id: self.id,
            title: self.title,
            body: self.body,
            receivedAt: self.receivedAt,
            type: self.type,
            isRead: true,
            emotion: self.emotion,
            intervention: self.intervention,
            customData: self.customData,
            priority: self.priority
        )
    }
}
enum NotificationHistoryType: String, CaseIterable, Codable {
    case emotionTriggered = "emotion_triggered"
    case predictiveIntervention = "predictive_intervention"
    case dailyCheckIn = "daily_checkin"
    case achievement = "achievement"
    case reminder = "reminder"
    case welcome = "welcome"
    case campaign = "campaign"
    
    var displayName: String {
        switch self {
        case .emotionTriggered:
            return "Emotion Support"
        case .predictiveIntervention:
            return "Predictive Care"
        case .dailyCheckIn:
            return "Daily Check-in"
        case .achievement:
            return "Achievement"
        case .reminder:
            return "Reminder"
        case .welcome:
            return "Welcome"
        case .campaign:
            return "Campaign"
        }
    }
    
    var icon: String {
        switch self {
        case .emotionTriggered:
            return "heart.fill"
        case .predictiveIntervention:
            return "brain.head.profile"
        case .dailyCheckIn:
            return "calendar"
        case .achievement:
            return "trophy.fill"
        case .reminder:
            return "bell.fill"
        case .welcome:
            return "hand.wave.fill"
        case .campaign:
            return "megaphone.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .emotionTriggered:
            return .red
        case .predictiveIntervention:
            return .purple
        case .dailyCheckIn:
            return .blue
        case .achievement:
            return .yellow
        case .reminder:
            return .orange
        case .welcome:
            return .green
        case .campaign:
            return .pink
        }
    }
}
