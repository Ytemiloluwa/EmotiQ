//
//  FeatureAccessManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import Combine

class FeatureAccessManager: ObservableObject {
    static let shared = FeatureAccessManager()
    
    private let subscriptionService: SubscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    @Published var currentSubscription: SubscriptionStatus = .free
    @Published var featureAccess: [FeatureType: Bool] = [:]
    
    init(subscriptionService: SubscriptionServiceProtocol = SubscriptionService.shared) {
        self.subscriptionService = subscriptionService
        setupSubscriptions()
        updateFeatureAccess()
    }
    
    private func setupSubscriptions() {
        subscriptionService.currentSubscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.currentSubscription = status
                self?.updateFeatureAccess()
            }
            .store(in: &cancellables)
    }
    
    private func updateFeatureAccess() {
        for feature in FeatureType.allCases {
            featureAccess[feature] = subscriptionService.checkFeatureAccess(feature)
        }
    }
    
    func canAccess(_ feature: FeatureType) -> Bool {
        return featureAccess[feature] ?? false
    }
    
    // MARK: - Feature Access Checks
    
    func canAccessVoiceCheckIns() -> Bool {
        return canAccess(.voiceCheckIns)
    }
    
    func canAccessVoiceCloning() -> Bool {
        return canAccess(.voiceCloning)
    }
    
    func canAccessVoiceAffirmations() -> Bool {
        return canAccess(.voiceAffirmations)
    }
    
    func canAccessGoalSetting() -> Bool {
        return canAccess(.goalSetting)
    }
    
    func canAccessPersonalizedCoaching() -> Bool {
        return canAccess(.personalizedCoaching)
    }
    
    func canAccessAdvancedAnalytics() -> Bool {
        return canAccess(.advancedAnalytics)
    }
    
    func canAccessDataExport() -> Bool {
        return canAccess(.dataExport)
    }
    
    func canAccessPrioritySupport() -> Bool {
        return canAccess(.prioritySupport)
    }
    
    func canAccessEarlyAccess() -> Bool {
        return canAccess(.earlyAccess)
    }
    
    // MARK: - Subscription Tier Checks
    
    var isFreeUser: Bool {
        return currentSubscription == .free
    }
    
    var isPremiumUser: Bool {
        return currentSubscription == .premium
    }
    
    var isProUser: Bool {
        return currentSubscription == .pro
    }
    
    var hasActiveSubscription: Bool {
        return !isFreeUser
    }
}
