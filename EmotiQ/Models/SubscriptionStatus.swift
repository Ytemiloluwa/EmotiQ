//
//  SubscriptionStatus.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation

enum SubscriptionStatus: String, CaseIterable {
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
            return "Free"
        case .premium:
            return Config.Subscription.premiumPrice
        case .pro:
            return Config.Subscription.proPrice
        }
    }
    
    var productIdentifier: String {
        switch self {
        case .free:
            return ""
        case .premium:
            return Config.Subscription.premiumMonthlyProductID
        case .pro:
            return Config.Subscription.proMonthlyProductID
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "3 daily voice check-ins",
                "Basic emotion tracking",
                "Simple insights"
            ]
        case .premium:
            return [
                "Unlimited voice check-ins",
                "Advanced emotion analysis",
                "Personalized coaching",
                "ElevenLabs voice affirmations",
                "Detailed emotional insights"
            ]
        case .pro:
            return [
                "Everything in Premium",
                "Custom voice cloning",
                "Advanced analytics & trends",
                "Data export capabilities",
                "Priority customer support",
                "Early access to new features"
            ]
        }
    }
    
    var dailyLimit: Int {
        switch self {
        case .free:
            return Config.Subscription.freeDailyLimit
        case .premium, .pro:
            return -1 // Unlimited
        }
    }
    
    var hasUnlimitedAccess: Bool {
        return self != .free
    }
    
    var hasVoiceCloning: Bool {
        return self == .pro
    }
    
    var hasAdvancedAnalytics: Bool {
        return self != .free
    }
    
    var hasDataExport: Bool {
        return self == .pro
    }
    
    var hasPrioritySupport: Bool {
        return self == .pro
    }
}

