//
//  SecurityManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import Security
import LocalAuthentication

class SecurityManager {
    static let shared = SecurityManager()
    
    private let faceIDEnabledKey = Config.Security.faceIDEnabledKey
    private let serviceIdentifier = Config.Security.serviceIdentifier
    
    private init() {}
    
    // MARK: - Face ID Settings (Secure Storage)
    
    func setFaceIDEnabled(_ enabled: Bool) -> Bool {
        let data = Data([enabled ? 1 : 0])
        return saveToKeychain(data: data, key: faceIDEnabledKey)
    }
    
    func isFaceIDEnabled() -> Bool {
        guard let data = loadFromKeychain(key: faceIDEnabledKey),
              let value = data.first else {
            return false
        }
        return value == 1
    }
    
    func clearFaceIDSettings() -> Bool {
        return deleteFromKeychain(key: faceIDEnabledKey)
    }
    
    // MARK: - Biometric Authentication
    
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            throw SecurityError.biometricsNotAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel:
                throw SecurityError.userCancelled
            case .userFallback:
                // User chose to enter device passcode - verify it properly
                return try await authenticateWithDevicePasscode(reason: reason)
            case .authenticationFailed:
                throw SecurityError.authenticationFailed("Biometric authentication failed")
            default:
                throw SecurityError.authenticationFailed(error.localizedDescription)
            }
        } catch {
            throw SecurityError.authenticationFailed(error.localizedDescription)
        }
    }
    
    private func authenticateWithDevicePasscode(reason: String) async throws -> Bool {
        let context = LAContext()
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel:
                throw SecurityError.userCancelled
            case .authenticationFailed:
                throw SecurityError.authenticationFailed("Incorrect passcode")
            default:
                throw SecurityError.authenticationFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Keychain Operations
    
    private func saveToKeychain(data: Data, key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // First, try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Then save the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return data
    }
    
    private func deleteFromKeychain(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // MARK: - Security Validation
    
    func validateSecuritySettings() -> Bool {
        // Verify that Face ID settings are properly stored in Keychain
        return loadFromKeychain(key: faceIDEnabledKey) != nil
    }
    
    func isBiometricAvailable() async -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}

// MARK: - Security Errors

enum SecurityError: LocalizedError {
    case biometricsNotAvailable
    case authenticationFailed(String)
    case userCancelled
    case keychainError
    
    var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .userCancelled:
            return "Authentication was cancelled."
        case .keychainError:
            return "Security settings could not be accessed."
        }
    }
}
