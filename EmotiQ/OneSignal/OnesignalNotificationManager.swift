//
//  OneSignalNotificationManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 25-08-2025.
//

//  Production-ready OneSignal notification manager with emotion-triggered campaigns and haptic integration
//

import Foundation
import OneSignalFramework
import UserNotifications
import Combine
import UIKit

// MARK: - OneSignal Notification Manager
@MainActor
class OneSignalNotificationManager: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = OneSignalNotificationManager()
    
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var notificationPermissionGranted = false
    @Published var userSubscriptionId: String?
    @Published var campaignAnalytics: CampaignAnalytics = CampaignAnalytics()
    @Published var activeCampaigns: [NotificationCampaign] = []
    @Published var showingNotificationSettingsAlert = false
    
    // MARK: - Private Properties
    private let oneSignalService = OneSignalService.shared
    private let behaviorAnalyzer = UserBehaviorAnalyzer()
    private var hasTriggeredWelcomeNotification = false
    private let interventionPredictor = EmotionalInterventionPredictor()
    private let notificationScheduler = SmartNotificationScheduler()
    private let hapticManager = HapticManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Campaign management
    private var emotionTriggeredCampaigns: [String: NotificationCampaign] = [:]
    private var predictiveCampaigns: [String: NotificationCampaign] = [:]
    private var achievementCampaigns: [String: NotificationCampaign] = [:]
    private var goalCompletionCampaigns: [String: NotificationCampaign] = [:]
    
    // MARK: - Configuration
    private struct config {
        static let appid = Config.oneSignalAppID
        static let maxActiveCampaigns = 10
        static let campaignCooldownPeriod: TimeInterval = 3600 // 1 hour
        static let maxDailyCampaigns = 5
        static let emergencyInterventionThreshold: Double = 0.9
        static let highConfidenceThreshold: Double = 0.8
        static let mediumConfidenceThreshold: Double = 0.6
        
    }
    
    // MARK: - Initialization
    private init() {
        setupOneSignalIntegration()
        setupEmotionObservers()
        setupCampaignManagement()
        checkNotificationPermissionOnLaunch()
    }
    
    // MARK: - Permission Management
    private func checkNotificationPermissionOnLaunch() {
        print("🔍 DEBUG: Checking notification permission on launch")
        
        // Don't show dialog immediately on fresh installs
        // Let the subscription state monitoring handle permission detection
        print("🔍 DEBUG: Skipping immediate permission check, will monitor OneSignal state instead")
    }
    
    private func performDelayedPermissionCheck() {
        print("🔍 DEBUG: Performing delayed permission check")
        
        // Force sync permission status
        oneSignalService.forceSyncPermissionStatus()
        
        // Check current permission status - OneSignal.Notifications.permission returns a boolean
        let currentStatus = OneSignal.Notifications.permission
        let subscriptionId = OneSignal.User.pushSubscription.id
        let optedIn = OneSignal.User.pushSubscription.optedIn
        
        print("🔍 DEBUG: Delayed check - OneSignal permission: \(currentStatus)")
        print("🔍 DEBUG: Delayed check - Subscription ID: \(subscriptionId)")
        print("🔍 DEBUG: Delayed check - Opted In: \(optedIn)")
        
        // Update our published property - OneSignal returns true for authorized, false for denied
        notificationPermissionGranted = currentStatus
        
        // Only show alert if permission is actually denied AND OneSignal is ready
        // This prevents showing the dialog on fresh installs before OneSignal is ready
        if oneSignalService.isFreshInstall() || (!currentStatus && !optedIn) {
            print("🔍 DEBUG: Fresh install or OneSignal not ready yet (permission: \(currentStatus), optedIn: \(optedIn)), skipping alert")
            // Don't show alert on fresh installs until OneSignal is fully initialized
        } else if !currentStatus {
            //print("🔍 DEBUG: Permission denied after initialization, showing settings alert")
            showingNotificationSettingsAlert = true
        } else {
            //print("🔍 DEBUG: Permission granted, hiding settings alert")
            showingNotificationSettingsAlert = false
        }
        
        // Force refresh OneSignal subscription status
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshOneSignalSubscription()
        }
    }
    
    private func refreshOneSignalSubscription() {
        print("🔍 DEBUG: Refreshing OneSignal subscription status")
        
        // Force OneSignal to re-evaluate permission and subscription
        OneSignal.Notifications.clearAll()
        
        // Re-request permission to ensure subscription is properly enabled
        OneSignal.Notifications.requestPermission({ accepted in
            print("🔍 DEBUG: Refresh permission result: \(accepted)")
            Task { @MainActor in
                self.notificationPermissionGranted = accepted
                if accepted {
                    self.showingNotificationSettingsAlert = false
                    print("🔍 DEBUG: Subscription refreshed successfully")
                }
            }
        }, fallbackToSettings: false)
    }
    
    // MARK: - Public Methods
    
    func dismissSettingsAlert() {
        print("🔍 DEBUG: Manually dismissing settings alert")
        showingNotificationSettingsAlert = false
    }
    
    func checkCurrentPermissionStatus() {
        let oneSignalPermission = OneSignal.Notifications.permission
        let servicePermission = oneSignalService.notificationPermissionStatus
        
        print("🔍 DEBUG: Current Permission Status:")
        print("  - OneSignal.Notifications.permission: \(oneSignalPermission)")
        print("  - OneSignalService.notificationPermissionStatus: \(servicePermission)")
        print("  - notificationPermissionGranted: \(notificationPermissionGranted)")
        print("  - showingNotificationSettingsAlert: \(showingNotificationSettingsAlert)")
    }
    
    // MARK: - OneSignal Integration Setup
    private func setupOneSignalIntegration() {
        // Observe OneSignal initialization
        oneSignalService.$isInitialized
            .sink { [weak self] isInitialized in
                self?.isInitialized = isInitialized
                if isInitialized {
                    Task { @MainActor in
                        await self?.initializeCampaignSystem()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe permission status
        oneSignalService.$notificationPermissionStatus
            .sink { [weak self] status in
                let isGranted = (status == .authorized)
                self?.notificationPermissionGranted = isGranted
                
                //print("🔍 DEBUG: Permission status changed to: \(status)")
                
                // Only show settings alert if OneSignal is ready but permission is denied
                let subscriptionId = OneSignal.User.pushSubscription.id
                let optedIn = OneSignal.User.pushSubscription.optedIn
                
                if isGranted {
                    //print("🔍 DEBUG: Permission granted, hiding settings alert")
                    self?.showingNotificationSettingsAlert = false
                } else if !(subscriptionId?.isEmpty ?? true) && !optedIn {
                    // OneSignal is ready but user hasn't opted in
                    print("🔍 DEBUG: OneSignal ready but user not opted in, showing settings alert")
                    self?.showingNotificationSettingsAlert = true
                } else {
                    // OneSignal not ready yet, don't show alert
                    print("🔍 DEBUG: OneSignal not ready yet (subscriptionId: \(subscriptionId), optedIn: \(optedIn)), skipping alert")
                }
            }
            .store(in: &cancellables)
        
        // Observe user subscription
        oneSignalService.$userSubscriptionId
            .sink { [weak self] subscriptionId in
                self?.userSubscriptionId = subscriptionId
                if subscriptionId != nil {
                    Task { @MainActor in
                        await self?.setupUserSegmentation()
                    }
                    
                    // When we get a subscription ID, it means OneSignal is ready
                    // Perform the delayed permission check
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.performDelayedPermissionCheck()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor OneSignal subscription status changes (reduced frequency to prevent duplicates)
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                let optedIn = OneSignal.User.pushSubscription.optedIn
                let permission = OneSignal.Notifications.permission
                let subscriptionId = OneSignal.User.pushSubscription.id
                
                // Check if OneSignal is now ready (has subscription ID and opted in)
                if !(subscriptionId?.isEmpty ?? true) && optedIn && permission {
                    // Update permission status and hide dialog
                    DispatchQueue.main.async {
                        self?.oneSignalService.notificationPermissionStatus = .authorized
                        self?.notificationPermissionGranted = true
                        self?.showingNotificationSettingsAlert = false
                        
                        // Trigger user setup and welcome notification only once
                        if !(self?.hasTriggeredWelcomeNotification ?? false) {
                            self?.hasTriggeredWelcomeNotification = true
                            self?.oneSignalService.setupUserTags()
                            self?.oneSignalService.scheduleInitialWelcomeNotification()
                        }
                    }
                } else if !(subscriptionId?.isEmpty ?? true) && !optedIn {
                    // OneSignal is ready but user hasn't opted in - show settings alert
                    DispatchQueue.main.async {
                        self?.showingNotificationSettingsAlert = true
                    }
                    
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupEmotionObservers() {
        // Observe emotion analysis results for immediate campaigns
        NotificationCenter.default.publisher(for: .emotionalDataSaved)
            .compactMap { $0.object as? EmotionAnalysisResult }
            .sink { [weak self] result in
                Task { @MainActor in
                    await self?.processEmotionForCampaigns(result)
                }
            }
            .store(in: &cancellables)
        
        // Observe intervention completions for follow-up campaigns
        NotificationCenter.default.publisher(for: .notificationInterventionCompleted)
            .compactMap { $0.object as? NotificationIntervention }
            .sink { [weak self] intervention in
                Task { @MainActor in
                    await self?.processInterventionCompletion(intervention)
                }
            }
            .store(in: &cancellables)
        
        // Observe achievement unlocks for celebration campaigns
        NotificationCenter.default.publisher(for: .achievementUnlocked)
            .compactMap { $0.object as? Achievement }
            .sink { [weak self] achievement in
                Task { @MainActor in
                    await self?.createAchievementCelebrationCampaign(achievement)
                }
            }
            .store(in: &cancellables)
        
        // Observe goal completion for celebration campaigns
        NotificationCenter.default.publisher(for: .goalCompleted)
            .compactMap { $0.object as? GoalEntity }
            .sink { [weak self] goal in
                Task { @MainActor in
                    await self?.createGoalCompletionCelebrationCampaign(goal)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupCampaignManagement() {
        // Periodic campaign optimization
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                await self.optimizeCampaignPerformance()
            }
        }
        
        // Daily campaign cleanup
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task { @MainActor in
                await self.cleanupExpiredCampaigns()
            }
        }
    }
    
    // MARK: - Campaign Initialization
    private var hasInitializedCampaigns = false
    
    private func initializeCampaignSystem() async {
        // Prevent multiple initializations
        guard !hasInitializedCampaigns else {
            print("🔍 Campaign system already initialized, skipping...")
            return
        }
        
        hasInitializedCampaigns = true
        
        // Create base emotion-triggered campaigns
        await createEmotionTriggeredCampaigns()
        
        // Set up predictive intervention campaigns
        await setupPredictiveCampaigns()
        
        // Initialize daily check-in campaigns
        await setupDailyCheckInCampaigns()
        
        // Set up re-engagement campaigns
        await setupReEngagementCampaigns()
        
        print("✅ OneSignal campaign system initialized")
    }
    
    private func setupUserSegmentation() async {
        // Set up user tags for advanced segmentation
        let behaviorPattern = await behaviorAnalyzer.getCurrentBehaviorPattern()
        let emotionalPatterns = behaviorAnalyzer.emotionalPatterns
        
        OneSignal.User.addTags([
            // Behavioral segmentation
            "avg_daily_sessions": String(behaviorPattern.sessionPatterns.sessionsPerDay),
            "peak_usage_hours": behaviorPattern.averageAppUsageHours.map(String.init).joined(separator: ","),
            "emotional_stability": String(format: "%.2f", emotionalPatterns.stability),
            "engagement_score": String(format: "%.2f", behaviorPattern.engagementHistory.last ?? 0.5),
            
            // Preference segmentation
            "preferred_interventions": behaviorPattern.preferredInterventionTypes.map { $0.rawValue }.joined(separator: ","),
            "optimal_intervention_times": behaviorPattern.emotionalPeakTimes.map(String.init).joined(separator: ","),
            
            // Emotional pattern segmentation
            "emotional_volatility": emotionalPatterns.transitions.count > 5 ? "high" : "low",
            "stress_prone": behaviorPattern.emotionalPeakTimes.count > 3 ? "true" : "false",
            
            // Subscription status
            "subscription_tier": "premium", // Will be updated based on actual subscription
            "voice_features_enabled": "true",
            "notification_preferences": "emotion_aware"
        ])
    }
    
    // MARK: - Emotion-Triggered Campaigns
    private func createEmotionTriggeredCampaigns() async {
        for emotion in EmotionType.allCases {
            let campaign = await createEmotionSpecificCampaign(for: emotion)
            emotionTriggeredCampaigns[emotion.rawValue] = campaign
            activeCampaigns.append(campaign)
        }
    }
    
    private func createEmotionSpecificCampaign(for emotion: EmotionType) async -> NotificationCampaign {
        let interventions = getOptimalInterventions(for: emotion)
        let content = generateEmotionCampaignContent(emotion: emotion, interventions: interventions)
        
        return NotificationCampaign(
            id: "emotion_\(emotion.rawValue)_\(UUID().uuidString)",
            name: "\(emotion.displayName) Support Campaign",
            type: .emotionTriggered,
            targetEmotion: emotion,
            content: content,
            triggers: createEmotionTriggers(for: emotion),
            segmentation: createEmotionSegmentation(for: emotion),
            schedule: createEmotionSchedule(for: emotion),
            analytics: CampaignAnalytics(),
            isActive: true,
            createdAt: Date()
        )
    }
    
    private func processEmotionForCampaigns(_ result: EmotionAnalysisResult) async {
        // Check if emotion requires immediate intervention
        if shouldTriggerImmediateCampaign(for: result) {
            await triggerImmediateEmotionCampaign(result)
        }
        
        // Update predictive campaigns based on new emotion data
        await updatePredictiveCampaigns(basedOn: result)
        
        // Track emotion for campaign optimization
        await trackEmotionForOptimization(result)
    }
    
    private func shouldTriggerImmediateCampaign(for result: EmotionAnalysisResult) -> Bool {
        // High-confidence negative emotions or emergency situations
        let emergencyEmotions: Set<EmotionType> = [.anger, .fear, .sadness]
        
        if emergencyEmotions.contains(convertEmotionCategoryToType(result.primaryEmotion)) {
            return result.confidence >= config.emergencyInterventionThreshold
        }
        
        // High-confidence positive emotions for amplification
        if result.primaryEmotion == .joy {
            return result.confidence >= config.highConfidenceThreshold
        }
        
        return false
    }
    
    private func triggerImmediateEmotionCampaign(_ result: EmotionAnalysisResult) async {
        guard let campaign = emotionTriggeredCampaigns[result.primaryEmotion.rawValue] else { return }
        
        // Check campaign cooldown
        if await isCampaignInCooldown(campaign) { return }
        
        // Personalize content based on user behavior
        let personalizedContent = await personalizeContent(
            campaign.content,
            for: result,
            userBehavior: await behaviorAnalyzer.getCurrentBehaviorPattern()
        )
        
        // Send immediate notification
        await sendCampaignNotification(
            campaign: campaign,
            content: personalizedContent,
            priority: .high,
            delay: 0
        )
        
        // Trigger appropriate haptic feedback
        hapticManager.emotionalFeedback(for: convertEmotionCategoryToType(result.primaryEmotion))
        
        // Update campaign analytics
        campaign.analytics.incrementCampaignsTriggered()
        campaign.lastTriggered = Date()
        
        print("🚀 Triggered immediate emotion campaign for \(result.primaryEmotion.displayName)")
    }
    
    // MARK: - Predictive Campaigns
    private func setupPredictiveCampaigns() async {
        // Create campaigns based on predicted emotional needs
        let predictions = await interventionPredictor.predictFutureEmotionalNeeds(
            currentEmotion: .neutral,
            confidence: 0.7,
            timeOfDay: Calendar.current.component(.hour, from: Date()),
            dayOfWeek: Calendar.current.component(.weekday, from: Date())
        )
        
        for prediction in predictions {
            let campaign = await createPredictiveCampaign(for: prediction)
            predictiveCampaigns[prediction.predictedEmotion.rawValue] = campaign
            activeCampaigns.append(campaign)
        }
    }
    
    private func createPredictiveCampaign(for prediction: EmotionalPrediction) async -> NotificationCampaign {
        let content = generatePredictiveCampaignContent(prediction: prediction)
        
        return NotificationCampaign(
            id: "predictive_\(prediction.predictedEmotion.rawValue)_\(UUID().uuidString)",
            name: "Predictive \(prediction.predictedEmotion.displayName) Support",
            type: .predictiveIntervention,
            targetEmotion: prediction.predictedEmotion,
            content: content,
            triggers: createPredictiveTriggers(for: prediction),
            segmentation: createPredictiveSegmentation(for: prediction),
            schedule: createPredictiveSchedule(for: prediction),
            analytics: CampaignAnalytics(),
            isActive: true,
            createdAt: Date()
        )
    }
    
    private func updatePredictiveCampaigns(basedOn result: EmotionAnalysisResult) async {
        // Update ML models with new emotion data
        await interventionPredictor.updateWithEmotionData(result)
        
        // Generate new predictions
        let newPredictions = await interventionPredictor.predictFutureEmotionalNeeds(
            currentEmotion: convertEmotionCategoryToType(result.primaryEmotion),
            confidence: result.confidence,
            timeOfDay: Calendar.current.component(.hour, from: Date()),
            dayOfWeek: Calendar.current.component(.weekday, from: Date())
        )
        
        // Schedule predictive interventions
        for prediction in newPredictions {
            await schedulePredictiveIntervention(prediction)
        }
    }
    
    private func schedulePredictiveIntervention(_ prediction: EmotionalPrediction) async {
        let campaign = NotificationCampaign(
            id: "scheduled_predictive_\(UUID().uuidString)",
            name: "Scheduled \(prediction.predictedEmotion.displayName) Prevention",
            type: .predictiveIntervention,
            targetEmotion: prediction.predictedEmotion,
            content: generatePredictiveCampaignContent(prediction: prediction),
            triggers: [],
            segmentation: [:],
            schedule: CampaignSchedule(
                scheduledTime: prediction.optimalTime,
                repeatInterval: nil,
                timeZone: TimeZone.current
            ),
            analytics: CampaignAnalytics(),
            isActive: true,
            createdAt: Date()
        )
        
        await notificationScheduler.schedulePredictiveIntervention(prediction: prediction)
        activeCampaigns.append(campaign)
        
        print("📅 Scheduled predictive intervention for \(prediction.predictedEmotion.displayName) at \(prediction.optimalTime)")
    }
    
    // MARK: - Achievement Campaigns
    private func createAchievementCelebrationCampaign(_ achievement: Achievement) async {
        let campaign = NotificationCampaign(
            id: "achievement_\(achievement.id)",
            name: "Achievement: \(achievement.title)",
            type: .achievement,
            targetEmotion: .joy,
            content: generateAchievementCampaignContent(achievement: achievement),
            triggers: [],
            segmentation: [:],
            schedule: CampaignSchedule(
                scheduledTime: Date().addingTimeInterval(300), // 5 minutes delay
                repeatInterval: nil,
                timeZone: TimeZone.current
            ),
            analytics: CampaignAnalytics(),
            isActive: true,
            createdAt: Date()
        )
        
        achievementCampaigns[achievement.id] = campaign
        activeCampaigns.append(campaign)
        
        await notificationScheduler.scheduleAchievementCelebration(achievement: achievement)
        
        // Trigger celebration haptic immediately
        hapticManager.celebration(.goalCompleted)
        
        print("🎉 Created achievement celebration campaign for: \(achievement.title)")
    }
    
    // MARK: - Goal Completion Campaigns
    private func createGoalCompletionCelebrationCampaign(_ goal: GoalEntity) async {
        let campaign = NotificationCampaign(
            id: "goal_\(goal.id?.uuidString ?? UUID().uuidString)",
            name: "Goal Completed: \(goal.title ?? "Unknown Goal")",
            type: .achievement, // Reuse achievement type for goal completion
            targetEmotion: .joy,
            content: generateGoalCompletionCampaignContent(goal: goal),
            triggers: [],
            segmentation: [:],
            schedule: CampaignSchedule(
                scheduledTime: Date().addingTimeInterval(30), // 30 seconds delay
                repeatInterval: nil,
                timeZone: TimeZone.current
            ),
            analytics: CampaignAnalytics(),
            isActive: true,
            createdAt: Date()
        )
        
        goalCompletionCampaigns[goal.id?.uuidString ?? UUID().uuidString] = campaign
        activeCampaigns.append(campaign)
        
        await notificationScheduler.scheduleGoalCompletionCelebration(goal: goal)
        
        // Trigger celebration haptic immediately
        hapticManager.celebration(.goalCompleted)
        
        print("🎯 Created goal completion celebration campaign for: \(goal.title ?? "Unknown Goal")")
        print("🔍 DEBUG: Goal completion notification will be sent in 30 seconds")
        print("🔍 DEBUG: Goal ID: \(goal.id?.uuidString ?? "Unknown")")
        print("🔍 DEBUG: Goal Category: \(goal.category ?? "Unknown")")
    }
    
    // MARK: - Daily Check-in Campaigns
    private func setupDailyCheckInCampaigns() async {
        let behaviorPattern = await behaviorAnalyzer.getCurrentBehaviorPattern()
        let optimalTime = findOptimalCheckInTime(from: behaviorPattern)
        
        let campaign = NotificationCampaign(
            id: "daily_checkin_\(UUID().uuidString)",
            name: "Daily Emotional Check-in",
            type: .dailyCheckIn,
            targetEmotion: .neutral,
            content: CampaignContent(
                title: "🌅 Daily Check-in",
                body: "Time for your emotional wellness check-in",
                actionButtons: [
                    CampaignActionButton(
                        id: "quick_checkin",
                        text: "Quick Check-in",
                        action: .openScreen(.quickCheckIn)
                    ),
                    CampaignActionButton(
                        id: "voice_analysis",
                        text: "Voice Analysis",
                        action: .openScreen(.voiceAnalysis)
                    )
                ],
                customData: [
                    "campaign_type": "daily_checkin",
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ],
                richMedia: nil
            ),
            triggers: createDailyCheckInTriggers(),
            segmentation: createDailyCheckInSegmentation(),
            schedule: CampaignSchedule(
                scheduledTime: optimalTime,
                repeatInterval: 86400, // Daily
                timeZone: TimeZone.current
            ),
            analytics: CampaignAnalytics(),
            isActive: true,
            createdAt: Date()
        )
        
        activeCampaigns.append(campaign)
        await notificationScheduler.scheduleDailyCheckIn()
        
        print("📅 Set up daily check-in campaign for \(optimalTime)")
    }
    
    // MARK: - Re-engagement Campaigns
    private func setupReEngagementCampaigns() async {
        // Create campaigns for users who haven't engaged recently
        let reEngagementCampaign = NotificationCampaign(
            id: "reengagement_\(UUID().uuidString)",
            name: "Re-engagement Campaign",
            type: .reEngagement,
            targetEmotion: .neutral,
            content: generateReEngagementContent(),
            triggers: createReEngagementTriggers(),
            segmentation: createReEngagementSegmentation(),
            schedule: CampaignSchedule(
                scheduledTime: Date().addingTimeInterval(86400 * 3), // 3 days
                repeatInterval: 86400 * 7, // Weekly
                timeZone: TimeZone.current
            ),
            analytics: CampaignAnalytics(),
            isActive: true,
            createdAt: Date()
        )
        
        activeCampaigns.append(reEngagementCampaign)
        print("🔄 Set up re-engagement campaign")
    }
    
    private func getRichMediaForEmotion(_ emotion: EmotionType) -> CampaignRichMedia? {
        let imageURL: String
        let soundName: String
        
        switch emotion {
        case .joy:
            imageURL = "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f60a.png" // 😊
            soundName = "default" // Use iOS default sound
        case .sadness:
            imageURL = "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f622.png" // 😢
            soundName = "default"
        case .anger:
            imageURL = "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f621.png" // 😡
            soundName = "default"
        case .fear:
            imageURL = "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f628.png" // 😨
            soundName = "default"
        case .surprise:
            imageURL = "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f632.png" // 😲
            soundName = "default"
        case .disgust:
            imageURL = "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f922.png" // 🤢
            soundName = "default"
        case .neutral:
            imageURL = "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f610.png" // 😐
            soundName = "default"
        }
        
        return CampaignRichMedia(
            imageURL: imageURL,
            videoURL: nil,
            soundName: soundName
        )
    }
    
    private func getAchievementImageURL(_ achievement: Achievement) -> String {
        switch achievement.type {
        case .dailyGoal:
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f3c6.png" // 🏆
        case .weeklyGoal:
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f947.png" // 🥇
        case .streak:
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f525.png" // 🔥
        case .milestone:
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/2b50.png" // ⭐
        }
    }
    
    private func getGoalCompletionImageURL(goalCategory: String) -> String {
        switch goalCategory.lowercased() {
        case "emotional_awareness":
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f60a.png" // 😊
        case "stress_management":
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f4aa.png" // 💪
        case "relationships":
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f91d.png" // 🤝
        case "self_compassion":
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f496.png" // 💖
        case "mindfulness":
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f4ab.png" // 💫
        case "communication":
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f4ac.png" // 💬
        case "resilience":
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f6e1.png" // 🛡️
        case "happiness":
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f31e.png" // 🌞
        default:
            return "https://twemoji.maxcdn.com/v/14.0.2/72x72/1f3c6.png" // 🏆
        }
    }
    
    // MARK: - Content Generation
    private func generateEmotionCampaignContent(emotion: EmotionType, interventions: [OneSignaInterventionType]) -> CampaignContent {
        let (title, body) = getEmotionSpecificContent(emotion: emotion)
        let actionButtons = interventions.map { intervention in
            CampaignActionButton(
                id: intervention.rawValue,
                text: getInterventionButtonText(intervention),
                action: .openIntervention(intervention)
            )
        }
        
        return CampaignContent(
            title: title,
            body: body,
            actionButtons: actionButtons,
            customData: [
                "emotion": emotion.rawValue,
                "campaign_type": "emotion_triggered",
                "interventions": interventions.map { $0.rawValue }.joined(separator: ",")
            ],
            richMedia: getRichMediaForEmotion(emotion)
        )
    }
    
    private func generatePredictiveCampaignContent(prediction: EmotionalPrediction) -> CampaignContent {
        let confidenceText = prediction.confidence > 0.8 ? "highly likely" : "might"
        let title = "🔮 Proactive Emotional Support"
        let body = "Based on your patterns, you \(confidenceText) benefit from some \(prediction.predictedEmotion.displayName.lowercased()) support soon."
        
        return CampaignContent(
            title: title,
            body: body,
            actionButtons: [
                CampaignActionButton(
                    id: "start_intervention",
                    text: "Start Session",
                    action: .openIntervention(prediction.recommendedIntervention)
                ),
                CampaignActionButton(
                    id: "remind_later",
                    text: "Remind Later",
                    action: .remindLater(3600)
                )
            ],
            customData: [
                "predicted_emotion": prediction.predictedEmotion.rawValue,
                "confidence": String(prediction.confidence),
                "campaign_type": "predictive"
            ],
            richMedia: nil
        )
    }
    
    private func generateAchievementCampaignContent(achievement: Achievement) -> CampaignContent {
        return CampaignContent(
            title: "🎉 \(achievement.title)",
            body: achievement.description + " Keep up the amazing progress!",
            actionButtons: [
                CampaignActionButton(
                    id: "view_progress",
                    text: "View Progress",
                    action: .openScreen(.insights)
                ),
                CampaignActionButton(
                    id: "share_achievement",
                    text: "Share",
                    action: .shareAchievement(achievement)
                )
            ],
            customData: [
                "achievement_id": achievement.id,
                "achievement_type": achievement.type.rawValue,
                "campaign_type": "achievement"
            ],
            richMedia: CampaignRichMedia(
                imageURL: getAchievementImageURL(achievement),
                videoURL: nil,
                soundName: "achievement_celebration.wav"
            )
        )
    }
    
    private func generateGoalCompletionCampaignContent(goal: GoalEntity) -> CampaignContent {
        let goalTitle = goal.title ?? "Your Goal"
        let goalCategory = goal.category ?? "personal"
        
        let celebrationMessages = [
            ("🎯 Goal Achieved!", "Congratulations! You've completed '\(goalTitle)'. Your dedication is inspiring!"),
            ("🌟 Mission Accomplished", "You did it! '\(goalTitle)' is now complete. Time to celebrate your success!"),
            ("🏆 Goal Completed", "Amazing work! You've successfully achieved '\(goalTitle)'. Keep up the momentum!"),
            ("✨ Achievement Unlocked", "Fantastic! '\(goalTitle)' is done. Your emotional growth journey continues!")
        ]
        
        let randomMessage = celebrationMessages.randomElement()!
        
        return CampaignContent(
            title: randomMessage.0,
            body: randomMessage.1,
            actionButtons: [
                CampaignActionButton(
                    id: "view_goals",
                    text: "View Goals",
                    action: .openScreen(.coaching)
                ),
                CampaignActionButton(
                    id: "set_new_goal",
                    text: "Set New Goal",
                    action: .openScreen(.coaching)
                )
            ],
            customData: [
                "goal_id": goal.id?.uuidString ?? "",
                "goal_title": goalTitle,
                "goal_category": goalCategory,
                "campaign_type": "goal_completion"
            ],
            richMedia: CampaignRichMedia(
                imageURL: getGoalCompletionImageURL(goalCategory: goalCategory),
                videoURL: nil,
                soundName: "goal_celebration.wav"
            )
        )
    }
    
    // Removed duplicate generateDailyCheckInContent method - using SmartNotificationScheduler instead
    
    private func generateReEngagementContent() -> CampaignContent {
        return CampaignContent(
            title: "💙 We Miss You",
            body: "Your emotional wellbeing journey is important. Ready to reconnect with your inner wisdom?",
            actionButtons: [
                CampaignActionButton(
                    id: "return_to_app",
                    text: "Continue Journey",
                    action: .openApp
                ),
                CampaignActionButton(
                    id: "quick_session",
                    text: "Quick Session",
                    action: .openScreen(.voiceAnalysis)
                )
            ],
            customData: [
                "campaign_type": "reengagement",
                "days_inactive": "3+"
            ],
            richMedia: nil
        )
    }
    
    // MARK: - Campaign Execution
    private func sendCampaignNotification(
        campaign: NotificationCampaign,
        content: CampaignContent,
        priority: NotificationPriority,
        delay: TimeInterval
    ) async {
        
        // Create OneSignal notification data
        let notificationData: [String: Any] = [
            "app_id": config.appid,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "data": content.customData,
            "buttons": content.actionButtons.map { button in
                ["id": button.id, "text": button.text]
            },
            "include_player_ids": [OneSignal.User.pushSubscription.id],
            "send_after": delay > 0 ? ISO8601DateFormatter().string(from: Date().addingTimeInterval(delay)) : nil,
            "filters": createCampaignFilters(campaign: campaign),
            "priority": priority.stringValue
        ].compactMapValues { $0 }
        
        // Add rich media if available
        if let richMedia = content.richMedia {
            var updatedData = notificationData
            if let imageURL = richMedia.imageURL {
                updatedData["big_picture"] = imageURL
                updatedData["large_icon"] = imageURL
            }
            if let soundName = richMedia.soundName {
                updatedData["ios_sound"] = soundName
            }
            
            // Send via OneSignal REST API
            await oneSignalService.sendNotificationViaAPI(updatedData)
        }
        
        
        // Update campaign analytics
        campaign.analytics.notificationsSent += 1
        campaignAnalytics.totalNotificationsSent += 1
        
        print("📤 Sent campaign notification: \(content.title)")
    }
    
    // MARK: - Campaign Optimization
    private func optimizeCampaignPerformance() async {
        // Analyze campaign performance
        let performanceData = await analyzeCampaignPerformance()
        
        // Optimize send times based on engagement
        await optimizeCampaignTiming(basedOn: performanceData)
        
        // Optimize content based on user preferences
        await optimizeCampaignContent(basedOn: performanceData)
        
        // Pause underperforming campaigns
        await pauseUnderperformingCampaigns(basedOn: performanceData)
        
        print("🔧 Campaign optimization completed")
    }
    
    private func analyzeCampaignPerformance() async -> CampaignPerformanceData {
        var performanceData = CampaignPerformanceData()
        
        for campaign in activeCampaigns {
            let engagementRate = campaign.analytics.calculateEngagementRate()
            let conversionRate = campaign.analytics.calculateConversionRate()
            
            performanceData.campaignPerformance[campaign.id] = CampaignMetrics(
                engagementRate: engagementRate,
                conversionRate: conversionRate,
                totalSent: campaign.analytics.notificationsSent,
                totalOpened: campaign.analytics.notificationsOpened,
                totalConverted: campaign.analytics.conversions
            )
        }
        
        return performanceData
    }
    
    // MARK: - Helper Methods
    private func getOptimalInterventions(for emotion: EmotionType) -> [OneSignaInterventionType] {
        switch emotion {
        case .joy:
            return [.gratitudePractice, .balanceMaintenance]
        case .sadness:
            return [.selfCompassionBreak, .breathingExercise]
        case .anger:
            return [.coolingBreath, .emotionalReset]
        case .fear:
            return [.groundingExercise, .breathingExercise]
        case .surprise:
            return [.mindfulnessCheck, .emotionalReset]
        case .disgust:
            return [.emotionalReset, .mindfulnessCheck]
        case .neutral:
            return [.balanceMaintenance, .mindfulnessCheck]
        }
    }
    
    private func getEmotionSpecificContent(emotion: EmotionType) -> (String, String) {
        switch emotion {
        case .joy:
            return ("✨ Amplify Your Joy", "You're feeling great! Let's make this positive energy last even longer.")
        case .sadness:
            return ("💙 Gentle Support", "I noticed you might be feeling down. You're not alone - let's work through this together.")
        case .anger:
            return ("🔥 Channel Your Energy", "Feeling intense emotions? Let's transform that energy into something positive.")
        case .fear:
            return ("🛡️ Build Your Courage", "Feeling anxious? You're stronger than you know. Let's practice some grounding techniques.")
        case .surprise:
            return ("⚡ Process the Unexpected", "Something caught you off guard? Let's help you process these new feelings.")
        case .disgust:
            return ("🌱 Reset and Refresh", "Feeling uncomfortable? Let's clear the air and reset your emotional state.")
        case .neutral:
            return ("⚖️ Maintain Balance", "You're in a good emotional space. Let's keep this balance going strong.")
        }
    }
    
    private func getInterventionButtonText(_ intervention: OneSignaInterventionType) -> String {
        switch intervention {
        case .gratitudePractice:
            return "Practice Gratitude"
        case .selfCompassionBreak:
            return "Self-Compassion"
        case .coolingBreath:
            return "Cooling Breath"
        case .groundingExercise:
            return "Grounding"
        case .mindfulnessCheck:
            return "Mindfulness"
        case .emotionalReset:
            return "Reset"
        case .balanceMaintenance:
            return "Maintain Balance"
        case .breathingExercise:
            return "Breathing"
        case .voiceGuidedMeditation:
            return "Voice Meditation"
        }
    }
    
    private func findOptimalCheckInTime(from pattern: UserBehaviorPattern) -> Date {
        // Find the most common usage hour
        let optimalHour = pattern.averageAppUsageHours.first ?? 9
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = optimalHour
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? Date()
    }
    
    private func isCampaignInCooldown(_ campaign: NotificationCampaign) async -> Bool {
        guard let lastTriggered = campaign.lastTriggered else { return false }
        
        let timeSinceLastTrigger = Date().timeIntervalSince(lastTriggered)
        return timeSinceLastTrigger < config.campaignCooldownPeriod
    }
    
    private func personalizeContent(
        _ content: CampaignContent,
        for result: EmotionAnalysisResult,
        userBehavior: UserBehaviorPattern
    ) async -> CampaignContent {
        
        // Personalize based on user's preferred interventions
        let preferredInterventions = userBehavior.preferredInterventionTypes
        let personalizedButtons = content.actionButtons.filter { button in
            preferredInterventions.contains { $0.rawValue == button.id }
        }
        
        // Use personalized buttons if available, otherwise use original
        let finalButtons = personalizedButtons.isEmpty ? content.actionButtons : personalizedButtons
        
        return CampaignContent(
            title: content.title,
            body: content.body,
            actionButtons: finalButtons,
            customData: content.customData,
            richMedia: content.richMedia
        )
    }
    
    private func createCampaignFilters(campaign: NotificationCampaign) -> [[String: Any]] {
        var filters: [[String: Any]] = []
        
        // Base filter for subscribed users
        filters.append([
            "field": "tag",
            "key": "notification_preferences",
            "relation": "=",
            "value": "emotion_aware"
        ])
        
        // Add campaign-specific filters
        for (key, value) in campaign.segmentation {
            filters.append([
                "field": "tag",
                "key": key,
                "relation": "=",
                "value": value
            ])
        }
        
        return filters
    }
    
    // MARK: - Campaign Management
    private func cleanupExpiredCampaigns() async {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        
        // Remove expired campaigns
        activeCampaigns.removeAll { campaign in
            campaign.createdAt < oneDayAgo && !campaign.isActive
        }
        
        // Clean up campaign dictionaries
        emotionTriggeredCampaigns = emotionTriggeredCampaigns.filter { _, campaign in
            campaign.createdAt >= oneDayAgo
        }
        
        predictiveCampaigns = predictiveCampaigns.filter { _, campaign in
            campaign.createdAt >= oneDayAgo
        }
        
        achievementCampaigns = achievementCampaigns.filter { _, campaign in
            campaign.createdAt >= oneDayAgo
        }
        
        goalCompletionCampaigns = goalCompletionCampaigns.filter { _, campaign in
            campaign.createdAt >= oneDayAgo
        }
        
        print("🧹 Cleaned up expired campaigns")
    }
    
    private func trackEmotionForOptimization(_ result: EmotionAnalysisResult) async {
        // Track emotion data for campaign optimization
        await behaviorAnalyzer.recordEmotionAnalysis(
            emotion: convertEmotionCategoryToType(result.primaryEmotion),
            confidence: result.confidence,
            intensity: result.intensity.threshold,
            context: ["source": "campaign_optimization"]
        )
    }
    
    private func processInterventionCompletion(_ intervention: NotificationIntervention) async {
        // Track intervention completion for campaign effectiveness
        await behaviorAnalyzer.recordInterventionCompletion(
            intervention: convertOneSignaInterventionToInterventionType(intervention.type),
            duration: intervention.duration,
            effectivenessScore: intervention.effectivenessScore,
            userFeedback: intervention.userFeedback
        )
        
        // Update campaign analytics
        if let campaign = activeCampaigns.first(where: { campaign in
            campaign.content.actionButtons.contains { $0.id == intervention.type.rawValue }
        }) {
            campaign.analytics.conversions += 1
            campaign.analytics.totalEffectivenessScore += intervention.effectivenessScore
        }
    }
    
    private func createEmotionTriggers(for emotion: EmotionType) -> [CampaignTrigger] {
        return [
            CampaignTrigger(
                type: .emotionDetected,
                condition: "emotion_equals",
                value: emotion.rawValue
            ),
            CampaignTrigger(
                type: .confidenceThreshold,
                condition: "confidence_greater_than",
                value: String(config.highConfidenceThreshold)
            )
        ]
    }
    
    
    private func createPredictiveTriggers(for prediction: EmotionalPrediction) -> [CampaignTrigger] {
        return [
            CampaignTrigger(
                type: .predictedEmotion,
                condition: "predicted_emotion_equals",
                value: prediction.predictedEmotion.rawValue
            ),
            CampaignTrigger(
                type: .predictionConfidence,
                condition: "prediction_confidence_greater_than",
                value: String(prediction.confidence)
            )
        ]
    }
    
    private func createDailyCheckInTriggers() -> [CampaignTrigger] {
        return [
            CampaignTrigger(
                type: .timeOfDay,
                condition: "hour_equals",
                value: "9"
            ),
            CampaignTrigger(
                type: .userActivity,
                condition: "last_activity_hours_ago_greater_than",
                value: "12"
            )
        ]
    }
    
    private func createReEngagementTriggers() -> [CampaignTrigger] {
        return [
            CampaignTrigger(
                type: .userActivity,
                condition: "last_activity_days_ago_greater_than",
                value: "3"
            ),
            CampaignTrigger(
                type: .engagementScore,
                condition: "engagement_score_less_than",
                value: "0.3"
            )
        ]
    }
    
    // Campaign Segmentation Functions
    private func createEmotionSegmentation(for emotion: EmotionType) -> [String: String] {
        return [
            "emotion_prone": emotion.rawValue,
            "notification_preferences": "emotion_aware",
            "subscription_tier": "premium"
        ]
    }
    
    private func createPredictiveSegmentation(for prediction: EmotionalPrediction) -> [String: String] {
        return [
            "predictive_enabled": "true",
            "ml_confidence": prediction.confidence > 0.8 ? "high" : "medium",
            "predicted_emotion": prediction.predictedEmotion.rawValue
        ]
    }
    
    private func createDailyCheckInSegmentation() -> [String: String] {
        return [
            "daily_checkin_enabled": "true",
            "engagement_level": "active",
            "notification_preferences": "emotion_aware"
        ]
    }
    
    private func createReEngagementSegmentation() -> [String: String] {
        return [
            "engagement_level": "inactive",
            "days_since_last_activity": "3+",
            "reengagement_eligible": "true"
        ]
    }
    
    // Campaign Schedule Functions
    private func createEmotionSchedule(for emotion: EmotionType) -> CampaignSchedule {
        let optimalHour = getOptimalHourForEmotion(emotion)
        let scheduledTime = getNextOccurrenceOfHour(optimalHour)
        
        return CampaignSchedule(
            scheduledTime: scheduledTime,
            repeatInterval: nil, // Triggered by emotion detection
            timeZone: TimeZone.current
        )
    }
    
    private func createPredictiveSchedule(for prediction: EmotionalPrediction) -> CampaignSchedule {
        return CampaignSchedule(
            scheduledTime: prediction.optimalTime,
            repeatInterval: nil, // One-time prediction
            timeZone: TimeZone.current
        )
    }
    
    // Campaign Optimization Functions
    private func optimizeCampaignTiming(basedOn performanceData: CampaignPerformanceData) async {
        // Analyze best performing time slots
        for (campaignId, metrics) in performanceData.campaignPerformance {
            if let campaign = activeCampaigns.first(where: { $0.id == campaignId }) {
                if metrics.engagementRate > 0.8 {
                    // Campaign is performing well, maintain current timing
                    continue
                } else if metrics.engagementRate < 0.3 {
                    // Campaign needs timing optimization
                    await adjustCampaignTiming(campaign)
                }
            }
        }
    }
    
    private func optimizeCampaignContent(basedOn performanceData: CampaignPerformanceData) async {
        // Analyze content performance and adjust messaging
        for (campaignId, metrics) in performanceData.campaignPerformance {
            if let campaign = activeCampaigns.first(where: { $0.id == campaignId }) {
                if metrics.conversionRate < 0.2 {
                    // Low conversion rate, optimize content
                    await adjustCampaignContent(campaign)
                }
            }
        }
    }
    
    private func pauseUnderperformingCampaigns(basedOn performanceData: CampaignPerformanceData) async {
        for (campaignId, metrics) in performanceData.campaignPerformance {
            if let campaign = activeCampaigns.first(where: { $0.id == campaignId }) {
                if metrics.engagementRate < 0.1 && metrics.totalSent > 10 {
                    // Very low engagement with sufficient data, pause campaign
                    campaign.isActive = false
                    print("⏸️ Paused underperforming campaign: \(campaign.name)")
                }
            }
        }
    }
    
    
    private func getOptimalHourForEmotion(_ emotion: EmotionType) -> Int {
        switch emotion {
        case .joy:
            return 10 // Mid-morning for gratitude
        case .sadness:
            return 14 // Afternoon for self-compassion
        case .anger:
            return 16 // Late afternoon for cooling down
        case .fear:
            return 11 // Late morning for courage building
        case .surprise:
            return 12 // Midday for processing
        case .disgust:
            return 15 // Mid-afternoon for reset
        case .neutral:
            return 9 // Morning for balance maintenance
        }
    }
    
    private func getNextOccurrenceOfHour(_ hour: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = 0
        components.second = 0
        
        if let scheduledTime = calendar.date(from: components) {
            if scheduledTime <= now {
                return calendar.date(byAdding: .day, value: 1, to: scheduledTime) ?? scheduledTime
            }
            return scheduledTime
        }
        
        return now.addingTimeInterval(3600) // Fallback to 1 hour from now
    }
    
    private func adjustCampaignTiming(_ campaign: NotificationCampaign) async {
        // Implement timing adjustment logic based on user behavior
        print("🔧 Adjusting timing for campaign: \(campaign.name)")
    }
    
    private func adjustCampaignContent(_ campaign: NotificationCampaign) async {
        // Implement content adjustment logic based on performance
        print("✏️ Adjusting content for campaign: \(campaign.name)")
    }
    
    func convertEmotionCategoryToType(_ category: EmotionCategory) -> EmotionType {
        switch category {
        case .joy: return .joy
        case .sadness: return .sadness
        case .anger: return .anger
        case .fear: return .fear
        case .surprise: return .surprise
        case .disgust: return .disgust
        case .neutral: return .neutral
        }
    }
    
    
}

// MARK: - Supporting Models
class NotificationCampaign: ObservableObject {
    let id: String
    let name: String
    let type: CampaignType
    let targetEmotion: EmotionType
    let content: CampaignContent
    let triggers: [CampaignTrigger]
    let segmentation: [String: String]
    let schedule: CampaignSchedule
    let analytics: CampaignAnalytics
    var isActive: Bool
    let createdAt: Date
    var lastTriggered: Date?
    
    init(id: String, name: String, type: CampaignType, targetEmotion: EmotionType, content: CampaignContent, triggers: [CampaignTrigger], segmentation: [String: String], schedule: CampaignSchedule, analytics: CampaignAnalytics, isActive: Bool, createdAt: Date) {
        self.id = id
        self.name = name
        self.type = type
        self.targetEmotion = targetEmotion
        self.content = content
        self.triggers = triggers
        self.segmentation = segmentation
        self.schedule = schedule
        self.analytics = analytics
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

enum CampaignType {
    case emotionTriggered
    case predictiveIntervention
    case dailyCheckIn
    case achievement
    case reEngagement
    case emergency
}

struct CampaignContent {
    let title: String
    let body: String
    let actionButtons: [CampaignActionButton]
    let customData: [String: String]
    let richMedia: CampaignRichMedia?
}

struct CampaignActionButton {
    let id: String
    let text: String
    let action: CampaignAction
}

enum CampaignAction {
    case openApp
    case openScreen(AppScreen)
    case openIntervention(OneSignaInterventionType)
    case remindLater(TimeInterval)
    case shareAchievement(Achievement)
}

enum AppScreen {
    case voiceAnalysis
    case insights
    case coaching
    case quickCheckIn
}

struct CampaignRichMedia {
    let imageURL: String?
    let videoURL: String?
    let soundName: String?
}

struct CampaignTrigger {
    let type: NotificationManagerTriggerType
    let condition: String
    let value: String
}

enum NotificationManagerTriggerType {
    case emotionDetected
    case confidenceThreshold
    case predictedEmotion
    case predictionConfidence
    case timeOfDay
    case userActivity
    case engagementScore
}

struct CampaignSchedule {
    let scheduledTime: Date
    let repeatInterval: TimeInterval?
    let timeZone: TimeZone
}

class CampaignAnalytics: ObservableObject {
    @Published var notificationsSent: Int = 0
    @Published var notificationsOpened: Int = 0
    @Published var conversions: Int = 0
    @Published var totalEffectivenessScore: Double = 0.00
    @Published var totalNotificationsSent: Int = 0
    
    func calculateEngagementRate() -> Double {
        guard notificationsSent > 0 else { return 0.0 }
        return Double(notificationsOpened) / Double(notificationsSent)
    }
    
    func calculateConversionRate() -> Double {
        guard notificationsOpened > 0 else { return 0.0 }
        return Double(conversions) / Double(notificationsOpened)
    }
    
    func calculateAverageEffectiveness() -> Double {
        guard conversions > 0 else { return 0.0 }
        return totalEffectivenessScore / Double(conversions)
    }
    
    func incrementNotificationsSent() {
        notificationsSent += 1
    }
    
    func incrementNotificationsOpened() {
        notificationsOpened += 1
    }
    
    func incrementConversions() {
        conversions += 1
    }
    
    func incrementCampaignsTriggered() {
        // This method can be used to track campaign triggers
    }
    
    func incrementTotalNotificationsSent() {
        totalNotificationsSent += 1
    }
    
    func addEffectivenessScore(_ score: Double) {
        totalEffectivenessScore += score
    }
}

struct CampaignPerformanceData {
    var campaignPerformance: [String: CampaignMetrics] = [:]
}

struct CampaignMetrics {
    let engagementRate: Double
    let conversionRate: Double
    let totalSent: Int
    let totalOpened: Int
    let totalConverted: Int
}

// MARK: - Helper Methods
private func convertOneSignaInterventionToInterventionType(_ oneSignaType: OneSignaInterventionType) -> InterventionType {
    switch oneSignaType {
    case .gratitudePractice:
        return .emotionalPrompt(.gratitude)
    case .selfCompassionBreak:
        return .emotionalPrompt(.selfCompassion)
    case .coolingBreath:
        return .breathing(.boxBreathing)
    case .groundingExercise:
        return .grounding(.fiveFourThreeTwoOne)
    case .mindfulnessCheck:
        return .mindfulness(.thoughtObservation)
    case .emotionalReset:
        return .emotionalPrompt(.emotionalProcessing)
    case .balanceMaintenance:
        return .mindfulness(.bodyAwareness)
    case .breathingExercise:
        return .breathing(.equalBreathing)
    case .voiceGuidedMeditation:
        return .mindfulness(.lovingKindness)
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}



