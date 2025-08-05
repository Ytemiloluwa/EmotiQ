//
//  SubscriptionService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation
import Combine

protocol SubscriptionServiceProtocol {
    var subscriptionStatusPublisher: AnyPublisher<SubscriptionStatus, Never> { get }
    func checkSubscriptionStatus() -> AnyPublisher<SubscriptionStatus, Error>
    func purchaseSubscription(_ status: SubscriptionStatus) -> AnyPublisher<Bool, Error>
    func restorePurchases() -> AnyPublisher<SubscriptionStatus, Error>
}

class SubscriptionService: SubscriptionServiceProtocol {
    @Published private var currentSubscriptionStatus: SubscriptionStatus = .free
    private let revenueCatService = RevenueCatService()
    
    var subscriptionStatusPublisher: AnyPublisher<SubscriptionStatus, Never> {
        $currentSubscriptionStatus.eraseToAnyPublisher()
    }
    
    init() {
        setupRevenueCat()
    }
    
    private func setupRevenueCat() {
        // RevenueCat will be configured when API keys are added
        revenueCatService.configure()
    }
    
    func checkSubscriptionStatus() -> AnyPublisher<SubscriptionStatus, Error> {
        return revenueCatService.getCustomerInfo()
            .map { [weak self] customerInfo in
                let status = self?.determineSubscriptionStatus(from: customerInfo) ?? .free
                self?.currentSubscriptionStatus = status
                return status
            }
            .catch { _ in
                Just(SubscriptionStatus.free)
                    .setFailureType(to: Error.self)
            }
            .eraseToAnyPublisher()
    }
    
    func purchaseSubscription(_ status: SubscriptionStatus) -> AnyPublisher<Bool, Error> {
        guard status != .free else {
            return Just(false)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return revenueCatService.purchaseProduct(status.productIdentifier)
            .map { [weak self] success in
                if success {
                    self?.currentSubscriptionStatus = status
                }
                return success
            }
            .eraseToAnyPublisher()
    }
    
    func restorePurchases() -> AnyPublisher<SubscriptionStatus, Error> {
        return revenueCatService.restorePurchases()
            .map { [weak self] customerInfo in
                let status = self?.determineSubscriptionStatus(from: customerInfo) ?? .free
                self?.currentSubscriptionStatus = status
                return status
            }
            .eraseToAnyPublisher()
    }
    
    private func determineSubscriptionStatus(from customerInfo: CustomerInfo) -> SubscriptionStatus {
        // Check for active subscriptions
        if customerInfo.activeSubscriptions.contains("emotiq_pro_monthly") {
            return .pro
        } else if customerInfo.activeSubscriptions.contains("emotiq_premium_monthly") {
            return .premium
        } else {
            return .free
        }
    }
}

// Temporary CustomerInfo struct until RevenueCat is properly integrated
struct CustomerInfo {
    let activeSubscriptions: Set<String>
    let originalPurchaseDate: Date?
    let latestExpirationDate: Date?
    
    init(activeSubscriptions: Set<String> = [], originalPurchaseDate: Date? = nil, latestExpirationDate: Date? = nil) {
        self.activeSubscriptions = activeSubscriptions
        self.originalPurchaseDate = originalPurchaseDate
        self.latestExpirationDate = latestExpirationDate
    }
}

