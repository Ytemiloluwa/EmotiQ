//
//  RevenueCatService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation
import Combine
import RevenueCat

protocol RevenueCatServiceProtocol {
    func configure()
    func getCustomerInfo() -> AnyPublisher<CustomerInfo, Error>
    func purchaseProduct(_ productIdentifier: String) -> AnyPublisher<Bool, Error>
    func restorePurchases() -> AnyPublisher<CustomerInfo, Error>
    func getOfferings() -> AnyPublisher<RevenueCat.Offerings, Error>
    func checkTrialEligibility() -> AnyPublisher<Bool, Error>
}

class RevenueCatService: RevenueCatServiceProtocol {
    
    private var isConfigured = false
    
    func configure() {
        guard !Config.revenueCatAPIKey.isEmpty && !Config.revenueCatAPIKey.contains("YOUR_") else {
            if Config.isDebugMode {
                print("⚠️ RevenueCat API key not configured - using mock mode")
            }
            return
        }
        
        // Configure RevenueCat with your API key
        Purchases.logLevel = Config.isDebugMode ? .debug : .error
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
        
        // Set user attributes for analytics
        Purchases.shared.attribution.setAttributes([
            "app_version": Config.appVersion,
            "build_number": Config.buildNumber
        ])
        
        isConfigured = true
        
        if Config.isDebugMode {
            print("✅ RevenueCat configured successfully")
        }
    }
    
    func getCustomerInfo() -> AnyPublisher<CustomerInfo, Error> {
        guard isConfigured else {
            return getMockCustomerInfo()
        }
        
        return Future { promise in
            Purchases.shared.getCustomerInfo { customerInfo, error in
                if let error = error {
                    promise(.failure(error))
                } else if let customerInfo = customerInfo {
                    let customInfo = CustomerInfo(
                        activeSubscriptions: Array(customerInfo.activeSubscriptions),
                        originalPurchaseDate: customerInfo.originalPurchaseDate,
                        latestExpirationDate: customerInfo.latestExpirationDate
                    )
                    promise(.success(customInfo))
                } else {
                    promise(.failure(RevenueCatError.customerInfoFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func purchaseProduct(_ productIdentifier: String) -> AnyPublisher<Bool, Error> {
        guard isConfigured else {
            return getMockPurchase(productIdentifier)
        }
        
        return Future { promise in
            Purchases.shared.getOfferings { offerings, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let offerings = offerings,
                      let package = self.findPackage(productIdentifier: productIdentifier, in: offerings) else {
                    promise(.failure(RevenueCatError.productNotFound))
                    return
                }
                
                Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
                    if let error = error {
                        promise(.failure(error))
                    } else if userCancelled {
                        promise(.failure(RevenueCatError.purchaseCancelled))
                    } else if transaction != nil {
                        promise(.success(true))
                        
                        if Config.isDebugMode {
                            print("✅ Purchase successful: \(productIdentifier)")
                        }
                    } else {
                        promise(.failure(RevenueCatError.purchaseFailed))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func restorePurchases() -> AnyPublisher<CustomerInfo, Error> {
        guard isConfigured else {
            return getMockRestore()
        }
        
        return Future { promise in
            Purchases.shared.restorePurchases { customerInfo, error in
                if let error = error {
                    promise(.failure(error))
                } else if let customerInfo = customerInfo {
                    let customInfo = CustomerInfo(
                        activeSubscriptions: Array(customerInfo.activeSubscriptions),
                        originalPurchaseDate: customerInfo.originalPurchaseDate,
                        latestExpirationDate: customerInfo.latestExpirationDate
                    )
                    promise(.success(customInfo))
                    
                    if Config.isDebugMode {
                        print("✅ Purchases restored successfully")
                    }
                } else {
                    promise(.failure(RevenueCatError.restoreFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getOfferings() -> AnyPublisher<RevenueCat.Offerings, Error> {
        guard isConfigured else {
            return getMockOfferings()
        }
        
        return Future { promise in
            Purchases.shared.getOfferings { offerings, error in
                if let error = error {
                    promise(.failure(error))
                } else if let offerings = offerings {
                    promise(.success(offerings))
                } else {
                    promise(.failure(RevenueCatError.offeringsFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func checkTrialEligibility() -> AnyPublisher<Bool, Error> {
        return getCustomerInfo()
            .map { customerInfo in
                // User is eligible for trial if they haven't had any active subscriptions
                return customerInfo.originalPurchaseDate == nil
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func findPackage(productIdentifier: String, in offerings: RevenueCat.Offerings) -> RevenueCat.Package? {
        // Look for the package in current offering
        if let currentOffering = offerings.current {
            for package in currentOffering.availablePackages {
                if package.storeProduct.productIdentifier == productIdentifier {
                    return package
                }
            }
        }
        
        // Look in all offerings
        for offering in offerings.all.values {
            for package in offering.availablePackages {
                if package.storeProduct.productIdentifier == productIdentifier {
                    return package
                }
            }
        }
        
        return nil
    }
    
    
    // MARK: - Mock Methods (for development without API key)
    
    private func getMockCustomerInfo() -> AnyPublisher<CustomerInfo, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                Thread.sleep(forTimeInterval: 0.5)
                
                DispatchQueue.main.async {
                    let customerInfo = CustomerInfo(
                        activeSubscriptions: [],
                        originalPurchaseDate: nil,
                        latestExpirationDate: nil
                    )
                    promise(.success(customerInfo))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func getMockPurchase(_ productIdentifier: String) -> AnyPublisher<Bool, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                Thread.sleep(forTimeInterval: 1.0)
                
                DispatchQueue.main.async {
                    // Simulate 90% success rate for testing
                    let success = Int.random(in: 1...10) <= 9
                    promise(.success(success))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func getMockRestore() -> AnyPublisher<CustomerInfo, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                Thread.sleep(forTimeInterval: 1.0)
                
                DispatchQueue.main.async {
                    let customerInfo = CustomerInfo(
                        activeSubscriptions: [],
                        originalPurchaseDate: Date().addingTimeInterval(-86400 * 30),
                        latestExpirationDate: Date().addingTimeInterval(86400 * 30)
                    )
                    promise(.success(customerInfo))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func getMockOfferings() -> AnyPublisher<RevenueCat.Offerings, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                Thread.sleep(forTimeInterval: 0.5)
                
                DispatchQueue.main.async {
                    // For mock mode, we'll return nil since we can't create RevenueCat types
                    // In a real implementation, you'd need to create proper RevenueCat types
                    // or handle mock data differently
                    promise(.failure(RevenueCatError.offeringsFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

enum RevenueCatError: Error, LocalizedError {
    case configurationFailed
    case customerInfoFailed
    case purchaseFailed
    case purchaseCancelled
    case restoreFailed
    case offeringsFailed
    case productNotFound
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .configurationFailed:
            return "Failed to configure RevenueCat."
        case .customerInfoFailed:
            return "Failed to get customer information."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .purchaseCancelled:
            return "Purchase was cancelled."
        case .restoreFailed:
            return "Failed to restore purchases."
        case .offeringsFailed:
            return "Failed to load subscription options."
        case .productNotFound:
            return "Subscription product not found."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}


