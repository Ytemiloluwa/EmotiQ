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
        print("🔍 SecurePurchaseManager: canGenerateAffirmations called for \(origin.displayName)")
        
        // First check if user has ANY subscription (Premium/Pro)
        guard await validateWithRevenueCat() else {
            print("❌ SecurePurchaseManager: \(origin.displayName) - No valid subscription, free users get nothing")
            return false
        }
        
        // Premium/Pro users get 3 free generations + pack usage if they have it
        let result: Bool
        switch origin {
        case .affirmationsView:
            if hasLifetimeAccess {
                result = true
                print("🔍 SecurePurchaseManager: AffirmationsView - Lifetime access, can generate")
            } else if hasPackAccess {
                // Pack users get ONLY pack usage (10 generations)
                result = sharedPackUsage < maxPackUsage
                print("🔍 SecurePurchaseManager: AffirmationsView - Pack access, pack usage: \(sharedPackUsage)/\(maxPackUsage), can generate: \(result)")
            } else {
                // Free users and premium/pro users get free usage
                result = affirmationsViewUsage < maxFreeUsage
                print("🔍 SecurePurchaseManager: AffirmationsView - Free tier, usage: \(affirmationsViewUsage)/\(maxFreeUsage), can generate: \(result)")
            }
        case .customAffirmationCreator:
            if hasLifetimeAccess {
                result = true
                print("🔍 SecurePurchaseManager: CustomAffirmationCreator - Lifetime access, can generate")
            } else if hasPackAccess {
                // Pack users get ONLY pack usage (10 generations)
                result = sharedPackUsage < maxPackUsage
                print("🔍 SecurePurchaseManager: CustomAffirmationCreator - Pack access, pack usage: \(sharedPackUsage)/\(maxPackUsage), can generate: \(result)")
            } else {
                // Free users and premium/pro users get free usage
                result = customAffirmationUsage < maxFreeUsage
                print("🔍 SecurePurchaseManager: CustomAffirmationCreator - Free tier, usage: \(customAffirmationUsage)/\(maxFreeUsage), can generate: \(result)")
            }
        }
        
        print("🔍 SecurePurchaseManager: Final canGenerate result for \(origin.displayName): \(result)")
        return result
    }
    
    /// Check if user needs to purchase more
    func needsToPurchase(from origin: PurchaseOrigin) async -> Bool {
        print("🔍 SecurePurchaseManager: needsToPurchase called for \(origin.displayName)")
        
        let canGenerate = await canGenerateAffirmations(from: origin)
        let needsPurchase = !canGenerate
        
        print("🔍 SecurePurchaseManager: \(origin.displayName) - canGenerate: \(canGenerate), needsPurchase: \(needsPurchase)")
        
        return needsPurchase
    }
    
    /// Get remaining uses for a specific origin
    func getRemainingUses(for origin: PurchaseOrigin) async -> Int {
        print("🔍 SecurePurchaseManager: getRemainingUses called for \(origin.displayName)")
        
        // First check if user has ANY subscription (Premium/Pro)
        guard await validateWithRevenueCat() else {
            print("❌ SecurePurchaseManager: \(origin.displayName) - No valid subscription, free users get 0 remaining")
            return 0
        }
        
        let result: Int
        if hasLifetimeAccess {
            result = -1  // -1 means unlimited, no count needed
            print("🔍 SecurePurchaseManager: \(origin.displayName) - Lifetime access, unlimited")
        } else if hasPackAccess {
            // Pack users get ONLY pack usage (10 generations)
            result = max(0, maxPackUsage - sharedPackUsage)
            print("🔍 SecurePurchaseManager: \(origin.displayName) - Pack access, pack remaining: \(result)/\(maxPackUsage)")
        } else {
            // Free users and premium/pro users get free usage
            switch origin {
            case .affirmationsView:
                result = max(0, maxFreeUsage - affirmationsViewUsage)
                print("🔍 SecurePurchaseManager: \(origin.displayName) - Free tier, usage: \(affirmationsViewUsage)/\(maxFreeUsage), remaining: \(result)")
            case .customAffirmationCreator:
                result = max(0, maxFreeUsage - customAffirmationUsage)
                print("🔍 SecurePurchaseManager: \(origin.displayName) - Free tier, usage: \(customAffirmationUsage)/\(maxFreeUsage), remaining: \(result)")
            }
        }
        
        print("🔍 SecurePurchaseManager: \(origin.displayName) - Final remaining uses: \(result)")
        return result
    }
    
    /// Increment usage for a specific origin
    func incrementUsage(for origin: PurchaseOrigin) async {
        print("🔍 SecurePurchaseManager: incrementUsage called for \(origin.displayName)")
        
        guard await validateWithRevenueCat() else {
            print("❌ SecurePurchaseManager: RevenueCat validation failed - cannot increment usage")
            return
        }
        
        print("🔍 SecurePurchaseManager: \(origin.displayName) - Current state - Lifetime: \(hasLifetimeAccess), Pack: \(hasPackAccess)")
        
        switch origin {
        case .affirmationsView:
            if hasLifetimeAccess {
                print("🔍 SecurePurchaseManager: AffirmationsView - Lifetime access, no tracking needed")
                return // No tracking needed for lifetime
            } else if hasPackAccess {
                sharedPackUsage += 1
                print("📦 SecurePurchaseManager: AffirmationsView - Incremented shared pack usage to \(sharedPackUsage)")
            } else {
                affirmationsViewUsage += 1
                print("📊 SecurePurchaseManager: AffirmationsView - Incremented free usage to \(affirmationsViewUsage)")
            }
        case .customAffirmationCreator:
            if hasLifetimeAccess {
                print("🔍 SecurePurchaseManager: CustomAffirmationCreator - Lifetime access, no tracking needed")
                return // No tracking needed for lifetime
            } else if hasPackAccess {
                sharedPackUsage += 1
                print("📦 SecurePurchaseManager: CustomAffirmationCreator - Incremented shared pack usage to \(sharedPackUsage)")
            } else {
                customAffirmationUsage += 1
                print("📊 SecurePurchaseManager: CustomAffirmationCreator - Incremented free usage to \(customAffirmationUsage)")
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
        
        print("✅ Lifetime access activated securely")
    }
    
    /// Activate pack access
    func activatePackAccess() async {
        hasPackAccess = true
        hasLifetimeAccess = false
        
        // Reset pack usage
        sharedPackUsage = 0
        
        saveSecureData()
        await trackPurchaseOnServer(plan: .pack)
        
        print("✅ Pack access activated securely")
    }
    
    /// Reset usage for testing or pack activation
    func resetUsage() async {
        affirmationsViewUsage = 0
        customAffirmationUsage = 0
        sharedPackUsage = 0
        
        saveSecureData()
        print("🔄 Usage reset securely")
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
    private func validateWithRevenueCat() async -> Bool {
        do {
            print("🔍 SecurePurchaseManager: Starting RevenueCat validation...")
            
            // Check if RevenueCat is configured
            guard RevenueCatService.shared.isConfigured else {
                print("⚠️ SecurePurchaseManager: RevenueCat not configured yet, waiting for callback...")
                
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
                                print("❌ SecurePurchaseManager: RevenueCat getCustomerInfo failed: \(error)")
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { customerInfo in
                            print("✅ SecurePurchaseManager: RevenueCat getCustomerInfo success")
                            continuation.resume(returning: customerInfo)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // 🔹 Non-consumables (check entitlements defined in RevenueCat dashboard)
            let hasLifetime = customerInfo.entitlements.all["unlimited_affirmations"]?.isActive == true
            let hasPack = customerInfo.entitlements.all["affirmation_pack_10"]?.isActive == true
            
            // 🔹 Premium/Pro subscriptions
            let hasPremium = customerInfo.activeSubscriptions.contains("emotiq_premium_monthly")
            let hasPro = customerInfo.activeSubscriptions.contains("emotiq_pro_monthly")
            
            print("🔍 SecurePurchaseManager: RevenueCat entitlements - Lifetime: \(hasLifetime), Pack: \(hasPack)")
            print("🔍 SecurePurchaseManager: RevenueCat subscriptions - Premium: \(hasPremium), Pro: \(hasPro)")
            
            // Update local state to match RevenueCat
            hasLifetimeAccess = hasLifetime
            hasPackAccess = hasPack
            hasPremiumAccess = hasPremium
            hasProAccess = hasPro
            
            // Get all active subscriptions and entitlements for debugging
            let allActiveSubscriptions = customerInfo.activeSubscriptions
            let allEntitlements = customerInfo.entitlements.all.keys
            print("🔍 SecurePurchaseManager: All active subscriptions: \(allActiveSubscriptions)")
            print("🔍 SecurePurchaseManager: All entitlements: \(allEntitlements)")
            
            // Check if user has any valid subscription OR entitlement
            let hasValidSubscription = hasLifetime || hasPack || hasPremium || hasPro
            print("🔍 SecurePurchaseManager: Final validation result: \(hasValidSubscription)")
            
            return hasValidSubscription
        } catch {
            print("❌ SecurePurchaseManager: RevenueCat validation failed: \(error)")
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
            print("❌ Failed to save purchase data to Keychain: \(error)")
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
            
            print("✅ Loaded secure purchase data")
        } catch {
            print("ℹ️ No existing purchase data found, starting fresh")
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
        if Config.isDebugMode {
            print("📊 Usage tracked on server for \(origin.displayName)")
        }
    }
    
    /// Track purchase on server (placeholder for production)
    private func trackPurchaseOnServer(plan: AffirmationPlan) async {
        // TODO: Implement server-side purchase tracking
        if Config.isDebugMode {
            print("💰 Purchase tracked on server for \(plan.title)")
        }
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
