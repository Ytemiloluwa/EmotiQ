//
//  AffirmationPurchaseFlow.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Affirmation Purchase Flow Manager
@MainActor
class AffirmationPurchaseFlowManager: ObservableObject {
    static let shared = AffirmationPurchaseFlowManager()
    
    init() {}
    @Published var showingPurchaseView = false
    @Published var purchaseCompleted = false
    @Published var currentPurchaseStatus: PurchaseStatus = .idle
    @Published var errorMessage: String?
    @Published var showingError = false
    
    private var cancellables = Set<AnyCancellable>()
    
    enum PurchaseStatus: Equatable {
        case idle
        case purchasing
        case completed
        case failed(String)
        
        static func == (lhs: PurchaseStatus, rhs: PurchaseStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.purchasing, .purchasing):
                return true
            case (.completed, .completed):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
        
        var displayText: String {
            switch self {
            case .idle: return "Buy More"
            case .purchasing: return "Processing..."
            case .completed: return "Purchased"
            case .failed: return "Failed"
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return "cart"
            case .purchasing: return "clock"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "exclamationmark.circle"
            }
        }
        
        var isEnabled: Bool {
            switch self {
            case .idle: return true
            case .purchasing: return false
            case .completed: return false
            case .failed: return true
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .idle: return .purple
            case .purchasing: return .gray
            case .completed: return .green
            case .failed: return .red
            }
        }
    }
    
    func startPurchase() {
        showingPurchaseView = true
        currentPurchaseStatus = .idle
        errorMessage = nil
    }
    
    func handlePurchaseCompleted() {
        purchaseCompleted = true
        currentPurchaseStatus = .completed
        
        // Reset after a delay to allow user to see success state
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.currentPurchaseStatus = .idle
            self.purchaseCompleted = false
        }
    }
    
    func handlePurchaseFailed(_ error: String) {
        currentPurchaseStatus = .failed(error)
        errorMessage = error
        showingError = true
        
        // Reset after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.currentPurchaseStatus = .idle
            self.errorMessage = nil
        }
    }
    
    func resetPurchaseStatus() {
        currentPurchaseStatus = .idle
        purchaseCompleted = false
        errorMessage = nil
        showingError = false
    }
}

// MARK: - Purchase Button Component
struct AffirmationPurchaseButton: View {
    @ObservedObject var purchaseManager: AffirmationPurchaseFlowManager
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if purchaseManager.currentPurchaseStatus.isEnabled {
                purchaseManager.startPurchase()
                action()
            }
        }) {
            HStack(spacing: 8) {
                if purchaseManager.currentPurchaseStatus == .purchasing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: purchaseManager.currentPurchaseStatus.icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(purchaseManager.currentPurchaseStatus.displayText)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [
                        purchaseManager.currentPurchaseStatus.backgroundColor,
                        purchaseManager.currentPurchaseStatus.backgroundColor.opacity(0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: purchaseManager.currentPurchaseStatus.backgroundColor.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(!purchaseManager.currentPurchaseStatus.isEnabled)
        .hapticFeedback(.primary)
        .alert("Purchase Error", isPresented: $purchaseManager.showingError) {
            Button("OK") {
                purchaseManager.resetPurchaseStatus()
            }
        } message: {
            Text(purchaseManager.errorMessage ?? "An unknown error occurred")
        }
    }
}

// MARK: - Purchase Status Indicator
struct PurchaseStatusIndicator: View {
    let status: AffirmationPurchaseFlowManager.PurchaseStatus
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .foregroundColor(status.backgroundColor)
            
            Text(status.displayText)
                .font(.caption)
                .foregroundColor(status.backgroundColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(status.backgroundColor.opacity(0.1))
        )
    }
}

// MARK: - Previews
#Preview("Purchase Flow Manager") {
    VStack(spacing: 20) {
        Text("Purchase Flow Manager Test")
            .font(.headline)
        
        // Test different purchase statuses
        Group {
            PurchaseStatusIndicator(status: .idle)
            PurchaseStatusIndicator(status: .purchasing)
            PurchaseStatusIndicator(status: .completed)
            PurchaseStatusIndicator(status: .failed("Payment declined"))
        }
        
        // Test purchase button
        AffirmationPurchaseButton(
            purchaseManager: AffirmationPurchaseFlowManager()
        ) {
           
        }
    }
    .padding()
}

#Preview("Purchase Button - Idle") {
    let manager = AffirmationPurchaseFlowManager()
    manager.currentPurchaseStatus = .idle
    
    return AffirmationPurchaseButton(purchaseManager: manager) {
      
    }
    .padding()
}

#Preview("Purchase Button - Purchasing") {
    let manager = AffirmationPurchaseFlowManager()
    manager.currentPurchaseStatus = .purchasing
    
    return AffirmationPurchaseButton(purchaseManager: manager) {
        
    }
    .padding()
}

#Preview("Purchase Button - Completed") {
    let manager = AffirmationPurchaseFlowManager()
    manager.currentPurchaseStatus = .completed
    
    return AffirmationPurchaseButton(purchaseManager: manager) {
      
    }
    .padding()
}

#Preview("Purchase Button - Failed") {
    let manager = AffirmationPurchaseFlowManager()
    manager.currentPurchaseStatus = .failed("Network error")
    
    return AffirmationPurchaseButton(purchaseManager: manager) {
        
    }
    .padding()
}

#Preview("Status Indicators") {
    VStack(spacing: 16) {
        PurchaseStatusIndicator(status: .idle)
        PurchaseStatusIndicator(status: .purchasing)
        PurchaseStatusIndicator(status: .completed)
        PurchaseStatusIndicator(status: .failed("Payment declined"))
    }
    .padding()
}
