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
    @Published var audioLevelsArray: [Float] = Array(repeating: 0.0, count: 20)
    @Published var analysisResult: EmotionAnalysisResult?
    @Published var showingLimitAlert = false
    @Published var showingErrorAlert = false
    @Published var errorMessage = ""
    @Published var dailyUsageCount = 0
    @Published var weeklyUsageCount = 0
    @Published var canRecord = true
    @Published var showingAnalysisResult = false
    
    // MARK: - Constants
    let dailyUsageLimit = 6 // Free tier limit (legacy)
    let weeklyUsageLimit = 6 // Free tier limit (new)
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
    }
    
    // Test function - add to VoiceAnalysisViewModel
    func testEmotionCampaign() {
        let testResult = EmotionAnalysisResult(
            primaryEmotion: .anger, // Test with anger for immediate trigger
            subEmotion: .confusion, // Default sub-emotion
            intensity: .high,
            confidence: 0.95, // High confidence to trigger campaign
            emotionScores: [.anger: 0.95, .sadness: 0.02, .fear: 0.01, .joy: 0.01, .surprise: 0.01],
            subEmotionScores: [SubEmotion.apprehension: 0.95, SubEmotion.distaste: 0.03, SubEmotion.disappointment: 0.02],
            audioQuality: .good,
            sessionDuration: 5.0,
            audioFeatures: nil
        )
        
        // Post notification to trigger campaign
        NotificationCenter.default.post(
            name: .emotionalDataSaved,
            object: testResult
        )
        
       
    }
    
    // Test predictive intervention
    func testPredictiveCampaign() async {
        let predictions = await EmotionalInterventionPredictor().predictFutureEmotionalNeeds(
            currentEmotion: .neutral,
            confidence: 0.8,
            timeOfDay: Calendar.current.component(.hour, from: Date()),
            dayOfWeek: Calendar.current.component(.weekday, from: Date())
        )
        
        
        
        // This should schedule notifications for predicted emotional needs
    }
    
    // Test achievement celebration
    func testAchievementCampaign() {
        let testAchievement = Achievement(
            id: "test_achievement",
            title: "First Voice Analysis",
            description: "You completed your first emotional voice analysis!",
            type: .milestone
        )
        
        NotificationCenter.default.post(
            name: .achievementUnlocked,
            object: testAchievement
        )
        
   
    }
    
    // Removed test method that was causing duplicate notifications
    


    
    // MARK: - Public Methods
    
    /// Starts voice recording with real-time monitoring
    func startRecording() async {

        
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
            
        
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    /// Stops recording and analyzes emotion
    func stopRecording() async {
      
        
        guard isRecording else { return }
        
        // Update UI state
        isRecording = false
        isProcessing = true
        stopRecordingTimer()
        
        do {
            // Stop recording and get URL
            let recordingURL = try await audioProcessingService.stopRecording()
       
            
            // Analyze emotion using CoreML
           
            let result = try await emotionService.analyzeEmotion(from: recordingURL)
   
            
            // Update daily usage IMMEDIATELY
            await updateDailyUsage()
            
                    // Save emotional data to Core Data
        await saveEmotionalData(result)
        
        // Notify other components that new emotional data was saved
        NotificationCenter.default.post(name: .emotionalDataSaved, object: result)
        
        // Update UI with results
        analysisResult = result
        showingAnalysisResult = true
            
            
        } catch {
 
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
        
        isProcessing = false
    }
    
    /// Cancels current recording
    func cancelRecording() {
     
        
        guard isRecording else { return }
        
        isRecording = false
        audioProcessingService.cancelRecording()
        stopRecordingTimer()
        
        recordingDuration = 0
        audioLevel = 0
        currentRecordingURL = nil
        
    
    }
    
    /// Refreshes daily and weekly usage count
    func checkDailyUsage() {
     
        
        // First refresh the subscription service to check for daily and weekly reset

        subscriptionService.refreshDailyUsage()
        
        subscriptionService.refreshWeeklyUsage()
        
        // Then update our local state
        dailyUsageCount = subscriptionService.dailyUsage
        weeklyUsageCount = subscriptionService.weeklyUsage

        updateCanRecord()

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
        
        // Monitor audio levels array for animated bars
        audioProcessingService.audioLevelsArrayPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] levels in
                self?.audioLevelsArray = levels
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
            
            }
            .store(in: &cancellables)
        
        // Monitor weekly usage changes from subscription service
        subscriptionService.$weeklyUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newCount in
                self?.weeklyUsageCount = newCount
                self?.updateCanRecord()
           
            }
            .store(in: &cancellables)
        
        // Monitor daily usage reset notifications
        NotificationCenter.default.publisher(for: .dailyUsageReset)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkDailyUsage()
       
                
                // CRITICAL FIX: Reset audio session state after daily usage reset
                // This prevents the "Failed to record audio" error that occurs
                // when the audio session gets corrupted during daily reset
                Task {
                    await self?.resetAudioSessionAfterDailyReset()
                }
            }
            .store(in: &cancellables)
        
        // Monitor weekly usage reset notifications
        NotificationCenter.default.publisher(for: .weeklyUsageReset)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkDailyUsage()
             
                
                // CRITICAL FIX: Reset audio session state after weekly usage reset
                // This prevents the "Failed to record audio" error that occurs
                // when the audio session gets corrupted during weekly reset
                Task {
                    await self?.resetAudioSessionAfterDailyReset()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateCanRecord() {
        let hasSubscription = subscriptionService.hasActiveSubscription
        let withinWeeklyLimit = weeklyUsageCount < weeklyUsageLimit
        canRecord = hasSubscription || withinWeeklyLimit
        
    }
    
    private func updateDailyUsage() async {
        // Increment usage in subscription service
        await subscriptionService.incrementDailyUsage()
        
        // Force immediate UI update
        dailyUsageCount = subscriptionService.dailyUsage
        weeklyUsageCount = subscriptionService.weeklyUsage
        updateCanRecord()
        
    }
    
    /// Resets audio session state after daily usage reset to prevent recording errors
    private func resetAudioSessionAfterDailyReset() async {
    
        
        do {
            // Deactivate current audio session to clear any corrupted state
            try await AudioSessionManager.shared.deactivateAudioSession()
    
            
            // Small delay to ensure clean state
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Reconfigure audio session for recording
            try await AudioSessionManager.shared.configureAudioSession(for: .recording)
       
            
         
            
        } catch {
          
        }
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

        } else {
            voiceFeatures = nil
          
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
        
    
        if let features = voiceFeatures {

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
        let normalized = min(max(audioLevel, 0), 1)
        return normalized
    }
}
