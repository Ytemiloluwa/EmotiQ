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
    func getCustomerInfo() -> AnyPublisher<RevenueCat.CustomerInfo, Error>
    func getCustomerInfoAsync() async throws -> RevenueCat.CustomerInfo
    func purchaseProduct(_ productIdentifier: String) -> AnyPublisher<Bool, Error>
    func restorePurchases() -> AnyPublisher<RevenueCat.CustomerInfo, Error>
    func getOfferings() -> AnyPublisher<RevenueCat.Offerings, Error>
    func getOfferings() async throws -> RevenueCat.Offerings
    func checkTrialEligibility() -> AnyPublisher<Bool, Error>
}

class RevenueCatService: RevenueCatServiceProtocol {
    
    // MARK: - Singleton
    static let shared = RevenueCatService()
    
    private(set) var isConfigured = false
    
    // Configuration completion callback
    var onConfigurationComplete: (() -> Void)?
    
    func configure() {
        guard !Config.revenueCatAPIKey.isEmpty && !Config.revenueCatAPIKey.contains("YOUR_") else {
            if Config.isDebugMode {
                print("⚠️ RevenueCat API key not configured - using mock mode")
            }
            return
        }
        
        if Config.isDebugMode {
            print("🔍 RevenueCat: Starting configuration...")
        }
        
        // Configure RevenueCat with your API key
        Purchases.logLevel = Config.isDebugMode ? .debug : .error
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
        
        // Set user attributes for analytics
        Purchases.shared.attribution.setAttributes([
            "app_version": Config.appVersion,
            "build_number": Config.buildNumber
        ])
        
        // Wait for RevenueCat to be ready by testing a simple operation
        Purchases.shared.getCustomerInfo { [weak self] customerInfo, error in
            DispatchQueue.main.async {
                if error == nil {
                    self?.isConfigured = true
                    if Config.isDebugMode {
                        print("✅ RevenueCat configured successfully and ready")
                    }
                    // Notify listeners that configuration is complete
                    self?.onConfigurationComplete?()
                } else {
                    if Config.isDebugMode {
                        print("❌ RevenueCat configuration failed: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
        
        if Config.isDebugMode {
            print("🔍 RevenueCat: Configuration call completed, waiting for readiness...")
        }
    }
    
    func getCustomerInfo() -> AnyPublisher<RevenueCat.CustomerInfo, Error> {
        guard isConfigured else {
            return Fail(error: RevenueCatError.configurationFailed).eraseToAnyPublisher()
        }
        
        return Future { promise in
            Purchases.shared.getCustomerInfo { customerInfo, error in
                if let error = error {
                    promise(.failure(error))
                } else if let customerInfo = customerInfo {
                    // Return RevenueCat's actual CustomerInfo directly
                    promise(.success(customerInfo))
                } else {
                    promise(.failure(RevenueCatError.customerInfoFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getCustomerInfoAsync() async throws -> RevenueCat.CustomerInfo {
        guard isConfigured else {
            throw RevenueCatError.configurationFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getCustomerInfo { customerInfo, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let customerInfo = customerInfo {
                    continuation.resume(returning: customerInfo)
                } else {
                    continuation.resume(throwing: RevenueCatError.customerInfoFailed)
                }
            }
        }
    }
    
    func purchaseProduct(_ productIdentifier: String) -> AnyPublisher<Bool, Error> {
        guard isConfigured else {
            return Fail(error: RevenueCatError.configurationFailed).eraseToAnyPublisher()
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
    
    func restorePurchases() -> AnyPublisher<RevenueCat.CustomerInfo, Error> {
        guard isConfigured else {
            return Fail(error: RevenueCatError.configurationFailed).eraseToAnyPublisher()
        }
        
        return Future { promise in
            Purchases.shared.restorePurchases { customerInfo, error in
                if let error = error {
                    promise(.failure(error))
                } else if let customerInfo = customerInfo {
                    // Return RevenueCat's actual CustomerInfo directly
                    promise(.success(customerInfo))
                    
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
        // If not configured, try to configure first
        if !isConfigured {
            configure()
        }
        
        // If still not configured after trying, return error
        guard isConfigured else {
            if Config.isDebugMode {
                print("⚠️ RevenueCat not configured, returning error")
            }
            return Fail(error: RevenueCatError.configurationFailed).eraseToAnyPublisher()
        }
        
        if Config.isDebugMode {
            print("📦 RevenueCat configured, fetching real offerings")
        }
        
        return Future { promise in
            Purchases.shared.getOfferings { offerings, error in
                if let error = error {
                    if Config.isDebugMode {
                        print("❌ RevenueCat getOfferings error: \(error)")
                    }
                    promise(.failure(error))
                } else if let offerings = offerings {
                    if Config.isDebugMode {
                        print("✅ RevenueCat offerings loaded successfully")
                    }
                    promise(.success(offerings))
                } else {
                    if Config.isDebugMode {
                        print("❌ RevenueCat offerings is nil")
                    }
                    promise(.failure(RevenueCatError.offeringsFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getOfferings() async throws -> RevenueCat.Offerings {
        // If not configured, try to configure first
        if !isConfigured {
            configure()
        }
        
        // If still not configured after trying, return error
        guard isConfigured else {
            if Config.isDebugMode {
                print("⚠️ RevenueCat not configured, returning error")
            }
            throw RevenueCatError.configurationFailed
        }
        
        if Config.isDebugMode {
            print("📦 RevenueCat configured, fetching real offerings")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getOfferings { offerings, error in
                if let error = error {
                    if Config.isDebugMode {
                        print("❌ RevenueCat getOfferings error: \(error)")
                    }
                    continuation.resume(throwing: error)
                } else if let offerings = offerings {
                    if Config.isDebugMode {
                        print("✅ RevenueCat offerings loaded successfully")
                    }
                    continuation.resume(returning: offerings)
                } else {
                    if Config.isDebugMode {
                        print("❌ RevenueCat offerings is nil")
                    }
                    continuation.resume(throwing: RevenueCatError.offeringsFailed)
                }
            }
        }
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
    
    // Removed convertOffering method - no longer needed since we're using RevenueCat native types
    
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
