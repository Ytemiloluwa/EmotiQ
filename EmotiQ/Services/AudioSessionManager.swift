//
//  AudioSessionManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import AVFoundation
import Combine

/// Centralized audio session manager to prevent conflicts between services
class AudioSessionManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AudioSessionManager()
    
    // MARK: - Private Properties
    private let audioSession = AVAudioSession.sharedInstance()
    private var currentConfiguration: AudioSessionConfiguration?
    private let queue = DispatchQueue(label: "com.emotiq.audiosession", qos: .userInitiated)
    
    // MARK: - Audio Session Configuration Types
    enum AudioSessionConfiguration {
        case recording
        case speechRecognition
        case playback
        case analysis
        
        var category: AVAudioSession.Category {
            switch self {
            case .recording, .speechRecognition, .analysis:
                return .playAndRecord
            case .playback:
                return .playback
            }
        }
        
        var mode: AVAudioSession.Mode {
            switch self {
            case .recording, .speechRecognition, .analysis:
                return .measurement
            case .playback:
                return .default
            }
        }
        
        var options: AVAudioSession.CategoryOptions {
            switch self {
            case .recording, .speechRecognition, .analysis:
                return [.defaultToSpeaker, .allowBluetooth]
            case .playback:
                return [.allowBluetooth, .allowBluetoothA2DP]
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Configures audio session for a specific purpose with conflict prevention
    func configureAudioSession(for configuration: AudioSessionConfiguration) async throws {
        print("🔍 DEBUG: AudioSessionManager.configureAudioSession() called for: \(configuration)")
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    // Check if we need to reconfigure
                    let currentConfig = self.currentConfiguration
                    print("🔍 DEBUG: Current audio session config: \(currentConfig?.description ?? "nil")")
                    if currentConfig == configuration {
                        print("🔍 DEBUG: Audio session already configured for \(configuration), skipping reconfiguration")
                        continuation.resume()
                        return
                    }
                    
                    // Deactivate current session first
                    print("🔍 DEBUG: Deactivating current audio session...")
                    try self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                    print("🔍 DEBUG: Audio session deactivated")
                    
                    // Configure for new purpose
                    print("🔍 DEBUG: Setting audio session category: \(configuration.category)")
                    try self.audioSession.setCategory(configuration.category, mode: configuration.mode, options: configuration.options)
                    print("🔍 DEBUG: Audio session category set successfully")
                    
                    print("🔍 DEBUG: Activating audio session...")
                    try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    print("🔍 DEBUG: Audio session activated")
                    
                    // Update current configuration
                    self.currentConfiguration = configuration
                    
                    print("✅ Audio session configured for: \(configuration)")
                    continuation.resume()
                    
                } catch {
                    print("❌ Failed to configure audio session for \(configuration): \(error)")
                    print("🔍 DEBUG: Audio session error type: \(type(of: error))")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Deactivates audio session
    func deactivateAudioSession() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                    
                    // Update current configuration
                    self.currentConfiguration = nil
                    
                    print("✅ Audio session deactivated")
                    continuation.resume()
                } catch {
                    print("❌ Failed to deactivate audio session: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Gets current audio session configuration
    var currentAudioSessionConfiguration: AudioSessionConfiguration? {
        return currentConfiguration
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Handle audio session interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // Handle route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔇 Audio session interruption began")
        case .ended:
            print("🔊 Audio session interruption ended")
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🎧 Audio route changed: \(reason)")
    }
}

// MARK: - Extensions for Better Debugging

extension AudioSessionManager.AudioSessionConfiguration: CustomStringConvertible {
    var description: String {
        switch self {
        case .recording:
            return "Recording"
        case .speechRecognition:
            return "Speech Recognition"
        case .playback:
            return "Playback"
        case .analysis:
            return "Analysis"
        }
    }
}
