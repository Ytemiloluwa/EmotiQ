//
//  SubscriptionStatus.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation

enum SubscriptionStatus: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Premium"
        case .pro:
            return "Pro"
        }
    }
    
    var monthlyPrice: String {
        switch self {
        case .free:
            return "$0"
        case .premium:
            return "$9.99"
        case .pro:
            return "$19.99"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "3 daily voice check-ins",
                "Basic emotion tracking",
                "Simple insights",
                "Limited coaching tips"
            ]
        case .premium:
            return [
                "Unlimited voice check-ins",
                "Advanced emotion analysis",
                "Personalized coaching",
                "ElevenLabs voice affirmations",
                "Weekly insights reports",
                "Mood pattern tracking"
            ]
        case .pro:
            return [
                "Everything in Premium",
                "AI coaching conversations",
                "Predictive emotional insights",
                "Custom voice cloning",
                "Advanced analytics",
                "Priority support",
                "Export data capabilities"
            ]
        }
    }
    
    var dailyCheckInLimit: Int? {
        switch self {
        case .free:
            return 3
        case .premium, .pro:
            return nil // Unlimited
        }
    }
    
    var hasAdvancedAnalysis: Bool {
        switch self {
        case .free:
            return false
        case .premium, .pro:
            return true
        }
    }
    
    var hasVoiceCloning: Bool {
        switch self {
        case .free, .premium:
            return false
        case .pro:
            return true
        }
    }
    
    var hasAICoaching: Bool {
        switch self {
        case .free:
            return false
        case .premium, .pro:
            return true
        }
    }
    
    var productIdentifier: String {
        switch self {
        case .free:
            return ""
        case .premium:
            return "emotiq_premium_monthly"
        case .pro:
            return "emotiq_pro_monthly"
        }
    }
}

