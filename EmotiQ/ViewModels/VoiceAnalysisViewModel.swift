//
//  VoiceAnalysisViewModel.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

// MARK: - Voice Analysis View Model
@MainActor
class VoiceAnalysisViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var analysisResult: EmotionAnalysisResult?
    @Published var showingLimitAlert = false
    @Published var showingErrorAlert = false
    @Published var errorMessage = ""
    @Published var dailyUsageCount = 0
    @Published var canRecord = true
    @Published var showingAnalysisResult = false
    
    // MARK: - Constants
    let dailyUsageLimit = 3 // Free tier limit
    private let maxRecordingDuration: TimeInterval = 120 // 2 minutes
    
    // MARK: - Services
    private let audioProcessingService = AudioProcessingService()
    private let emotionService = CoreMLEmotionService.shared
    private let subscriptionService = SubscriptionService.shared
    private let persistenceController = PersistenceController.shared
    
    // MARK: - Private Properties
    private var recordingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var currentRecordingURL: URL?
    
    // MARK: - Initialization
    init() {
        setupSubscriptions()
        checkDailyUsage()
        print("🎯 VoiceAnalysisViewModel initialized")
    }
    
    // MARK: - Public Methods
    
    /// Starts voice recording with real-time monitoring
    func startRecording() async {
        print("🎤 Starting voice recording...")
        
        guard canRecord else {
            showingLimitAlert = true
            return
        }
        
        do {
            // Start recording
            currentRecordingURL = try await audioProcessingService.startRecording()
            
            // Update UI state
            isRecording = true
            recordingDuration = 0
            audioLevel = 0
            
            // Start recording timer
            startRecordingTimer()
            
            print("✅ Recording started successfully")
            
        } catch {
            print("❌ Failed to start recording: \(error)")
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    /// Stops recording and analyzes emotion
    func stopRecording() async {
        print("⏹️ Stopping recording and analyzing emotion...")
        
        guard isRecording else { return }
        
        // Update UI state
        isRecording = false
        isProcessing = true
        stopRecordingTimer()
        
        do {
            // Stop recording and get URL
            let recordingURL = try await audioProcessingService.stopRecording()
            print("📁 Recording saved to: \(recordingURL.lastPathComponent)")
            
            // Analyze emotion using CoreML
            print("🧠 Starting emotion analysis...")
            let result = try await emotionService.analyzeEmotion(from: recordingURL)
            print("✅ Emotion analysis completed: \(result.primaryEmotion)")
            
            // Update daily usage IMMEDIATELY
            await updateDailyUsage()
            
                    // Save emotional data to Core Data
        await saveEmotionalData(result)
        
        // Notify other components that new emotional data was saved
        NotificationCenter.default.post(name: .emotionalDataSaved, object: result)
        
        // Update UI with results
        analysisResult = result
        showingAnalysisResult = true
            
            print("🎉 Voice analysis completed successfully")
            
        } catch {
            print("❌ Voice analysis failed: \(error)")
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
        
        isProcessing = false
    }
    
    /// Cancels current recording
    func cancelRecording() {
        print("❌ Cancelling recording...")
        
        guard isRecording else { return }
        
        isRecording = false
        audioProcessingService.cancelRecording()
        stopRecordingTimer()
        
        recordingDuration = 0
        audioLevel = 0
        currentRecordingURL = nil
        
        print("✅ Recording cancelled")
    }
    
    /// Refreshes daily usage count
    func checkDailyUsage() {
        dailyUsageCount = subscriptionService.dailyUsage
        updateCanRecord()
        print("📊 Current daily usage: \(dailyUsageCount)/\(dailyUsageLimit)")
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Monitor audio levels from recording service
        audioProcessingService.audioLevels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        // Monitor subscription status changes
        subscriptionService.currentSubscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCanRecord()
            }
            .store(in: &cancellables)
        
        // Monitor daily usage changes from subscription service
        subscriptionService.$dailyUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newCount in
                self?.dailyUsageCount = newCount
                self?.updateCanRecord()
                print("📊 Daily usage updated: \(newCount)")
            }
            .store(in: &cancellables)
    }
    
    private func updateCanRecord() {
        let hasSubscription = subscriptionService.hasActiveSubscription
        let withinLimit = dailyUsageCount < dailyUsageLimit
        canRecord = hasSubscription || withinLimit
        
        print("🎯 Can record: \(canRecord) (subscription: \(hasSubscription), usage: \(dailyUsageCount)/\(dailyUsageLimit))")
    }
    
    private func updateDailyUsage() async {
        // Increment usage in subscription service
        await subscriptionService.incrementDailyUsage()
        
        // Force immediate UI update
        dailyUsageCount = subscriptionService.dailyUsage
        updateCanRecord()
        
        print("📈 Daily usage incremented to: \(dailyUsageCount)")
    }
    
    private func saveEmotionalData(_ result: EmotionAnalysisResult) async {
        // Get or create user
        let user = persistenceController.createUserIfNeeded()
        
        // Convert EmotionCategory to EmotionType
        let emotionType = EmotionType(rawValue: result.primaryEmotion.rawValue) ?? .neutral
        
        // Convert EmotionIntensity to Double
        let intensityValue = result.intensity.threshold
        
        // Enhanced conversion: Convert ProductionAudioFeatures to VoiceFeatures with complete data preservation
        let voiceFeatures: VoiceFeatures?
        if let audioFeatures = result.audioFeatures {
            // Use the enhanced conversion method for complete data preservation
            voiceFeatures = VoiceFeatures.fromProductionFeatures(audioFeatures)
            
            // Log the enhanced features for debugging
            print("🎯 Enhanced VoiceFeatures created:")
            print("   - Core features: pitch=\(voiceFeatures!.pitch), energy=\(voiceFeatures!.energy)")
            print("   - Enhanced features: \(voiceFeatures!.featureSummary)")
            print("   - Total features: \(voiceFeatures!.featureCount)")
        } else {
            voiceFeatures = nil
            print("⚠️ No audio features available for conversion")
        }
        
        // Convert EmotionAnalysisResult to EmotionalData
        let emotionalData = EmotionalData(
            timestamp: result.timestamp,
            primaryEmotion: emotionType,
            confidence: result.confidence,
            intensity: intensityValue,
            voiceFeatures: voiceFeatures
        )
        
        // Save to Core Data
        persistenceController.saveEmotionalData(emotionalData, for: user)
        
        print("💾 Enhanced emotional data saved to Core Data: \(result.primaryEmotion.displayName)")
        if let features = voiceFeatures {
            print("📊 Data preservation: \(features.hasEnhancedFeatures ? "Enhanced" : "Basic") features (\(features.featureCount) total)")
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.recordingDuration += 0.1
                
                // Auto-stop after max duration
                if self.recordingDuration >= self.maxRecordingDuration {
                    await self.stopRecording()
                }
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Computed Properties
    
    var progressPercentage: Double {
        guard dailyUsageLimit > 0 else { return 0 }
        return min(Double(dailyUsageCount) / Double(dailyUsageLimit), 1.0)
    }
    
    var usageText: String {
        if subscriptionService.hasActiveSubscription {
            return "Unlimited"
        } else {
            return "\(dailyUsageCount)/\(dailyUsageLimit)"
        }
    }
    
    var recordingTimeText: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var canStartRecording: Bool {
        return !isRecording && !isProcessing && canRecord
    }
    
    var recordButtonText: String {
        if isProcessing {
            return "Analyzing..."
        } else if isRecording {
            return "Stop Analysis"
        } else if !canRecord {
            return "Daily Limit Reached"
        } else {
            return "Start Analysis"
        }
    }
    
    var recordButtonColor: Color {
        if isProcessing {
            return .gray
        } else if isRecording {
            return .red
        } else if !canRecord {
            return .gray
        } else {
            return .purple
        }
    }
}

// MARK: - Helper Extensions
extension VoiceAnalysisViewModel {
    
    /// Formats duration for display
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Gets usage status text with color
    func getUsageStatusText() -> (text: String, color: Color) {
        if subscriptionService.hasActiveSubscription {
            return ("Unlimited Access", .green)
        } else if dailyUsageCount >= dailyUsageLimit {
            return ("Daily Limit Reached", .red)
        } else {
            let remaining = dailyUsageLimit - dailyUsageCount
            return ("\(remaining) analyses remaining", .blue)
        }
    }
    
    /// Gets audio level for visualization (0-1 range)
    func getNormalizedAudioLevel() -> Float {
        return min(max(audioLevel, 0), 1)
    }
}
