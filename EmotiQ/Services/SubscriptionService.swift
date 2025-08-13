//
//  SubscriptionService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation
import Combine
import RevenueCat

protocol SubscriptionServiceProtocol {
    var currentSubscription: AnyPublisher<SubscriptionStatus, Never> { get }
    var dailyUsageRemaining: AnyPublisher<Int, Never> { get }
    func checkSubscriptionStatus() -> AnyPublisher<SubscriptionStatus, Error>
    func purchaseSubscription(_ tier: SubscriptionStatus) -> AnyPublisher<Bool, Error>
    func restorePurchases() -> AnyPublisher<SubscriptionStatus, Error>
    func canPerformVoiceAnalysis() -> Bool
    func incrementDailyUsage()
    func getRemainingDailyUsage() -> Int
}

class SubscriptionService: SubscriptionServiceProtocol, ObservableObject {
    static let shared = SubscriptionService()
    
    @Published private var subscriptionStatus: SubscriptionStatus = .free
    @Published var dailyUsage: Int = 0
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
    
    init(revenueCatService: RevenueCatServiceProtocol = RevenueCatService(),
         persistenceController: PersistenceController = .shared) {
        self.revenueCatService = revenueCatService
        self.persistenceController = persistenceController
        
        self.revenueCatService.configure()
        loadInitialSubscriptionStatus()
        loadDailyUsage()
    }

    private func loadInitialSubscriptionStatus() {
        // Load from Core Data first
        if let user = persistenceController.getCurrentUser() {
            let status = SubscriptionStatus(rawValue: user.subscriptionStatus ?? "free") ?? .free
            subscriptionStatus = status
            
            if Config.isDebugMode {
                print("📱 Loaded subscription status from Core Data: \(status.displayName)")
            }
        }
        
        // Then check with RevenueCat for latest status
        checkSubscriptionStatus()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        if Config.isDebugMode {
                            print("❌ Failed to load subscription status: \(error)")
                        }
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
            dailyUsage = Int(user.dailyCheckInsUsed)
            
            if Config.isDebugMode {
                print("📊 Loaded daily usage: \(dailyUsage)/\(Config.Subscription.freeDailyLimit)")
            }
        }
    }
    
    private func updateUserSubscriptionStatus(_ status: SubscriptionStatus) {
        let user = persistenceController.createUserIfNeeded()
        user.subscriptionStatus = status.rawValue
        persistenceController.save()
        
        if Config.isDebugMode {
            print("💾 Updated user subscription status to: \(status.displayName)")
        }
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
    
    func purchaseSubscription(_ tier: SubscriptionStatus) -> AnyPublisher<Bool, Error> {
        guard tier != .free else {
            return Just(false)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        if Config.isDebugMode {
            print("🛒 Attempting to purchase: \(tier.displayName) (\(tier.monthlyPrice))")
        }
        
        return revenueCatService.purchaseProduct(tier.productIdentifier)
            .handleEvents(receiveOutput: { [weak self] success in
                if success {
                    self?.subscriptionStatus = tier
                    self?.updateUserSubscriptionStatus(tier)
                    
                    if Config.isDebugMode {
                        print("✅ Purchase successful: \(tier.displayName)")
                    }
                } else {
                    if Config.isDebugMode {
                        print("❌ Purchase failed for: \(tier.displayName)")
                    }
                }
            })
            .eraseToAnyPublisher()
    }
    
    func restorePurchases() -> AnyPublisher<SubscriptionStatus, Error> {
        if Config.isDebugMode {
            print("🔄 Restoring purchases...")
        }
        
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
                
                if Config.isDebugMode {
                    print("🔄 Restored subscription: \(status.displayName)")
                }
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Daily Usage Management
    
    func canPerformVoiceAnalysis() -> Bool {
        // Premium and Pro users have unlimited access
        if subscriptionStatus != .free {
            return true
        }
        
        // Check daily limit for free users
        let user = persistenceController.createUserIfNeeded()
        return persistenceController.canPerformDailyCheckIn(for: user)
    }
    
    func incrementDailyUsage() {
        // Only increment for free users
        guard subscriptionStatus == .free else { return }
        
        let user = persistenceController.createUserIfNeeded()
        persistenceController.incrementDailyUsage(for: user)
        
        // Update local state
        dailyUsage = Int(user.dailyCheckInsUsed)
        
        if Config.isDebugMode {
            print("📈 Daily usage incremented: \(dailyUsage)/\(Config.Subscription.freeDailyLimit)")
        }
    }
    
    func getRemainingDailyUsage() -> Int {
        // Unlimited for premium users
        if subscriptionStatus != .free {
            return -1 // Indicates unlimited
        }
        
        return max(0, Config.Subscription.freeDailyLimit - dailyUsage)
    }
    
    // MARK: - Subscription Benefits
    
    func hasUnlimitedAccess() -> Bool {
        return subscriptionStatus != .free
    }
    
    func hasVoiceCloning() -> Bool {
        return subscriptionStatus == .pro
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
    
    // MARK: - Pricing Information
    
    func getSubscriptionPricing() -> [(tier: SubscriptionStatus, price: String, features: [String])] {
        return [
            (tier: .free, price: "Free", features: [
                "3 daily voice check-ins",
                "Basic emotion tracking",
                "Simple insights"
            ]),
            (tier: .premium, price: Config.Subscription.premiumPrice + "/month", features: [
                "Unlimited voice check-ins",
                "Advanced emotion analysis",
                "Personalized coaching",
                "ElevenLabs voice affirmations"
            ]),
            (tier: .pro, price: Config.Subscription.proPrice + "/month", features: [
                "Everything in Premium",
                "Custom voice cloning",
                "Advanced analytics",
                "Data export",
                "Priority support"
            ])
        ]
    }
}

// CustomerInfo struct for RevenueCat integration
struct CustomerInfo {
    let activeSubscriptions: [String]
    let originalPurchaseDate: Date?
    let latestExpirationDate: Date?
    
    init(activeSubscriptions: [String] = [], originalPurchaseDate: Date? = nil, latestExpirationDate: Date? = nil) {
        self.activeSubscriptions = activeSubscriptions
        self.originalPurchaseDate = originalPurchaseDate
        self.latestExpirationDate = latestExpirationDate
    }
}



// SANBOX testing //
//    func loadOfferings() {
//        revenueCatService.getOfferings()
//            .receive(on: DispatchQueue.main)
//            .sink(
//                receiveCompletion: { completion in
//                    if case .failure(let error) = completion {
//                        if Config.isDebugMode {
//                            print("❌ Failed to load offerings: \(error)")
//                        }
//                    }
//                },
//                receiveValue: { [weak self] offerings in
//                    self?.currentOffering = offerings.current
//
//                    if let offering = offerings.current {
//                        self?.availablePackages = offering.availablePackages
//
//                        if Config.isDebugMode {
//                            print("✅ Loaded \(offering.availablePackages.count) packages")
//                        }
//                    }
//                }
//            )
//            .store(in: &cancellables)
//    }
// SANBOX testing //

// SANBOX testing //

//    @Published var currentOffering: Offering?
//    @Published var availablePackages: [Package] = []
