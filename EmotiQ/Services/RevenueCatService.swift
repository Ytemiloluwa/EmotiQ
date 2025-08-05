//
//  RevenueCatService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation
import Combine

protocol RevenueCatServiceProtocol {
    func configure()
    func getCustomerInfo() -> AnyPublisher<CustomerInfo, Error>
    func purchaseProduct(_ productIdentifier: String) -> AnyPublisher<Bool, Error>
    func restorePurchases() -> AnyPublisher<CustomerInfo, Error>
}

class RevenueCatService: RevenueCatServiceProtocol {
    
    func configure() {
        // RevenueCat configuration will be implemented when API keys are added
        // For now, this is a placeholder
        print("RevenueCat configuration placeholder - add API key in Config.swift")
    }
    
    func getCustomerInfo() -> AnyPublisher<CustomerInfo, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                // Simulate API call delay
                Thread.sleep(forTimeInterval: 0.5)
                
                // Return mock customer info for development
                let customerInfo = CustomerInfo(
                    activeSubscriptions: [],
                    originalPurchaseDate: nil,
                    latestExpirationDate: nil
                )
                
                promise(.success(customerInfo))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func purchaseProduct(_ productIdentifier: String) -> AnyPublisher<Bool, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                // Simulate purchase flow
                Thread.sleep(forTimeInterval: 1.0)
                
                // For development, simulate successful purchase
                let success = Bool.random() // Random success for testing
                promise(.success(success))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func restorePurchases() -> AnyPublisher<CustomerInfo, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                // Simulate restore purchases
                Thread.sleep(forTimeInterval: 1.0)
                
                // Return mock restored customer info
                let customerInfo = CustomerInfo(
                    activeSubscriptions: [],
                    originalPurchaseDate: Date().addingTimeInterval(-86400 * 30), // 30 days ago
                    latestExpirationDate: Date().addingTimeInterval(86400 * 30) // 30 days from now
                )
                
                promise(.success(customerInfo))
            }
        }
        .eraseToAnyPublisher()
    }
}

enum RevenueCatError: Error, LocalizedError {
    case configurationFailed
    case purchaseFailed
    case restoreFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .configurationFailed:
            return "Failed to configure RevenueCat."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .restoreFailed:
            return "Failed to restore purchases."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}


