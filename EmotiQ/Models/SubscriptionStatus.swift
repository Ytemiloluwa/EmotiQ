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
                "6 weekly voice check-ins",
                "Basic emotion tracking",
                "Simple insights"
            ]
        case .premium:
            return [
                "Unlimited voice check-ins",
                "Voice cloning",
                "Advanced emotion analysis",
                "Personalized coaching",
                "Goal setting & tracking",
                "Advanced analytics"
            ]
        case .pro:
            return [
                "Everything in Premium",
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
    
    var weeklyLimit: Int {
        switch self {
        case .free:
            return Config.Subscription.freeWeeklyLimit
        case .premium, .pro:
            return -1 // Unlimited
        }
    }
    
    var hasUnlimitedAccess: Bool {
        return self != .free
    }
    
    var hasVoiceCloning: Bool {
        return self == .premium || self == .pro
    }
    
    var hasAdvancedAnalytics: Bool {
        return self != .free
    }
    
    var hasDataExport: Bool {
        return self == .pro
    }
    
    var hasGoalSetting: Bool {
        return self != .free
    }
    
    var hasPersonalizedCoaching: Bool {
        return self != .free
    }
    
    var hasPrioritySupport: Bool {
        return self == .pro
    }
    
    var hasEarlyAccess: Bool {
        return self == .pro
    }
}

