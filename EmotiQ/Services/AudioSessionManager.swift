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
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    // Check if we need to reconfigure
                    let currentConfig = self.currentConfiguration
                    
                    if currentConfig == configuration {
                        continuation.resume()
                        return
                    }
                    
                    // Deactivate current session first
        
                    try self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
             
                    
                    // Configure for new purpose
                   
                    try self.audioSession.setCategory(configuration.category, mode: configuration.mode, options: configuration.options)

                    try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
             
                    
                    // Update current configuration
                    self.currentConfiguration = configuration
                    
                    continuation.resume()
                    
                } catch {

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
                    
         
                    continuation.resume()
                } catch {
                 
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
            break
        case .ended:
            break
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
