//
//  AffirmationPurchaseErrorHandler.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import RevenueCat
import SwiftUI

// MARK: - Purchase Error Handler
class AffirmationPurchaseErrorHandler {
    
    enum PurchaseError: LocalizedError {
        case networkError
        case paymentDeclined
        case productNotFound
        case userCancelled
        case serverError
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .networkError:
                return "Network connection issue. Please check your internet and try again."
            case .paymentDeclined:
                return "Payment was declined. Please check your payment method and try again."
            case .productNotFound:
                return "Product not available. Please try again later."
            case .userCancelled:
                return "Purchase was cancelled."
            case .serverError:
                return "Server error. Please try again in a few minutes."
            case .unknownError(let message):
                return "An unexpected error occurred: \(message)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .networkError:
                return "Check your internet connection and try again."
            case .paymentDeclined:
                return "Verify your payment method or try a different one."
            case .productNotFound:
                return "Contact support if this issue persists."
            case .userCancelled:
                return "You can try purchasing again anytime."
            case .serverError:
                return "Our servers are experiencing issues. Please try again later."
            case .unknownError:
                return "Please try again or contact support if the issue persists."
            }
        }
        
        var shouldRetry: Bool {
            switch self {
            case .networkError, .serverError:
                return true
            case .paymentDeclined, .productNotFound, .userCancelled, .unknownError:
                return false
            }
        }
    }
    
    static func handleRevenueCatError(_ error: Error) -> PurchaseError {
        if let rcError = error as? RevenueCat.ErrorCode {
            switch rcError {
            case .networkError:
                return .networkError
            case .paymentPendingError:
                return .paymentDeclined
            case .productNotAvailableForPurchaseError:
                return .productNotFound
            case .purchaseCancelledError:
                return .userCancelled
            default:
                return .unknownError(rcError.localizedDescription)
            }
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError
            case .timedOut:
                return .serverError
            default:
                return .unknownError(urlError.localizedDescription)
            }
        } else {
            return .unknownError(error.localizedDescription)
        }
    }
    
    static func logError(_ error: Error, context: String) {

    }
}

// MARK: - Purchase Retry Manager
@MainActor
class PurchaseRetryManager: ObservableObject {
    @Published var retryCount = 0
    @Published var canRetry = false
    @Published var retryMessage = ""
    
    private let maxRetries = 3
    private var retryTimer: Timer?
    
    func handleError(_ error: AffirmationPurchaseErrorHandler.PurchaseError) {
        if error.shouldRetry && retryCount < maxRetries {
            retryCount += 1
            canRetry = true
            retryMessage = "Retry \(retryCount)/\(maxRetries): \(error.recoverySuggestion ?? "")"
            
            // Auto-retry after 3 seconds
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                self.canRetry = false
                self.retryMessage = ""
            }
        } else {
            canRetry = false
            retryMessage = error.recoverySuggestion ?? ""
        }
    }
    
    func reset() {
        retryCount = 0
        canRetry = false
        retryMessage = ""
        retryTimer?.invalidate()
        retryTimer = nil
    }
}

// MARK: - Previews
#Preview("Error Handler - Network Error") {
    VStack(spacing: 16) {
        let error = AffirmationPurchaseErrorHandler.PurchaseError.networkError
        
        Text("Network Error Example")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Error: \(error.errorDescription ?? "")")
                .foregroundColor(.red)
            
            Text("Recovery: \(error.recoverySuggestion ?? "")")
                .foregroundColor(.blue)
            
            Text("Should Retry: \(error.shouldRetry ? "Yes" : "No")")
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    .padding()
}

#Preview("Error Handler - Payment Declined") {
    VStack(spacing: 16) {
        let error = AffirmationPurchaseErrorHandler.PurchaseError.paymentDeclined
        
        Text("Payment Declined Example")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Error: \(error.errorDescription ?? "")")
                .foregroundColor(.red)
            
            Text("Recovery: \(error.recoverySuggestion ?? "")")
                .foregroundColor(.blue)
            
            Text("Should Retry: \(error.shouldRetry ? "Yes" : "No")")
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    .padding()
}

#Preview("Retry Manager") {
    VStack(spacing: 20) {
        Text("Retry Manager Test")
            .font(.headline)
        
        let retryManager = PurchaseRetryManager()
        
        VStack(spacing: 12) {
            Text("Retry Count: \(retryManager.retryCount)")
            Text("Can Retry: \(retryManager.canRetry ? "Yes" : "No")")
            Text("Message: \(retryManager.retryMessage)")
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        // Test buttons
        VStack(spacing: 8) {
            Button("Simulate Network Error") {
                retryManager.handleError(.networkError)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Simulate Payment Error") {
                retryManager.handleError(.paymentDeclined)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Reset") {
                retryManager.reset()
            }
            .buttonStyle(.bordered)
        }
    }
    .padding()
}
