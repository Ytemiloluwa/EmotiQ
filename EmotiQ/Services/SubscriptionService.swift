//
//  SubscriptionService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//


import Foundation
import Combine
import SwiftUI
import RevenueCat

// MARK: - Feature Types
enum FeatureType: String, CaseIterable {
    case voiceCheckIns = "voice_check_ins"
    case voiceCloning = "voice_cloning"
    case voiceAffirmations = "voice_affirmations"
    case goalSetting = "goal_setting"
    case personalizedCoaching = "personalized_coaching"
    case advancedAnalytics = "advanced_analytics"
    case dataExport = "data_export"
    case prioritySupport = "priority_support"
    case earlyAccess = "early_access"
    
    var displayName: String {
        switch self {
        case .voiceCheckIns:
            return "Voice Check-ins"
        case .voiceCloning:
            return "Voice Cloning"
        case .voiceAffirmations:
            return "Voice Affirmations"
        case .goalSetting:
            return "Goal Setting"
        case .personalizedCoaching:
            return "Personalized Coaching"
        case .advancedAnalytics:
            return "Advanced Analytics"
        case .dataExport:
            return "Data Export"
        case .prioritySupport:
            return "Priority Support"
        case .earlyAccess:
            return "Early Access"
        }
    }
    
    var description: String {
        switch self {
        case .voiceCheckIns:
            return "Analyze your emotions through voice recordings"
        case .voiceCloning:
            return "Create a custom voice profile for personalized content"
        case .voiceAffirmations:
            return "Receive personalized voice affirmations"
        case .goalSetting:
            return "Set and track emotional wellness goals"
        case .personalizedCoaching:
            return "Get personalized emotional wellness coaching"
        case .advancedAnalytics:
            return "Access detailed emotional patterns and trends"
        case .dataExport:
            return "Export your emotional data for analysis"
        case .prioritySupport:
            return "Get priority customer support"
        case .earlyAccess:
            return "Access new features before general release"
        }
    }
}

protocol SubscriptionServiceProtocol {
    var currentSubscription: AnyPublisher<SubscriptionStatus, Never> { get }
    var dailyUsageRemaining: AnyPublisher<Int, Never> { get }
    var weeklyUsageRemaining: AnyPublisher<Int, Never> { get }
    func checkSubscriptionStatus() -> AnyPublisher<SubscriptionStatus, Error>
    func purchaseSubscription(_ tier: SubscriptionStatus) -> AnyPublisher<Bool, Error>
    func restorePurchases() -> AnyPublisher<SubscriptionStatus, Error>
    func canPerformVoiceAnalysis() -> Bool
    func incrementDailyUsage()
    func incrementWeeklyUsage()
    func getRemainingDailyUsage() -> Int
    func getRemainingWeeklyUsage() -> Int
    func refreshDailyUsage()
    func refreshWeeklyUsage()
    func checkFeatureAccess(_ feature: FeatureType) -> Bool
    func hasVoiceCloning() -> Bool
    func hasGoalSetting() -> Bool
    func hasPersonalizedCoaching() -> Bool
    func hasAdvancedAnalytics() -> Bool
    func hasDataExport() -> Bool
    func hasPrioritySupport() -> Bool
    func hasEarlyAccess() -> Bool
}

class SubscriptionService: SubscriptionServiceProtocol, ObservableObject {
    func hasDataExport() -> Bool {
        return subscriptionStatus == .pro
    }
    
    static let shared = SubscriptionService()
    
    @Published private var subscriptionStatus: SubscriptionStatus = .free
    @Published var dailyUsage: Int = 0
    @Published var weeklyUsage: Int = 0
    private let revenueCatService: RevenueCatServiceProtocol
    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    var currentSubscription: AnyPublisher<SubscriptionStatus, Never> {
        $subscriptionStatus.eraseToAnyPublisher()
    }
    
    var dailyUsageRemaining: AnyPublisher<Int, Never> {
        $dailyUsage
            .map { usage in
                max(0, Config.Subscription.freeDailyLimit - usage)
            }
            .eraseToAnyPublisher()
    }
    
    var weeklyUsageRemaining: AnyPublisher<Int, Never> {
        $weeklyUsage
            .map { usage in
                max(0, Config.Subscription.freeWeeklyLimit - usage)
            }
            .eraseToAnyPublisher()
    }
    
    var hasActiveSubscription: Bool {
        subscriptionStatus != .free
    }
    
    var currentSubscriptionTier: SubscriptionStatus? {
        hasActiveSubscription ? subscriptionStatus : nil
    }
    
    var subscriptionExpiryDate: Date? {
        // This would typically come from RevenueCat
        // For now, return a placeholder date if subscribed
        hasActiveSubscription ? Calendar.current.date(byAdding: .month, value: 1, to: Date()) : nil
    }
    
    init(revenueCatService: RevenueCatServiceProtocol = RevenueCatService.shared,
         persistenceController: PersistenceController = .shared) {
        self.revenueCatService = revenueCatService
        self.persistenceController = persistenceController
        
        // Note: RevenueCat is configured in AppDelegate, no need to configure here
        loadInitialSubscriptionStatus()
        loadDailyUsage()
        loadWeeklyUsage()
    }
    

    
    private func loadInitialSubscriptionStatus() {
        // Load from Core Data first
        if let user = persistenceController.getCurrentUser() {
            let status = SubscriptionStatus(rawValue: user.subscriptionStatus ?? "free") ?? .free
            subscriptionStatus = status
            
        }
        
        // Then check with RevenueCat for latest status
        checkSubscriptionStatus()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {

                    }
                },
                receiveValue: { [weak self] status in
                    self?.subscriptionStatus = status
                    self?.updateUserSubscriptionStatus(status)
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadDailyUsage() {
 
        
        if let user = persistenceController.getCurrentUser() {
         
            
            // Check if we need to reset daily usage (new day)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
           
            
            if let lastCheckIn = user.lastCheckInDate {
                let lastCheckInDay = calendar.startOfDay(for: lastCheckIn)
           
                
                if lastCheckInDay < today {
                    // Reset daily usage for new day
                   
                    user.dailyCheckInsUsed = 0
                    persistenceController.save()
                    

                } else {
                    
                }
            } else {
             
            }
            
            DispatchQueue.main.async {
                self.dailyUsage = Int(user.dailyCheckInsUsed)

            }
        } else {
           
        }
    }
    
    private func loadWeeklyUsage() {
   
        if let user = persistenceController.getCurrentUser() {

            
            // Check if we need to reset weekly usage (7 days from week start)
            if persistenceController.shouldResetWeeklyUsage(for: user) {
                persistenceController.resetWeeklyUsage(for: user)
            }

            DispatchQueue.main.async {
                self.weeklyUsage = Int(user.weeklyCheckInsUsed)

            }
        } else {
            
        }
    }
    
    private func updateUserSubscriptionStatus(_ status: SubscriptionStatus) {
        let user = persistenceController.createUserIfNeeded()
        user.subscriptionStatus = status.rawValue
        persistenceController.save()
        
    }
    
    func checkSubscriptionStatus() -> AnyPublisher<SubscriptionStatus, Error> {
        return revenueCatService.getCustomerInfo()
            .map { customerInfo in
                // Check for Pro subscription first (higher tier)
                if customerInfo.activeSubscriptions.contains(Config.Subscription.proMonthlyProductID) {
                    return SubscriptionStatus.pro
                } else if customerInfo.activeSubscriptions.contains(Config.Subscription.premiumMonthlyProductID) {
                    return SubscriptionStatus.premium
                } else {
                    return SubscriptionStatus.free
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Safe Subscription Refresh
    func refreshSubscriptionStatus() async {
        // Safe refresh of subscription status that doesn't interfere with view updates
        // This is called after successful purchases to unlock features
        do {
            let customerInfo = try await revenueCatService.getCustomerInfoAsync()
            let newStatus: SubscriptionStatus
            
            if customerInfo.activeSubscriptions.contains(Config.Subscription.proMonthlyProductID) {
                newStatus = .pro
            } else if customerInfo.activeSubscriptions.contains(Config.Subscription.premiumMonthlyProductID) {
                newStatus = .premium
            } else {
                newStatus = .free
            }
            
            // Use a slight delay to avoid "Publishing changes from within view updates" error
            //try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Update the published property to trigger UI updates
            await MainActor.run {
                self.subscriptionStatus = newStatus
                self.updateUserSubscriptionStatus(newStatus)
                
            }
        } catch {

        }
    }
    
    func purchaseSubscription(_ tier: SubscriptionStatus) -> AnyPublisher<Bool, Error> {
        guard tier != .free else {
            return Just(false)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return revenueCatService.purchaseProduct(tier.productIdentifier)
            .handleEvents(receiveOutput: { [weak self] success in
                if success {
                    self?.subscriptionStatus = tier
                    self?.updateUserSubscriptionStatus(tier)
                    
                } else {

                }
            })
            .eraseToAnyPublisher()
    }
    
    func restorePurchases() -> AnyPublisher<SubscriptionStatus, Error> {
        
        return revenueCatService.restorePurchases()
            .map { customerInfo in
                if customerInfo.activeSubscriptions.contains(Config.Subscription.proMonthlyProductID) {
                    return SubscriptionStatus.pro
                } else if customerInfo.activeSubscriptions.contains(Config.Subscription.premiumMonthlyProductID) {
                    return SubscriptionStatus.premium
                } else {
                    return SubscriptionStatus.free
                }
            }
            .handleEvents(receiveOutput: { [weak self] status in
                self?.subscriptionStatus = status
                self?.updateUserSubscriptionStatus(status)
                
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Daily Usage Management
    
    func canPerformVoiceAnalysis() -> Bool {
        // Premium and Pro users have unlimited access
        if subscriptionStatus != .free {
            return true
        }
        
        // Check weekly limit for free users (new implementation)
        let user = persistenceController.createUserIfNeeded()
        return persistenceController.canPerformWeeklyCheckIn(for: user)
    }
    
    func incrementDailyUsage() {
        // Only increment for free users
        guard subscriptionStatus == .free else { return }
        
        let user = persistenceController.createUserIfNeeded()
        persistenceController.incrementDailyUsage(for: user)
        
        // Update local state
        dailyUsage = Int(user.dailyCheckInsUsed)
        
        // Also increment weekly usage for free users
        if subscriptionStatus == .free {
            persistenceController.incrementWeeklyUsage(for: user)
            weeklyUsage = Int(user.weeklyCheckInsUsed)
        }
        
    }
    
    func incrementWeeklyUsage() {
        // Only increment for free users
        guard subscriptionStatus == .free else { return }
        
        let user = persistenceController.createUserIfNeeded()
        persistenceController.incrementWeeklyUsage(for: user)
        
        // Update local state
        weeklyUsage = Int(user.weeklyCheckInsUsed)
        
    }
    
    func getRemainingDailyUsage() -> Int {
        // Unlimited for premium users
        if subscriptionStatus != .free {
            return -1 // Indicates unlimited
        }
        
        return max(0, Config.Subscription.freeDailyLimit - dailyUsage)
    }
    
    func getRemainingWeeklyUsage() -> Int {
        // Unlimited for premium users
        if subscriptionStatus != .free {
            return -1 // Indicates unlimited
        }
        
        return max(0, Config.Subscription.freeWeeklyLimit - weeklyUsage)
    }
    
    /// Refreshes daily usage and checks for daily reset
    func refreshDailyUsage() {
        let previousUsage = dailyUsage
  
        loadDailyUsage()

        
        // If usage was reset (went from >0 to 0), notify other components
        if previousUsage > 0 && dailyUsage == 0 {

            NotificationCenter.default.post(name: .dailyUsageReset, object: nil)
            
        }
        
    }
    
    /// Refreshes weekly usage and checks for weekly reset
    func refreshWeeklyUsage() {
        let previousUsage = weeklyUsage
        loadWeeklyUsage()
        
        // If usage was reset (went from >0 to 0), notify other components
        if previousUsage > 0 && weeklyUsage == 0 {

            NotificationCenter.default.post(name: .weeklyUsageReset, object: nil)

        }
        
    }
    
    // MARK: - Feature Access Control
    
    func hasUnlimitedAccess() -> Bool {
        return subscriptionStatus != .free
    }
    
    func hasVoiceCloning() -> Bool {
        // Both Premium and Pro users get voice cloning
        return subscriptionStatus == .premium || subscriptionStatus == .pro
    }
    
    func hasAdvancedAnalytics() -> Bool {
        return subscriptionStatus != .free
    }
    
    func hasPersonalizedCoaching() -> Bool {
        return subscriptionStatus != .free
    }
    
    func canExportData() -> Bool {
        return subscriptionStatus == .pro
    }
    
    func hasVoiceAffirmations() -> Bool {
        // Voice affirmations have their own subscription system
        // This will be checked separately in the AffirmationEngine
        return true // For now, allow all users to access
    }
    
    func hasGoalSetting() -> Bool {
        return subscriptionStatus != .free
    }
    
    func hasPrioritySupport() -> Bool {
        return subscriptionStatus == .pro
    }
    
    func hasEarlyAccess() -> Bool {
        return subscriptionStatus == .pro
    }
    
    // MARK: - Comprehensive Feature Check
    func checkFeatureAccess(_ feature: FeatureType) -> Bool {
        switch feature {
        case .voiceCheckIns:
            return hasUnlimitedAccess() || getRemainingWeeklyUsage() > 0
        case .voiceCloning:
            return hasVoiceCloning()
        case .voiceAffirmations:
            return hasVoiceAffirmations()
        case .goalSetting:
            return hasGoalSetting()
        case .personalizedCoaching:
            return hasPersonalizedCoaching()
        case .advancedAnalytics:
            return hasAdvancedAnalytics()
        case .dataExport:
            return canExportData()
        case .prioritySupport:
            return hasPrioritySupport()
        case .earlyAccess:
            return hasEarlyAccess()
        }
    }

    
    // MARK: - Pricing Information
    
    func getSubscriptionPricing() -> [(tier: SubscriptionStatus, price: String, features: [String])] {
        return [
            (tier: .free, price: "Free", features: [
                "6 weekly voice check-ins",
                "Basic emotion tracking",
                "Simple insights"
            ]),
            (tier: .premium, price: Config.Subscription.premiumPrice + "/month", features: [
                "Unlimited voice check-ins",
                "Voice cloning",
                "Advanced emotion analysis",
                "Personalized coaching",
                "Goal setting & tracking",
                "Advanced analytics"
            ]),
            (tier: .pro, price: Config.Subscription.proPrice + "/month", features: [
                "Everything in Premium",
                "Data export capabilities",
                "Priority customer support",
                "Early access to new features"
            ])
        ]
    }
}



