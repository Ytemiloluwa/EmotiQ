//
//  OneSignalService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 24-08-2025.
//
import Foundation
import OneSignalFramework
import Combine
import CoreML
import UserNotifications
import NaturalLanguage
import CoreData

// MARK: - OneSignal Service
@MainActor
class OneSignalService: NSObject, ObservableObject, OSNotificationClickListener, UNUserNotificationCenterDelegate {
    
    // MARK: - Shared Instance
    static let shared = OneSignalService()
    
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var userSubscriptionId: String?
    @Published var lastNotificationSent: Date?
    @Published var notificationAnalytics: NotificationAnalytics = NotificationAnalytics()
    
    // MARK: - Private Properties
    private let emotionService = CoreMLEmotionService.shared
    private let speechService = SpeechAnalysisService()
    private let hapticManager = HapticManager.shared
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasTriggeredWelcomeNotification: Bool {
        get { UserDefaults.standard.bool(forKey: "hasTriggeredWelcomeNotification") }
        set { UserDefaults.standard.set(newValue, forKey: "hasTriggeredWelcomeNotification") }
    }
    private var isSendingWelcomeNotification = false
    private var hasSetupUserTags = false
    
    // Predictive intervention system
    private let interventionPredictor = EmotionalInterventionPredictor()
    private let notificationScheduler = SmartNotificationScheduler()
    private let behaviorAnalyzer = UserBehaviorAnalyzer()
    
    // MARK: - Configuration
    private struct config {
        static let appId = Config.oneSignalAppID
        // Use secure proxy instead of direct OneSignal API
        static let baseURL = "https://emotiq-api-proxy-v2.vercel.app/api/onesignal"
        // Removed notification limits - no maximum daily notifications or minimum intervals
        // Removed emotionAnalysisThreshold - now triggers notifications for all emotions regardless of confidence
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupOneSignal()
        setupEmotionObservers()
        setupBehaviorTracking()
    }
    
    // MARK: - OneSignal Setup
    private func setupOneSignal() {
        // OneSignal is already initialized in AppDelegate
        // Here we configure additional settings and observers
        
        // Set up notification opened handler
        OneSignal.Notifications.addClickListener(self)
        
        // Note: OneSignal listeners are handled via protocol conformance
        // Click events are handled via OSNotificationClickListener protocol
        
        // Set up emotion data observers
        setupEmotionDataObservers()
        
        // Set up local notification categories
        setupNotificationCategories()
        
        // Initialize user state
        initializeUserState()
        
        // clear any pending local predictive notifications
        
        clearPredictiveLocalNotifications()
        
        // Request permission if not already granted
        requestNotificationPermission()
        
        // Schedule today's streak maintenance reminder at 6:00 PM
          Task { @MainActor in
              let scheduler = SmartNotificationScheduler()
              await scheduler.scheduleStreakMaintenanceReminder()
              await scheduler.scheduleDailyCheckIn()
          }
    }
    
    // MARK: - OSNotificationClickListener Protocol
    func onClick(event: OSNotificationClickEvent) {
        Task { @MainActor in
            await self.handleNotificationOpened(event)
        }
    }
    
    // MARK: - Helper Methods
    private func convertEmotionCategoryToType(_ category: EmotionCategory) -> EmotionType {
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
    
    private func convertPersonalizationContextToNotificationContent(_ context: PersonalizationContext) -> NotificationContent {
        let baseContent = getBaseContentForEmotion(context.emotion)
        
        return NotificationContent(
            title: baseContent.title,
            body: baseContent.body,
            actionButtons: getActionButtons(for: .mindfulnessCheck),
            customData: [
                "emotion": context.emotion.rawValue,
                "time_of_day": String(context.timeOfDay),
                "day_of_week": String(context.dayOfWeek),
                "contextual_factors": context.contextualFactors.joined(separator: ",")
            ],
            categoryIdentifier: "emotion_intervention",
            sound: .default,
            badge: 1,
            userInfo: [:]
        )
    }
    
    // MARK: - Permission Management
    func requestNotificationPermission() {
        // Check if we already have permission
        if OneSignal.Notifications.permission {
            Task { @MainActor in
                self.notificationPermissionStatus = .authorized
                self.setupUserTags()
                // Try to send welcome notification if this is first launch and not sent yet
                if !self.hasTriggeredWelcomeNotification {
                    self.scheduleInitialWelcomeNotification()
                }
            }
            return
        }
        
        OneSignal.Notifications.requestPermission({ accepted in
            
            // Don't rely on the callback result - it's unreliable
            // Instead, let the subscription state monitoring handle the permission check
            Task { @MainActor in
                // Force a permission check after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.forceSyncPermissionStatus()
                }
            }
        }, fallbackToSettings: false)
    }
    
    func setupUserTags() {
        // Prevent multiple tag setups
        guard !hasSetupUserTags else {
            return
        }
        
        hasSetupUserTags = true
        
        // Set initial user tags for segmentation (only once)
        OneSignal.User.addTags([
            "app_version": Config.appVersion,
            "user_type": "new_user",
            "emotion_analysis_enabled": "true",
            "voice_features_enabled": "true",
            "subscription_status": "free"
        ])
        
        // Force enable push subscription if permission is granted (only once)
        if OneSignal.Notifications.permission {
            OneSignal.Notifications.clearAll()
            OneSignal.Notifications.requestPermission({ accepted in
                // Permission result handled by subscription monitoring
            }, fallbackToSettings: false)
        }
    }
    
    private func initializeUserState() {
        // Initialize user state for OneSignal
        OneSignal.User.addTags([
            "initialized_at": ISO8601DateFormatter().string(from: Date()),
            "notification_preferences": "emotion_aware"
        ])
        
        // Check and fix subscription status
        checkAndFixSubscriptionStatus()
        
        // Set user as initialized
        isInitialized = true
    }
    
    private func checkAndFixSubscriptionStatus() {
        // Check if we have permission but subscription is disabled
        if OneSignal.Notifications.permission {
            // Update our permission status
            Task { @MainActor in
                self.notificationPermissionStatus = .authorized
            }
            
            // Force enable the subscription
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                OneSignal.Notifications.clearAll()
                OneSignal.Notifications.requestPermission({ accepted in
                    // Permission result handled by subscription monitoring
                }, fallbackToSettings: false)
            }
        }
    }
    
    // MARK: - Force Permission Sync
    func forceSyncPermissionStatus() {
        // Check actual OneSignal permission status
        let actualPermission = OneSignal.Notifications.permission
        
        // Get subscription status
        let subscriptionId = OneSignal.User.pushSubscription.id
        let optedIn = OneSignal.User.pushSubscription.optedIn
        
        
        Task { @MainActor in
            // Update our internal status based on actual OneSignal state
            if actualPermission || optedIn {
                self.notificationPermissionStatus = .authorized
                
                // If we have permission and subscription, try to send welcome notification
                if !(subscriptionId?.isEmpty ?? true) && !self.hasTriggeredWelcomeNotification && !self.isSendingWelcomeNotification {
                    
                    self.setupUserTags()
                    self.scheduleInitialWelcomeNotification()
                } else if self.hasTriggeredWelcomeNotification {
                    
                } else if self.isSendingWelcomeNotification {
                    
                } else {
                    
                }
            } else {
                self.notificationPermissionStatus = .denied
                
            }
        }
    }
    
    // MARK: - Fresh Install Detection
    func isFreshInstall() -> Bool {
        let subscriptionId = OneSignal.User.pushSubscription.id
        return ((subscriptionId?.isEmpty) != nil)
    }
    
    // MARK: - Emotion Data Observers
    private func setupEmotionDataObservers() {
        // Listen for emotion analysis results
        NotificationCenter.default.publisher(for: .emotionalDataSaved)
            .sink { [weak self] notification in
                if let result = notification.object as? EmotionAnalysisResult {
                    Task { @MainActor in
                        await self?.processEmotionAnalysisResult(result)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for speech analysis results
        NotificationCenter.default.publisher(for: .speechAnalysisCompleted)
            .sink { [weak self] notification in
                if let transcription = notification.object as? String {
                    Task { @MainActor in
                        await self?.processSpeechAnalysisResult(transcription)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Local Notification Categories
    private func setupNotificationCategories() {
        // Create emotion check-in category with actions
        let checkInAction = UNNotificationAction(
            identifier: "check_in",
            title: "Check In",
            options: [.foreground]
        )
        
        
        let emotionCheckInCategory = UNNotificationCategory(
            identifier: "emotion_checkin",
            actions: [checkInAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([emotionCheckInCategory])
        
        // Set delegate for handling notification actions
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Save local notification to history when it's received
        Task {
            await saveLocalNotificationToHistory(notification)
        }
        
        // Show notification with sound and badge
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "check_in":
            // User tapped "Check In" - send OneSignal notification with rich content
            handleCheckInAction(userInfo: userInfo)
        default:
            // User tapped the notification itself
            handleNotificationTap(userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    private func handleCheckInAction(userInfo: [AnyHashable: Any]) {
        // Send rich OneSignal notification when user wants to check in
        let content = NotificationContent(
            title: "💫 Let's Check In",
            body: "Take a moment to reflect on how you're feeling right now.",
            actionButtons: [
                NotificationActionButton(id: "start_voice_analysis", text: "Voice Check"),
                NotificationActionButton(id: "mindfulness_exercise", text: "Mindfulness")
            ],
            customData: [
                "type": "emotion_checkin",
                "source": "predictive_intervention",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            categoryIdentifier: "emotion_intervention",
            sound: .default,
            badge: 1,
            userInfo: [:]
        )
        
        Task {
            await sendNotificationWithContent(content, hapticPattern: .neutral)
            await saveNotificationToHistory([
                "type": "emotion_checkin",
                "title": content.title,
                "body": content.body,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Handle when user taps the notification itself
        
    }
    
    // MARK: - Emotion Detection Integration
    private func setupEmotionObservers() {
        // Note: Emotion analysis results are handled by setupEmotionDataObservers()
        // to avoid duplicate processing. This method is kept for speech analysis only.
        
        // Observe speech analysis results
        speechService.$lastTranscription
            .filter { !$0.isEmpty }
            .sink { [weak self] transcription in
                Task { @MainActor in
                    await self?.processSpeechAnalysisResult(transcription)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupBehaviorTracking() {
        // Track app usage patterns for predictive notifications
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.trackAppUsage()
                }
            }
            .store(in: &cancellables)
        
        // Track emotional patterns for ML optimization
        Timer.publish(every: 3600, on: .main, in: .common) // Every hour
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.analyzeEmotionalPatterns()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Emotion-Triggered Notifications
    private func processEmotionAnalysisResult(_ result: EmotionAnalysisResult) async {
        
        
        // Update user tags with current emotional state
        updateEmotionalStateTags(result)
        
        // Check if intervention is needed
        let shouldTrigger = shouldTriggerIntervention(for: result)
        
        
        if shouldTrigger {
            
            await triggerEmotionBasedIntervention(result)
        } else {
            
        }
        
        // Delegate to other systems (instead of duplicate observers)
        await delegateToOtherSystems(result)
    }
    
    // MARK: - System Delegation
    private func delegateToOtherSystems(_ result: EmotionAnalysisResult) async {
        // 1. Update predictive model with new data
        await interventionPredictor.updateWithEmotionData(result)
        
        // 2. Record emotion analysis for behavior tracking
        await behaviorAnalyzer.recordEmotionAnalysis(
            emotion: convertEmotionCategoryToType(result.primaryEmotion),
            confidence: result.confidence,
            intensity: result.intensity.threshold,
            context: ["source": "voice_analysis"]
        )
        
    }
    
    private func processSpeechAnalysisResult(_ transcription: String) async {
        // Analyze speech content for additional emotional context
        let sentiment = await analyzeSentiment(transcription)
        let emotionalKeywords = extractEmotionalKeywords(transcription)
        
        // Update user tags with speech analysis
        OneSignal.User.addTags([
            "last_speech_sentiment": sentiment,
            "emotional_keywords": emotionalKeywords.joined(separator: ","),
            "speech_analysis_timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        // Trigger contextual notifications based on speech content
        if shouldTriggerSpeechBasedIntervention(sentiment: sentiment, keywords: emotionalKeywords) {
            await triggerSpeechBasedIntervention(sentiment: sentiment, keywords: emotionalKeywords)
        }
    }
    
    private func clearPredictiveLocalNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { req in
                req.identifier.hasPrefix("predictive_") || req.content.categoryIdentifier == "emotion_checkin"
            }.map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.filter { item in
                item.request.identifier.hasPrefix("predictive_") || item.request.content.categoryIdentifier == "emotion_checkin"
            }.map { $0.request.identifier }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
            
        }
    }
    
    private func scheduleInterventionNotification(_ prediction: EmotionalPrediction) async {
        let notification = EmotionTriggeredNotification(
            emotion: prediction.predictedEmotion,
            interventionType: prediction.recommendedIntervention,
            scheduledTime: prediction.optimalTime,
            personalizationData: convertPersonalizationContextToNotificationContent(prediction.personalizationContext)
        )
        
        await sendScheduledNotification(notification)
    }
    
    // MARK: - Smart Notification Scheduling
    private func triggerEmotionBasedIntervention(_ result: EmotionAnalysisResult) async {
        let emotionType = convertEmotionCategoryToType(result.primaryEmotion)
        let intervention = getOptimalIntervention(for: emotionType)
        
        let personalizedContent = generatePersonalizedContent(
            emotion: emotionType,
            confidence: result.confidence,
            intervention: intervention
        )
        
        let notification = EmotionTriggeredNotification(
            emotion: emotionType,
            interventionType: intervention,
            scheduledTime: Date(),
            personalizationData: personalizedContent
        )
        
        await sendImmediateNotification(notification)
    }
    
    private func sendSpeechBasedNotification(_ notification: SpeechTriggeredNotification) async {
        guard canSendNotification() else { return }
        
        await sendNotificationWithContent(notification.personalizedContent, hapticPattern: .neutral)
        updateNotificationAnalytics(for: .neutral)
    }
    
    private func triggerSpeechBasedIntervention(sentiment: String, keywords: [String]) async {
        let intervention = getOptimalInterventionForSpeech(sentiment: sentiment, keywords: keywords)
        let personalizedContent = generateSpeechBasedContent(sentiment: sentiment, keywords: keywords)
        
        let notification = SpeechTriggeredNotification(
            sentiment: sentiment,
            keywords: keywords,
            interventionType: intervention,
            personalizedContent: personalizedContent
        )
        
        await sendSpeechBasedNotification(notification)
    }
    
    // MARK: - Notification Content Generation
    private func generatePersonalizedContent(
        emotion: EmotionType,
        confidence: Double,
        intervention: OneSignaInterventionType
    ) -> NotificationContent {
        let baseContent = getBaseContentForEmotion(emotion)
        let confidenceModifier = getConfidenceModifier(confidence)
        let interventionCTA = getInterventionCallToAction(intervention)
        
        return NotificationContent(
            title: "\(baseContent.title) \(confidenceModifier)",
            body: "\(baseContent.body) \(interventionCTA)",
            actionButtons: getActionButtons(for: intervention),
            customData: [
                "emotion": emotion.rawValue,
                "confidence": String(confidence),
                "intervention_type": intervention.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            categoryIdentifier: "emotion_intervention",
            sound: .default,
            badge: 1,
            userInfo: [:]
        )
    }
    
    private func getBaseContentForEmotion(_ emotion: EmotionType) -> (title: String, body: String) {
        switch emotion {
        case .joy:
            return (
                title: "✨ Amplify Your Joy",
                body: "You're feeling great! Let's make this positive energy last even longer."
            )
        case .sadness:
            return (
                title: "💙 Gentle Support",
                body: "I noticed you might be feeling down. You're not alone - let's work through this together."
            )
        case .anger:
            return (
                title: "🔥 Channel Your Energy",
                body: "Feeling intense emotions? Let's transform that energy into something positive."
            )
        case .fear:
            return (
                title: "🛡️ Build Your Courage",
                body: "Feeling anxious? You're stronger than you know. Let's practice some grounding techniques."
            )
        case .surprise:
            return (
                title: "⚡ Process the Unexpected",
                body: "Something caught you off guard? Let's help you process these new feelings."
            )
        case .disgust:
            return (
                title: "🌱 Reset and Refresh",
                body: "Feeling uncomfortable? Let's clear the air and reset your emotional state."
            )
        case .neutral:
            return (
                title: "⚖️ Maintain Balance",
                body: "You're in a good emotional space. Let's keep this balance going strong."
            )
        }
    }
    
    private func getOptimalIntervention(for emotion: EmotionType) -> OneSignaInterventionType {
        switch emotion {
        case .joy:
            return .gratitudePractice
        case .sadness:
            return .selfCompassionBreak
        case .anger:
            return .coolingBreath
        case .fear:
            return .groundingExercise
        case .surprise:
            return .mindfulnessCheck
        case .disgust:
            return .emotionalReset
        case .neutral:
            return .balanceMaintenance
        }
    }
    
    private func getOptimalInterventionForSpeech(sentiment: String, keywords: [String]) -> OneSignaInterventionType {
        // Use SpeechAnalysisService's comprehensive keyword analysis for intervention mapping
        let text = keywords.joined(separator: " ")
        let emotionalKeywords = speechService.analyzeEmotionalKeywords(text: text)
        
        // Map detected emotions to optimal interventions
        let emotionInterventionMap: [EmotionCategory: OneSignaInterventionType] = [
            .joy: .gratitudePractice,
            .sadness: .selfCompassionBreak,
            .anger: .coolingBreath,
            .fear: .groundingExercise,
            .surprise: .mindfulnessCheck,
            .disgust: .emotionalReset,
            .neutral: .balanceMaintenance
        ]
        
        // Find the highest weighted emotion from the analysis
        let primaryEmotion = emotionalKeywords
            .max(by: { $0.weight < $1.weight })?.emotion ?? .neutral
        
        // Return the optimal intervention for the detected emotion
        return emotionInterventionMap[primaryEmotion] ?? .mindfulnessCheck
    }
    
    private func generateSpeechBasedContent(sentiment: String, keywords: [String]) -> NotificationContent {
        let intervention = getOptimalInterventionForSpeech(sentiment: sentiment, keywords: keywords)
        let baseContent = getBaseContentForSpeech(sentiment: sentiment, keywords: keywords)
        
        return NotificationContent(
            title: baseContent.title,
            body: baseContent.body,
            actionButtons: getActionButtons(for: intervention),
            customData: [
                "sentiment": sentiment,
                "keywords": keywords.joined(separator: ","),
                "intervention_type": intervention.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            categoryIdentifier: "speech_intervention",
            sound: .default,
            badge: 1,
            userInfo: [:]
        )
    }
    
    private func getBaseContentForSpeech(sentiment: String, keywords: [String]) -> (title: String, body: String) {
        let lowercasedSentiment = sentiment.lowercased()
        
        if lowercasedSentiment.contains("stress") || lowercasedSentiment.contains("anxiety") {
            return (
                title: "🛡️ Let's Find Your Calm",
                body: "I heard you mention feeling stressed. Let's work through this together with some grounding techniques."
            )
        } else if lowercasedSentiment.contains("sad") || lowercasedSentiment.contains("down") {
            return (
                title: "💙 You're Not Alone",
                body: "It sounds like you're having a tough time. Remember, it's okay to not be okay. Let's practice some self-compassion."
            )
        } else if lowercasedSentiment.contains("angry") || lowercasedSentiment.contains("frustrated") {
            return (
                title: "🔥 Channel That Energy",
                body: "I sense some frustration in your voice. Let's transform that energy into something positive."
            )
        } else {
            return (
                title: "🎯 Let's Process This",
                body: "I heard something in your voice that caught my attention. Let's take a moment to reflect and process."
            )
        }
    }
    
    // MARK: - Notification Sending
    private func sendImmediateNotification(_ notification: EmotionTriggeredNotification) async {
 
        
        guard canSendNotification() else {
     
            return
        }
        
   
        
        let content = generatePersonalizedContent(
            emotion: notification.emotion,
            confidence: 0.8, // Default confidence for immediate notifications
            intervention: notification.interventionType
        )
        
        
        await sendNotificationWithContent(content, hapticPattern: notification.emotion)
        updateNotificationAnalytics(for: notification.emotion)
        
       
    }
    
    private func sendScheduledNotification(_ notification: EmotionTriggeredNotification) async {
        guard canSendNotification() else { return }
        
        // Schedule notification for future delivery
        let content = generatePersonalizedContent(
            emotion: notification.emotion,
            confidence: 0.8,
            intervention: notification.interventionType
        )
        
        await scheduleNotificationForTime(content, at: notification.scheduledTime)
    }
    
    private func sendNotificationWithContent(_ content: NotificationContent, hapticPattern: EmotionType) async {
        
        // Send via OneSignal REST API for advanced features
        let notificationData: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "data": content.customData,
            "buttons": content.actionButtons?.map { button in
                ["id": button.id, "text": button.text]
            } ?? [],
            "include_player_ids": [OneSignal.User.pushSubscription.id]
            // Note: Removed filters when using include_player_ids to prevent cross-user targeting
        ]
        
     
        await sendNotificationViaAPI(notificationData)
        
        // Trigger haptic feedback for immediate notifications
        hapticManager.emotionalFeedback(for: hapticPattern)
        
        lastNotificationSent = Date()

    }
    
    func sendNotificationViaAPI(_ data: [String: Any]) async -> Bool {
        guard let url = URL(string: "\(config.baseURL)?path=notifications") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // API key is handled by the secure proxy - no need to include it in the request
        
        do {
            
            let playerId = OneSignal.User.pushSubscription.id
            let optedIn = OneSignal.User.pushSubscription.optedIn
            guard let nonEmptyPlayerId = playerId, !nonEmptyPlayerId.isEmpty, optedIn else {
                return false
            }
            
            var payload = data
            payload["include_player_ids"] = [nonEmptyPlayerId]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
     
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                
            }
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
      
                    
                    // Save notification to history
                    await saveNotificationToHistory(payload)
                    return true
                } else {
                  
                    if let responseString = String(data: responseData, encoding: .utf8) {
                       
                    }
                    return false
                }
            }
        } catch {

        }
        return false
    }
    
    // MARK: - Notification Handlers
    private func handleNotificationOpened(_ result: OSNotificationClickEvent) async {
        // Track notification engagement
        notificationAnalytics.notificationOpened += 1
        
        // Extract custom data
        if let customData = result.notification.additionalData {
            // Handle welcome notification actions
            if let notificationType = customData["notification_type"] as? String,
               notificationType == "welcome" {
                await handleWelcomeNotificationAction(result)
                return
            }
            
            // Handle goal completion notification actions
            if let campaignType = customData["campaign_type"] as? String,
               campaignType == "goal_completion" {
                await handleGoalCompletionNotificationAction(result)
                return
            }
            
            // Handle emotion-based notifications
            if let emotion = customData["emotion"] as? String,
               let emotionType = EmotionType(rawValue: emotion) {
                
                // Trigger appropriate haptic feedback
                hapticManager.emotionalFeedback(for: emotionType)
                
                // Navigate to appropriate intervention
                await navigateToIntervention(emotionType, customData: customData as? [String: Any] ?? [:])
            }
        }
        
        // Update user engagement tags
        OneSignal.User.addTags([
            "last_notification_opened": ISO8601DateFormatter().string(from: Date()),
            "notification_engagement": "high"
        ])
    }
    
    private func handleWelcomeNotificationAction(_ result: OSNotificationClickEvent) async {
        // Get the action that was tapped
        let actionId = result.result.actionId
        
        switch actionId {
        case "start_analysis":
            // Navigate to VoiceAnalysisView using deep link
            await navigateToVoiceAnalysis()
            
        case "explore_app":
            // Navigate to main app using deep link
            await navigateToMainApp()
            
        default:
            // Default behavior - just open the app
            break
        }
        
        // Update user tags for welcome notification engagement
        OneSignal.User.addTags([
            "welcome_notification_engaged": "true",
            "welcome_action_taken": actionId ?? "unknown",
            "onboarding_completed": "true"
        ])
    }
    
    private func handleGoalCompletionNotificationAction(_ result: OSNotificationClickEvent) async {
        // Get the action that was tapped
        let actionId = result.result.actionId
        
        switch actionId {
        case "view_goals":
            // Navigate to Goals tab
            await navigateToGoals()
            
        case "set_new_goal":
            // Navigate to Goals tab
            await navigateToGoals()
            
        default:
            // Default behavior - just open the app
            break
        }
        
        // Update user tags for goal completion notification engagement
        OneSignal.User.addTags([
            "goal_completion_notification_engaged": "true",
            "goal_completion_action_taken": actionId ?? "unknown",
            "last_goal_completion_engagement": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    private func navigateToGoals() async {
        // Post notification to navigate to Goals tab
        NotificationCenter.default.post(
            name: Notification.Name("navigateToGoals"),
            object: nil,
            userInfo: ["source": "goal_completion_notification"]
        )
    }
    
    private func navigateToVoiceAnalysis() async {
        // Post notification to navigate to VoiceAnalysisView
        NotificationCenter.default.post(
            name: Notification.Name("navigateToVoiceAnalysis"),
            object: nil,
            userInfo: ["source": "welcome_notification"]
        )
    }
    
    private func navigateToMainApp() async {
        // Post notification to navigate to main app
        NotificationCenter.default.post(
            name: Notification.Name("navigateToMainApp"),
            object: nil,
            userInfo: ["source": "welcome_notification"]
        )
    }
    
    private func handleNotificationReceived(_ notification: OSNotification) async {
        // Track notification delivery
        notificationAnalytics.notificationReceived += 1
        
        // Update user tags with notification received
        OneSignal.User.addTags([
            "last_notification_received": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    // MARK: - User Behavior Analysis
    private func trackAppUsage() async {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        
        // Update behavior tracking tags
        OneSignal.User.addTags([
            "last_app_open_hour": String(currentHour),
            "last_app_open_day": String(dayOfWeek),
            "app_usage_timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        // Feed data to behavior analyzer
        await behaviorAnalyzer.recordAppUsage(hour: currentHour, dayOfWeek: dayOfWeek)
        
        // Check for streak maintenance reminder
        await checkStreakMaintenance()
    }
    
    // MARK: - Streak Maintenance Reminder
    private func checkStreakMaintenance() async {
        
        // Only send streak reminders if user has granted notification permission
        guard OneSignal.Notifications.permission && OneSignal.User.pushSubscription.optedIn else { return }
        
        // Check if this is a fresh install (no previous app usage recorded)
        let lastAppUsage = UserDefaults.standard.object(forKey: "last_app_usage") as? Date
        let isFreshInstall = (lastAppUsage == nil)
        
        if isFreshInstall {
            // Set initial timestamp for future streak checks
            UserDefaults.standard.set(Date(), forKey: "last_app_usage")
            return
        }
        
        // Check if user hasn't used app for 24+ hours
        let hoursSinceLastUsage = Date().timeIntervalSince(lastAppUsage!) / 3600
        
        // Update last app usage timestamp
        UserDefaults.standard.set(Date(), forKey: "last_app_usage")
        
        // Send streak reminder if user hasn't used app for 24+ hours
        if hoursSinceLastUsage >= 24 {
            await sendStreakMaintenanceReminder()
        } else {

        }
    }
    
    private func sendStreakMaintenanceReminder() async {
        let streakMessages = [
            ("🔥 Don't lose your streak!", "You've been doing great! Don't let your emotional wellness journey slip away."),
            ("💪 Keep the momentum!", "Your consistency is inspiring. Let's continue your emotional growth journey!"),
            ("🌟 You're on fire!", "Don't break your amazing streak! Your emotional wellness matters."),
            ("🎯 Stay consistent!", "You've built something beautiful. Keep nurturing your emotional growth!")
        ]
        
        let randomMessage = streakMessages.randomElement()!
        
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": randomMessage.0],
            "contents": ["en": randomMessage.1],
            "buttons": [
                ["id": "continue_streak", "text": "Continue Streak"],
                ["id": "voice_check", "text": "Voice Check"]
            ],
            "data": [
                "type": "reminder",
                "reminder_type": "streak_maintenance",
                "emotion": "motivation",
                "intervention": "streak_reminder",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""]
        ]
        
        await sendNotificationViaAPI(data)

    }
    
    private func analyzeEmotionalPatterns() async {
        // Analyze user's emotional patterns for predictive notifications
        let patterns = await behaviorAnalyzer.analyzeEmotionalPatterns()
        
        // Update user tags with pattern insights
        OneSignal.User.addTags([
            "emotional_pattern": patterns.dominantPattern,
            "stress_peak_hours": patterns.stressPeakHours.map(String.init).joined(separator: ","),
            "optimal_intervention_times": patterns.optimalInterventionTimes.map(String.init).joined(separator: ",")
        ])
        
        // Convert EmotionalPatternInsights to EmotionalPatterns for scheduling
        let emotionalPatterns = EmotionalPatterns(
            primaryEmotion: .neutral, // Default, will be overridden by prediction
            confidence: patterns.confidenceLevel,
            optimalInterventionTimes: patterns.optimalInterventionTimes.map { hour in
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.hour = hour
                components.minute = 0
                components.second = 0
                return calendar.date(from: components) ?? Date()
            },
            preferredInterventions: [.mindfulnessCheck] // Default intervention
        )
        
        // Schedule predictive interventions based on patterns
        await schedulePredictiveInterventionsFromPatterns(emotionalPatterns)
    }
    
    // MARK: - Helper Methods
    
    func getCurrentSubscriptionStatus() -> String {
        let permission = OneSignal.Notifications.permission
        let subscriptionId = OneSignal.User.pushSubscription.id
        let optedIn = OneSignal.User.pushSubscription.optedIn
        
        return """
        🔍 OneSignal Status:
        - Permission: \(permission)
        - Subscription ID: \(subscriptionId)
        - Opted In: \(optedIn)
        - Our Status: \(notificationPermissionStatus)
        """
    }
    
    func forceUpdatePermissionStatus() {
    
        let actualPermission = OneSignal.Notifications.permission

        
        Task { @MainActor in
            self.notificationPermissionStatus = actualPermission ? .authorized : .denied
            
        }
    }
    
    private func canSendNotification() -> Bool {

        
        guard notificationPermissionStatus == .authorized else {
            
            return false
        }
        
        // Removed notification limits - no daily limits or minimum intervals

        return true
    }
    
    private func updateNotificationAnalytics(for emotion: EmotionType) {
        notificationAnalytics.recordNotificationSent()
        
        // Update emotion-specific analytics
        OneSignal.User.addTags([
            "last_notification_emotion": emotion.rawValue,
            "notifications_sent_today": String(notificationAnalytics.notificationsSent)
        ])
    }
    
    private func shouldTriggerIntervention(for result: EmotionAnalysisResult) -> Bool {

        
        // Trigger notifications for all emotions regardless of confidence
        // This ensures users get support whenever they record their voice
        switch result.primaryEmotion {
        case .sadness, .anger, .fear, .disgust, .joy, .surprise:
            
            return true
        case .neutral:
          
            return false // Don't trigger automatic interventions for neutral
        }
    }
    
    private func updateEmotionalStateTags(_ result: EmotionAnalysisResult) {
        OneSignal.User.addTags([
            "current_emotion": result.primaryEmotion.rawValue,
            "emotion_confidence": String(format: "%.2f", result.confidence),
            "emotion_intensity": String(format: "%.2f", result.intensity.threshold),
            "last_emotion_analysis": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    // MARK: - Sentiment Analysis
    private func analyzeSentiment(_ text: String) async -> String {
        // Use NaturalLanguage framework for sentiment analysis
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let sentimentScore = sentiment {
            let score = Double(sentimentScore.rawValue) ?? 0.0
            if score > 0.1 {
                return "positive"
            } else if score < -0.1 {
                return "negative"
            } else {
                return "neutral"
            }
        }
        
        return "neutral"
    }
    
    private func extractEmotionalKeywords(_ text: String) -> [String] {
        let emotionalKeywords = [
            // Positive emotions
            "happy", "joy", "excited", "grateful", "love", "amazing", "wonderful", "great",
            // Negative emotions
            "sad", "angry", "frustrated", "worried", "anxious", "stressed", "upset", "disappointed",
            // Neutral/descriptive
            "tired", "confused", "uncertain", "calm", "peaceful", "relaxed"
        ]
        
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        return words.filter { emotionalKeywords.contains($0) }
    }
    
    // MARK: - Speech-Based Intervention Logic
    private func shouldTriggerSpeechBasedIntervention(sentiment: String, keywords: [String]) -> Bool {
        // Production logic: Only trigger interventions for significant emotional content
        
        // 1. Check sentiment intensity
        let sentimentRequiresIntervention = sentiment == "negative" || sentiment == "positive"
        
        // 2. Check for high-impact emotional keywords
        let highImpactKeywords = [
            "suicide", "kill", "die", "end", "hopeless", "worthless", // Crisis keywords
            "panic", "terrified", "overwhelmed", "can't cope", // High distress
            "amazing", "incredible", "best day", "so happy" // High positive
        ]
        
        let hasHighImpactKeywords = keywords.contains { keyword in
            highImpactKeywords.contains { highImpact in
                keyword.lowercased().contains(highImpact.lowercased())
            }
        }
        
        // 3. Check keyword density (multiple emotional words suggest strong emotion)
        let emotionalKeywordCount = keywords.count
        let hasSignificantEmotionalContent = emotionalKeywordCount >= 2
        
        // 4. Check user's current notification state
        let hasRecentIntervention = lastNotificationSent != nil &&
            Date().timeIntervalSince(lastNotificationSent!) < 3600 // Within last hour
        
        // Production decision logic:
        // - Always trigger for crisis keywords
        // - Trigger for negative sentiment with emotional keywords
        // - Trigger for very positive sentiment (amplification opportunity)
        // - Respect notification limits
        if hasHighImpactKeywords {
            return true // Crisis intervention
        }
        
        if sentimentRequiresIntervention && hasSignificantEmotionalContent && !hasRecentIntervention {
            return true
        }
        
        return false
    }
    
    // MARK: - Deep Link Navigation
    private func navigateToIntervention(_ emotion: EmotionType, customData: [String: Any]) async {
        // Production deep linking: Navigate user to appropriate intervention based on notification data
        
        // Extract intervention type from custom data
        let interventionTypeString = customData["intervention_type"] as? String ?? ""
        let interventionType = OneSignaInterventionType(rawValue: interventionTypeString) ?? getOptimalIntervention(for: emotion)
        
        // Create deep link URL with intervention context
        var deepLinkComponents = URLComponents()
        deepLinkComponents.scheme = "emotiq"
        deepLinkComponents.host = "intervention"
        deepLinkComponents.queryItems = [
            URLQueryItem(name: "type", value: interventionType.rawValue),
            URLQueryItem(name: "emotion", value: emotion.rawValue),
            URLQueryItem(name: "source", value: "notification"),
            URLQueryItem(name: "timestamp", value: ISO8601DateFormatter().string(from: Date()))
        ]
        
        // Add custom data as query parameters
        for (key, value) in customData {
            if let stringValue = value as? String {
                deepLinkComponents.queryItems?.append(URLQueryItem(name: key, value: stringValue))
            }
        }
        
        // Post notification for app to handle deep link
        if let deepLinkURL = deepLinkComponents.url {
            NotificationCenter.default.post(
                name: .deepLinkToIntervention,
                object: deepLinkURL,
                userInfo: [
                    "intervention_type": interventionType,
                    "emotion": emotion,
                    "custom_data": customData
                ]
            )
            
            // Update analytics for successful navigation
            OneSignal.User.addTags([
                "last_intervention_navigation": ISO8601DateFormatter().string(from: Date()),
                "navigated_intervention": interventionType.rawValue,
                "navigation_emotion": emotion.rawValue
            ])
            
        
        }
    }
    
    // MARK: - Welcome Notification
    func scheduleInitialWelcomeNotification() {
        // Check if this is truly a first install
        guard isFirstAppLaunch() else {
          
            return
        }
        
        // Prevent multiple welcome notifications
        guard !hasTriggeredWelcomeNotification else {
   
            return
        }
        
        // Prevent concurrent welcome notification attempts
        guard !isSendingWelcomeNotification else {

            return
        }
        
        isSendingWelcomeNotification = true
        
        // Wait for OneSignal to fully register the device and user to grant permission
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            Task {
                await self.sendWelcomeNotificationWithRetry()
            }
        }
    }
    
    private func isFirstAppLaunch() -> Bool {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            // Don't mark as launched until we actually send the welcome notification
            return true
        }
        return false
    }
    
    private func sendWelcomeNotificationWithRetry() async {
        let playerId = OneSignal.User.pushSubscription.id
        let optedIn = OneSignal.User.pushSubscription.optedIn
        let permission = OneSignal.Notifications.permission
        
        
        // Enhanced validation - check if player is fully subscribed
        guard !(playerId?.isEmpty ?? true) else {
         
            return
        }
        
        guard optedIn else {
     
            return
        }
        
        guard permission else {
      
            return
        }
        
        let welcomeData: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": "🎉 Welcome to EmotiQ!"],
            "contents": ["en": "Your emotional intelligence journey begins now. Discover your emotional patterns with voice analysis."],
            "include_player_ids": [playerId!],
            "data": [
                "notification_type": "welcome",
                "user_journey_stage": "onboarding",
                "action": "voice_analysis",
                "deep_link_voice": "emotiq://voice-analysis",
                "deep_link_dashboard": "emotiq://dashboard"
            ],
            "buttons": [
                ["id": "start_analysis", "text": "Start Voice Analysis"],
                ["id": "explore_app", "text": "Explore App"]
            ],
            "ios_category": "WELCOME"
        ]
        
    
        let success = await sendNotificationViaAPI(welcomeData)
        
        // Reset the sending flag
        isSendingWelcomeNotification = false
        
        // Only mark as sent if successful
        if success {
            hasTriggeredWelcomeNotification = true
            // Mark app as launched only after successful welcome notification
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            
        } else {
  
        }
    }
    
    private func scheduleNotificationForTime(_ content: NotificationContent, at time: Date) async {
        // Implementation for scheduling future notifications
        let timeInterval = time.timeIntervalSince(Date())
        guard timeInterval > 0 else { return }
        
        let notificationData: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "data": content.customData,
            "send_after": ISO8601DateFormatter().string(from: time),
            "include_player_ids": [OneSignal.User.pushSubscription.id]
        ]
        
        await sendNotificationViaAPI(notificationData)
    }

    // MARK: - Public APIs for App Events
    func sendStreakNotification(streak: Int, interventionTitle: String, isMilestone: Bool) async {
        let title = isMilestone ? "🌟 Milestone Unlocked!" : "🔥 Streak Updated"
        let body = isMilestone ? "You've hit a \(streak)-day streak! Keep it going." : "You're on a \(streak)-day streak with \(interventionTitle)."
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": title],
            "contents": ["en": body],
            "data": [
                "type": "achievement",
                "campaign_type": isMilestone ? "goal_completion" : "achievement",
                "streak": streak,
                "intervention": interventionTitle,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""],
            "ios_category": isMilestone ? "GOAL_COMPLETION" : "ACHIEVEMENT"
        ]
        _ = await sendNotificationViaAPI(data)
    }

    func sendFeedback(tags: [String], interventionTitle: String) async {
        guard !tags.isEmpty else { return }
        let text = tags.joined(separator: ", ")
        // Tag feedback on the user profile so it is visible in OneSignal dashboard
        OneSignal.User.addTags([
            "last_feedback_tags": text,
            "last_feedback_intervention": interventionTitle,
            "last_feedback_time": ISO8601DateFormatter().string(from: Date())
        ])
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": "Thanks for your feedback"],
            "contents": ["en": "You marked: \(text) for \(interventionTitle)."],
            "data": [
                "type": "feedback",
                "intervention": interventionTitle,
                "feedback_tags": text,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""]
        ]
        _ = await sendNotificationViaAPI(data)
    }
    
    // MARK: - In-App Messages: Tags & Triggers
    func tagCompletionAndTriggerIAM(interventionTitle: String, category: String, durationSeconds: Int, rating: Int) async {
        OneSignal.User.addTags([
            "last_session_title": interventionTitle,
            "last_session_category": category,
            "last_session_duration": String(durationSeconds),
            "last_session_rating": String(rating),
            "last_session_completed_at": ISO8601DateFormatter().string(from: Date())
        ])
        
        OneSignal.InAppMessages.addTrigger("event", withValue: "session_completed")
        OneSignal.InAppMessages.addTriggers([
            "session_category": category,
            "session_title": interventionTitle
        ])
        
        let streak = (try? computeCurrentStreak()) ?? 0
        OneSignal.User.addTags(["streak_count": String(streak)])
        if streak == 7 || streak == 30 {
            OneSignal.InAppMessages.addTrigger("streak_milestone", withValue: String(streak))
        }
    }
    
    private func computeCurrentStreak(referenceDate: Date = Date()) throws -> Int {
        let context = PersistenceController.shared.container.viewContext
        let fetch: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -35, to: referenceDate) ?? referenceDate
        fetch.predicate = NSPredicate(format: "completedAt >= %@ AND completedAt <= %@", start as NSDate, referenceDate as NSDate)
        fetch.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        let results = try context.fetch(fetch)
        var days = Set<Date>()
        for item in results { if let d = item.completedAt { days.insert(cal.startOfDay(for: d)) } }
        var streak = 0
        var cursor = cal.startOfDay(for: referenceDate)
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
    
    private func getActionButtons(for intervention: OneSignaInterventionType) -> [NotificationActionButton] {
        switch intervention {
        case .gratitudePractice:
            return [
                NotificationActionButton(id: "start_gratitude", text: "Start Practice"),
                NotificationActionButton(id: "remind_later", text: "Remind Later")
            ]
        case .selfCompassionBreak:
            return [
                NotificationActionButton(id: "start_compassion", text: "Take Break"),
                NotificationActionButton(id: "skip", text: "Skip")
            ]
        case .coolingBreath:
            return [
                NotificationActionButton(id: "start_breathing", text: "Start Breathing"),
                NotificationActionButton(id: "remind_later", text: "Remind Later")
            ]
        case .groundingExercise:
            return [
                NotificationActionButton(id: "start_grounding", text: "Ground Now"),
                NotificationActionButton(id: "skip", text: "Skip")
            ]
        case .mindfulnessCheck:
            return [
                NotificationActionButton(id: "start_mindfulness", text: "Check In"),
                NotificationActionButton(id: "remind_later", text: "Remind Later")
            ]
        case .emotionalReset:
            return [
                NotificationActionButton(id: "start_reset", text: "Reset Now"),
                NotificationActionButton(id: "skip", text: "Skip")
            ]
        case .balanceMaintenance:
            return [
                NotificationActionButton(id: "start_balance", text: "Find Balance"),
                NotificationActionButton(id: "remind_later", text: "Remind Later")
            ]
        case .breathingExercise:
            return [
                NotificationActionButton(id: "start_breathing", text: "Start Breathing"),
                NotificationActionButton(id: "remind_later", text: "Remind Later")
            ]
        case .voiceGuidedMeditation:
            return [
                NotificationActionButton(id: "start_meditation", text: "Start Meditation"),
                NotificationActionButton(id: "remind_later", text: "Remind Later")
            ]
        }
    }
    
    private func getConfidenceModifier(_ confidence: Double) -> String {
        if confidence >= 0.9 {
            return "✨"
        } else if confidence >= 0.7 {
            return "💫"
        } else {
            return "🌟"
        }
    }
    
    private func getInterventionCallToAction(_ intervention: OneSignaInterventionType) -> String {
        switch intervention {
        case .gratitudePractice:
            return "Tap to start your gratitude practice."
        case .selfCompassionBreak:
            return "Take a moment for self-compassion."
        case .coolingBreath:
            return "Let's practice some cooling breaths."
        case .groundingExercise:
            return "Ground yourself with this exercise."
        case .mindfulnessCheck:
            return "Take a mindful moment to check in."
        case .emotionalReset:
            return "Reset your emotional state now."
        case .balanceMaintenance:
            return "Find your emotional balance."
        case .breathingExercise:
            return "Practice mindful breathing."
        case .voiceGuidedMeditation:
            return "Start a guided meditation."
        }
    }
    
    private func schedulePredictiveInterventionsFromPatterns(_ patterns: EmotionalPatterns) async {
        // Schedule notifications based on predicted emotional patterns
        for time in patterns.optimalInterventionTimes {
            let intervention = getOptimalIntervention(for: patterns.primaryEmotion)
            let notification = EmotionTriggeredNotification(
                emotion: patterns.primaryEmotion,
                interventionType: intervention,
                scheduledTime: time,
                personalizationData: generatePersonalizedContent(
                    emotion: patterns.primaryEmotion,
                    confidence: patterns.confidence,
                    intervention: intervention
                )
            )
            
            await sendScheduledNotification(notification)
        }
    }
    
    // MARK: - Individual Notification Method
    
    /// Send notification to specific user (individual targeting)
    func sendIndividualNotification(_ content: NotificationContent) async {
        let notificationData: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "data": content.customData,
            "buttons": content.actionButtons?.map { button in
                ["id": button.id, "text": button.text]
            } ?? [],
            "include_player_ids": [OneSignal.User.pushSubscription.id]
            // Note: Removed filters when using include_player_ids to prevent cross-user targeting
        ]
        
        await sendNotificationViaAPI(notificationData)
    }
    
//    /// Send notification to segment (mass targeting)
//    func sendSegmentNotification(_ content: NotificationContent, segment: String) async {
//        let notificationData: [String: Any] = [
//            "app_id": config.appId,
//            "headings": ["en": content.title],
//            "contents": ["en": content.body],
//            "data": content.customData,
//            "buttons": content.actionButtons?.map { button in
//                ["id": button.id, "text": button.text]
//            } ?? [],
//            "included_segments": [segment],
//            "filters": [
//                ["field": "tag", "key": "emotion_analysis_enabled", "relation": "=", "value": "true"]
//            ]
//        ]
//
//        await sendNotificationViaAPI(notificationData)
//    }
//
//    //  Send mass campaign to all active users
//    func sendMassCampaign(_ content: NotificationContent) async {
//        await sendSegmentNotification(content, segment: "Active Users")
//    }
//
//    /// Send notification to pro subscribers
//    func sendProUserNotification(_ content: NotificationContent) async {
//        await sendSegmentNotification(content, segment: "Pro Subscribers")
//    }
//
//    /// Send notification to free users
//    func sendFreeUserNotification(_ content: NotificationContent) async {
//        await sendSegmentNotification(content, segment: "Free Users")
//    }
}

// MARK: - Supporting Models
struct EmotionTriggeredNotification {
    let emotion: EmotionType
    let interventionType: OneSignaInterventionType
    let scheduledTime: Date
    let personalizationData: NotificationContent
}

struct SpeechTriggeredNotification {
    let sentiment: String
    let keywords: [String]
    let interventionType: OneSignaInterventionType
    let personalizedContent: NotificationContent
}

struct NotificationContent {
    let title: String
    let body: String
    
    // OneSignal specific
    let actionButtons: [NotificationActionButton]?
    let customData: [String: String]
    
    // iOS Native specific
    let categoryIdentifier: String
    let sound: UNNotificationSound
    let badge: Int
    let userInfo: [String: Any]
}


struct NotificationActionButton {
    let id: String
    let text: String
}

struct EmotionalPatterns {
    let primaryEmotion: EmotionType
    let confidence: Double
    let optimalInterventionTimes: [Date]
    let preferredInterventions: [OneSignaInterventionType]
}

enum OneSignaInterventionType: String, CaseIterable {
    case gratitudePractice = "gratitude_practice"
    case selfCompassionBreak = "self_compassion_break"
    case coolingBreath = "cooling_breath"
    case groundingExercise = "grounding_exercise"
    case mindfulnessCheck = "mindfulness_check"
    case emotionalReset = "emotional_reset"
    case balanceMaintenance = "balance_maintenance"
    case breathingExercise = "breathing_exercise"
    case voiceGuidedMeditation = "voice_guided_meditation"
}

// MARK: - Analytics
class NotificationAnalytics: ObservableObject {
    @Published var notificationsSent: Int = 0
    @Published var notificationReceived: Int = 0
    @Published var notificationOpened: Int = 0
    @Published var interventionsTriggered: Int = 0
    
    private var dailyNotificationCounts: [Date: Int] = [:]
    
    func getNotificationCount(since date: Date) -> Int {
        return dailyNotificationCounts[date] ?? 0
    }
    
    func recordNotificationSent() {
        notificationsSent += 1
        let today = Calendar.current.startOfDay(for: Date())
        dailyNotificationCounts[today, default: 0] += 1
    }
}

// MARK: - Notification Extensions
// MARK: - Notification History Integration

private func saveNotificationToHistory(_ data: [String: Any]) async {
    guard let headings = data["headings"] as? [String: String],
          let contents = data["contents"] as? [String: String],
          let title = headings["en"],
          let body = contents["en"] else {

        return
    }
    
    // Determine notification type from data
    let notificationType = determineNotificationType(from: data)
    let emotion = extractEmotion(from: data)
    let intervention = extractIntervention(from: data)
    let customData = extractCustomData(from: data)
    let priority = determinePriority(from: data)
    
    // Create and save notification to history
    let historyItem = NotificationHistoryItem(
        title: title,
        body: body,
        type: notificationType,
        emotion: emotion,
        intervention: intervention,
        customData: customData,
        priority: priority
    )
    
    await NotificationHistoryManager.shared.addNotification(historyItem)
    
}

// MARK: - Local Notification History Saving
private func saveLocalNotificationToHistory(_ notification: UNNotification) async {
    let content = notification.request.content
    let userInfo = content.userInfo
    
    // Extract notification data
    let title = content.title
    let body = content.body
    let categoryIdentifier = content.categoryIdentifier ?? ""
    
    // Determine notification type from category or userInfo
    let notificationType = determineLocalNotificationType(from: categoryIdentifier, userInfo: userInfo)
    let emotion = extractEmotionFromUserInfo(userInfo)
    let intervention = extractInterventionFromUserInfo(userInfo)
    let customData = extractCustomDataFromUserInfo(userInfo)
    let priority = determineLocalNotificationPriority(from: categoryIdentifier)
    
    // Create and save notification to history
    let historyItem = NotificationHistoryItem(
        title: title,
        body: body,
        type: notificationType,
        emotion: emotion,
        intervention: intervention,
        customData: customData,
        priority: priority
    )
    
    await NotificationHistoryManager.shared.addNotification(historyItem)
    
}

private func determineLocalNotificationType(from categoryIdentifier: String, userInfo: [AnyHashable: Any]) -> NotificationHistoryType {
    // Check userInfo first for explicit type
    if let typeString = userInfo["type"] as? String {
        switch typeString {
        case "predictive_intervention":
            return .predictiveIntervention
        case "achievement":
            return .achievement
        case "goal_completion":
            return .achievement
        case "reminder":
            return .reminder
        default:
            break
        }
    }
    
    // Fallback to category identifier
    switch categoryIdentifier {
    case "emotion_checkin":
        return .predictiveIntervention
    case "ACHIEVEMENT":
        return .achievement
    case "GOAL_COMPLETION":
        return .achievement
    case "DAILY_CHECKIN":
        return .dailyCheckIn
    default:
        return .reminder
    }
}

private func extractEmotionFromUserInfo(_ userInfo: [AnyHashable: Any]) -> EmotionType? {
    guard let emotionString = userInfo["emotion"] as? String else { return nil }
    return EmotionType(rawValue: emotionString)
}

private func extractInterventionFromUserInfo(_ userInfo: [AnyHashable: Any]) -> OneSignaInterventionType? {
    guard let interventionString = userInfo["intervention"] as? String else { return nil }
    return OneSignaInterventionType(rawValue: interventionString)
}

private func extractCustomDataFromUserInfo(_ userInfo: [AnyHashable: Any]) -> [String: String]? {
    var customData: [String: String] = [:]
    
    for (key, value) in userInfo {
        if let stringKey = key as? String, let stringValue = value as? String {
            customData[stringKey] = stringValue
        }
    }
    
    return customData.isEmpty ? nil : customData
}

private func determineLocalNotificationPriority(from categoryIdentifier: String) -> NotificationPriority {
    switch categoryIdentifier {
    case "ACHIEVEMENT", "GOAL_COMPLETION":
        return .high
    case "emotion_checkin":
        return .high
    case "DAILY_CHECKIN":
        return .medium
    default:
        return .medium
    }
}

private func determineNotificationType(from data: [String: Any]) -> NotificationHistoryType {
    if let customData = data["data"] as? [String: Any] {
        if let notificationType = customData["notification_type"] as? String {
            switch notificationType {
            case "welcome":
                return .welcome
            case "emotion_triggered":
                return .emotionTriggered
            case "predictive_intervention":
                return .predictiveIntervention
            case "daily_checkin":
                return .dailyCheckIn
            case "achievement":
                return .achievement
            case "goal_completion":
                return .achievement
            default:
                return .campaign
            }
        }
        
        if let campaignType = customData["campaign_type"] as? String {
            switch campaignType {
            case "emotion_triggered":
                return .emotionTriggered
            case "predictive_intervention":
                return .predictiveIntervention
            case "daily_checkin":
                return .dailyCheckIn
            case "achievement", "goal_completion":
                return .achievement
            default:
                return .campaign
            }
        }
    }
    
    // Default fallback based on content
    if let title = (data["headings"] as? [String: String])?["en"] {
        if title.contains("Welcome") {
            return .welcome
        } else if title.contains("Check-in") || title.contains("Reflection") {
            return .dailyCheckIn
        } else if title.contains("Achievement") || title.contains("Goal") {
            return .achievement
        }
    }
    
    return .campaign
}

private func extractEmotion(from data: [String: Any]) -> EmotionType? {
    if let customData = data["data"] as? [String: Any],
       let emotionString = customData["emotion"] as? String {
        return EmotionType(rawValue: emotionString)
    }
    return nil
}

private func extractIntervention(from data: [String: Any]) -> OneSignaInterventionType? {
    if let customData = data["data"] as? [String: Any],
       let interventionString = customData["intervention_type"] as? String {
        return OneSignaInterventionType(rawValue: interventionString)
    }
    return nil
}

private func extractCustomData(from data: [String: Any]) -> [String: String]? {
    if let customData = data["data"] as? [String: Any] {
        return customData.compactMapValues { value in
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            }
            return nil
        }
    }
    return nil
}

private func determinePriority(from data: [String: Any]) -> NotificationPriority {
    if let priority = data["priority"] as? String {
        switch priority {
        case "high":
            return .high
        case "low":
            return .low
        default:
            return .medium
        }
    }
    return .medium
}


extension Notification.Name {
    static let speechAnalysisCompleted = Notification.Name("speechAnalysisCompleted")
    static let deepLinkToIntervention = Notification.Name("deepLinkToIntervention")
}

