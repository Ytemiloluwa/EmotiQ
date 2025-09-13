//
//  SecurePurchaseManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//
import Foundation
import Security
import Combine
import RevenueCat
import UIKit

// MARK: - Purchase Origin Tracking
enum PurchaseOrigin: String, CaseIterable {
    case affirmationsView = "affirmations_view"
    case customAffirmationCreator = "custom_affirmation_creator"
    
    var displayName: String {
        switch self {
        case .affirmationsView:
            return "Affirmations"
        case .customAffirmationCreator:
            return "Custom Affirmations"
        }
    }
}

// MARK: - Secure Purchase Manager
@MainActor
class SecurePurchaseManager: ObservableObject {
    static let shared = SecurePurchaseManager()
    
    // MARK: - Published Properties
    @Published var affirmationsViewUsage: Int = 0
    @Published var customAffirmationUsage: Int = 0
    @Published var sharedPackUsage: Int = 0
    @Published var hasLifetimeAccess: Bool = false
    @Published var hasPackAccess: Bool = false
    @Published var hasPremiumAccess: Bool = false
    @Published var hasProAccess: Bool = false
    @Published var lastPurchaseOrigin: PurchaseOrigin?
    
    // MARK: - Private Properties
    private let keychainService = "Temi.EmotiQ.purchase"
    private let revenueCatService: RevenueCatServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    private let maxFreeUsage = 3
    private let maxPackUsage = 10
    
    // MARK: - Initialization
    private init(revenueCatService: RevenueCatServiceProtocol = RevenueCatService.shared) {
        self.revenueCatService = revenueCatService
        loadSecureData()
        setupRevenueCatValidation()
    }
    
    // MARK: - Public Methods
    
    /// Check if user can generate affirmations in AffirmationsView
    func canGenerateAffirmations(from origin: PurchaseOrigin) async -> Bool {
        
        // First check if user has ANY subscription (Premium/Pro)
        guard await validateWithRevenueCat() else {

            return false
        }
        
        // Premium/Pro users get 3 free generations + pack usage if they have it
        let result: Bool
        switch origin {
        case .affirmationsView:
            if hasLifetimeAccess {
                result = true
             
            } else if hasPackAccess {
                // Pack users get ONLY pack usage (10 generations)
                result = sharedPackUsage < maxPackUsage

            } else {
                // Free users and premium/pro users get free usage
                result = affirmationsViewUsage < maxFreeUsage

            }
        case .customAffirmationCreator:
            if hasLifetimeAccess {
                result = true
   
            } else if hasPackAccess {
                // Pack users get ONLY pack usage (10 generations)
                result = sharedPackUsage < maxPackUsage

            } else {
                // Free users and premium/pro users get free usage
                result = customAffirmationUsage < maxFreeUsage

            }
        }
        
        return result
    }
    
    /// Check if user needs to purchase more
    func needsToPurchase(from origin: PurchaseOrigin) async -> Bool {
    
        
        let canGenerate = await canGenerateAffirmations(from: origin)
        let needsPurchase = !canGenerate
    
        
        return needsPurchase
    }
    
    /// Get remaining uses for a specific origin
    func getRemainingUses(for origin: PurchaseOrigin) async -> Int {
   
        
        // First check if user has ANY subscription (Premium/Pro)
        guard await validateWithRevenueCat() else {

            return 0
        }
        
        let result: Int
        if hasLifetimeAccess {
            result = -1  // -1 means unlimited, no count needed
        
        } else if hasPackAccess {
    
            result = max(0, maxPackUsage - sharedPackUsage)
        } else {
            // Free users and premium/pro users get free usage
            switch origin {
            case .affirmationsView:
                result = max(0, maxFreeUsage - affirmationsViewUsage)
            case .customAffirmationCreator:
                result = max(0, maxFreeUsage - customAffirmationUsage)

            }
        }
        
        return result
    }
    
    /// Increment usage for a specific origin
    func incrementUsage(for origin: PurchaseOrigin) async {
   
        guard await validateWithRevenueCat() else { return }
        
        switch origin {
        case .affirmationsView:
            if hasLifetimeAccess {
               
                return // No tracking needed for lifetime
            } else if hasPackAccess {
                sharedPackUsage += 1

            } else {
                affirmationsViewUsage += 1

            }
        case .customAffirmationCreator:
            if hasLifetimeAccess {
                
                return // No tracking needed for lifetime
            } else if hasPackAccess {
                sharedPackUsage += 1

            } else {
                customAffirmationUsage += 1

            }
        }
        
        saveSecureData()
        await trackUsageOnServer(for: origin)
    }
    
    /// Activate lifetime access
    func activateLifetimeAccess() async {
        hasLifetimeAccess = true
        hasPackAccess = false
        lastPurchaseOrigin = nil
        
        // Reset all usage counters
        affirmationsViewUsage = 0
        customAffirmationUsage = 0
        sharedPackUsage = 0
        
        saveSecureData()
        await trackPurchaseOnServer(plan: .lifetime)
        
    
    }
    
    /// Activate pack access
    func activatePackAccess() async {
        hasPackAccess = true
        hasLifetimeAccess = false
        
        // Reset pack usage
        sharedPackUsage = 0
        
        saveSecureData()
        await trackPurchaseOnServer(plan: .pack)
        
    }
    
    /// Reset usage for testing or pack activation
    func resetUsage() async {
        affirmationsViewUsage = 0
        customAffirmationUsage = 0
        sharedPackUsage = 0
        
        saveSecureData()

    }
    
    /// Set purchase origin for navigation tracking
    func setPurchaseOrigin(_ origin: PurchaseOrigin) {
        lastPurchaseOrigin = origin
        saveSecureData()
    }
    
    /// Get the last purchase origin for navigation
    func getLastPurchaseOrigin() -> PurchaseOrigin? {
        return lastPurchaseOrigin
    }
    
    // MARK: - Private Methods
    
    /// Validate with RevenueCat (secure validation)
    func validateWithRevenueCat() async -> Bool {
        do {
            
            // Check if RevenueCat is configured
            guard RevenueCatService.shared.isConfigured else {
              
                
                // Wait for configuration to complete using callback
                return await withCheckedContinuation { continuation in
                    RevenueCatService.shared.onConfigurationComplete = {
                        Task {
                            let result = await self.validateWithRevenueCat()
                            continuation.resume(returning: result)
                        }
                    }
                }
            }
            
            let customerInfo = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RevenueCat.CustomerInfo, Error>) in
                revenueCatService.getCustomerInfo()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                          
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { customerInfo in
   
                            continuation.resume(returning: customerInfo)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // 🔹 Non-consumables (check entitlements - can be restored)
            let hasLifetime = customerInfo.entitlements.all["unlimited_affirmations"]?.isActive == true
            
            // 🔹 Premium/Pro subscriptions
            let hasPremium = customerInfo.activeSubscriptions.contains("emotiq_premium_monthly")
            let hasPro = customerInfo.activeSubscriptions.contains("emotiq_pro_monthly")
            
            // 🔹 Consumables (check product identifier in purchase history)
            // Consumables cannot be validated via entitlements or restore
            let hasPackPurchase = customerInfo.nonSubscriptions.contains { transaction in
                transaction.productIdentifier == "affirmation_pack_10"
            }
            
            
            // Update local state to match RevenueCat
            hasLifetimeAccess = hasLifetime  // Non-consumable: check entitlements
            hasPackAccess = hasPackPurchase  // Consumable: check product identifier
            hasPremiumAccess = hasPremium
            hasProAccess = hasPro
            
            // Get all active subscriptions and entitlements for debugging
            let allActiveSubscriptions = customerInfo.activeSubscriptions
            let allEntitlements = customerInfo.entitlements.all.keys
            let allNonSubscriptionTransactions = customerInfo.nonSubscriptions.map { $0.productIdentifier }
            
            // Check if user has any valid subscription OR entitlement OR consumable purchase
            let hasValidSubscription = hasLifetime || hasPremium || hasPro || hasPackPurchase

            
            return hasValidSubscription
        } catch {

            return false
        }
    }
    
    /// Setup RevenueCat validation on app launch
    private func setupRevenueCatValidation() {
        // Validate with RevenueCat every time the app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.validateWithRevenueCat()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Save data to Keychain
    private func saveSecureData() {
        let data = PurchaseData(
            affirmationsViewUsage: affirmationsViewUsage,
            customAffirmationUsage: customAffirmationUsage,
            sharedPackUsage: sharedPackUsage,
            hasLifetimeAccess: hasLifetimeAccess,
            hasPackAccess: hasPackAccess,
            hasPremiumAccess: hasPremiumAccess,
            hasProAccess: hasProAccess,
            lastPurchaseOrigin: lastPurchaseOrigin?.rawValue
        )
        
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(data)
            try saveToKeychain(encodedData, forKey: "purchase_data")
        } catch {
           
        }
    }
    
    /// Load data from Keychain
    private func loadSecureData() {
        do {
            let data = try loadFromKeychain(forKey: "purchase_data")
            let decoder = JSONDecoder()
            let purchaseData = try decoder.decode(PurchaseData.self, from: data)
            
            affirmationsViewUsage = purchaseData.affirmationsViewUsage
            customAffirmationUsage = purchaseData.customAffirmationUsage
            sharedPackUsage = purchaseData.sharedPackUsage
            hasLifetimeAccess = purchaseData.hasLifetimeAccess
            hasPackAccess = purchaseData.hasPackAccess
            hasPremiumAccess = purchaseData.hasPremiumAccess
            hasProAccess = purchaseData.hasProAccess
            lastPurchaseOrigin = PurchaseOrigin(rawValue: purchaseData.lastPurchaseOrigin ?? "")
            
        
        } catch {
            
        }
    }
    
    /// Save data to Keychain
    private func saveToKeychain(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Load data from Keychain
    private func loadFromKeychain(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.loadFailed(status)
        }
        
        return data
    }
    
    /// Track usage on server (placeholder for production)
    private func trackUsageOnServer(for origin: PurchaseOrigin) async {
        // TODO: Implement server-side usage tracking
    }
    
    /// Track purchase on server (placeholder for production)
    private func trackPurchaseOnServer(plan: AffirmationPlan) async {
        // TODO: Implement server-side purchase tracking

    }
}

// MARK: - Supporting Types

/// Purchase data structure for Keychain storage
private struct PurchaseData: Codable {
    let affirmationsViewUsage: Int
    let customAffirmationUsage: Int
    let sharedPackUsage: Int
    let hasLifetimeAccess: Bool
    let hasPackAccess: Bool
    let hasPremiumAccess: Bool
    let hasProAccess: Bool
    let lastPurchaseOrigin: String?
}

/// Keychain error types
enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from Keychain: \(status)"
        }
    }
}
