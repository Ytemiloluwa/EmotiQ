//  SmartNotificationScheduler.swift
//  EmotiQ
//
//  Created by Temiloluwa on 25-08-2025.
//
//
import Foundation
import UserNotifications
import CoreML
import Combine
import UIKit
import OneSignalFramework
import CoreData

// MARK: - Smart Notification Scheduler
@MainActor
class SmartNotificationScheduler: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var scheduledNotifications: [ScheduledNotification] = []
    @Published var notificationAnalytics: SchedulerAnalytics = SchedulerAnalytics()
    @Published var isOptimizing = false
    @Published var lastOptimizationDate: Date?
    
    // MARK: - Private Properties
    private let behaviorAnalyzer = UserBehaviorAnalyzer()
    private let interventionPredictor = EmotionalInterventionPredictor()
    private let hapticManager = HapticManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private struct config {
        // Removed notification limits - no maximum daily notifications or minimum intervals
        static let appId = Config.oneSignalAppID
        static let optimizationInterval: TimeInterval = 86400 // Daily optimization
        static let engagementTrackingWindow: TimeInterval = 86400 * 7 // 1 week
        static let defaultSendTimeHour = 9 // 9 AM
        static let quietHoursStart = 22 // 10 PM
        static let quietHoursEnd = 7 // 7 AM
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupNotificationCenter()
        setupBehaviorTracking()
        scheduleOptimization()
        loadScheduledNotifications()
        
        // Schedule reminders for active goals on app start
        Task {
            await scheduleRemindersForActiveGoals()
        }
    }
    
    // MARK: - Setup Methods
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            Task { @MainActor in
                if granted {
                    self.setupNotificationCategories()
                } else if let error = error {
                
                }
            }
        }
    }
    
    private func setupNotificationCategories() {
        let categories = createNotificationCategories()
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
    }
    
    private func createNotificationCategories() -> [UNNotificationCategory] {
        // Welcome notification category - Enhanced for persistence
        let welcomeCategory = UNNotificationCategory(
            identifier: "WELCOME",
            actions: [
                UNNotificationAction(identifier: "start_analysis", title: "Start Voice Analysis", options: [.foreground]),
                UNNotificationAction(identifier: "explore_app", title: "Explore App", options: [.foreground])
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Emotion-based intervention category
        let emotionInterventionCategory = UNNotificationCategory(
            identifier: "EMOTION_INTERVENTION",
            actions: [
                UNNotificationAction(identifier: "START_INTERVENTION", title: "Start Session", options: [.foreground]),
                UNNotificationAction(identifier: "REMIND_LATER", title: "Remind Later", options: []),
                UNNotificationAction(identifier: "SKIP", title: "Skip", options: [])
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Daily check-in category
        let dailyCheckInCategory = UNNotificationCategory(
            identifier: "DAILY_CHECKIN",
            actions: [
                UNNotificationAction(identifier: "QUICK_CHECKIN", title: "Quick Check-in", options: [.foreground]),
                UNNotificationAction(identifier: "VOICE_ANALYSIS", title: "Voice Analysis", options: [.foreground]),
                UNNotificationAction(identifier: "LATER", title: "Later", options: [])
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Achievement celebration category
        let achievementCategory = UNNotificationCategory(
            identifier: "ACHIEVEMENT",
            actions: [
                UNNotificationAction(identifier: "VIEW_PROGRESS", title: "View Progress", options: [.foreground]),
                UNNotificationAction(identifier: "SHARE", title: "Share", options: []),
                UNNotificationAction(identifier: "CONTINUE", title: "Continue", options: [.foreground])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        // Goal completion celebration category
        let goalCompletionCategory = UNNotificationCategory(
            identifier: "GOAL_COMPLETION",
            actions: [
                UNNotificationAction(identifier: "VIEW_GOALS", title: "View Goals", options: [.foreground]),
                UNNotificationAction(identifier: "SET_NEW_GOAL", title: "Set New Goal", options: [.foreground]),
                UNNotificationAction(identifier: "CONTINUE", title: "Continue", options: [.foreground])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        // Goal progress reminder category
        let goalReminderCategory = UNNotificationCategory(
            identifier: "GOAL_REMINDER",
            actions: [
                UNNotificationAction(identifier: "update_progress", title: "Update Progress", options: [.foreground]),
                UNNotificationAction(identifier: "view_goal", title: "View Goal", options: [.foreground]),
                UNNotificationAction(identifier: "remind_later", title: "Remind Later", options: [])
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        return [welcomeCategory, emotionInterventionCategory, dailyCheckInCategory, achievementCategory, goalCompletionCategory, goalReminderCategory]
    }
    
    private func setupBehaviorTracking() {
        // Track notification engagement
        NotificationCenter.default.publisher(for: .notificationOpened)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.trackNotificationEngagement(notification)
                }
            }
            .store(in: &cancellables)
        
        // Track app usage patterns
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.trackAppUsage()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Smart Scheduling Methods
    func scheduleEmotionTriggeredNotification(
        emotion: EmotionType,
        intervention: OneSignaInterventionType,
        delay: TimeInterval = 0
    ) async {
        
        let optimalTime = await calculateOptimalSendTime(
            for: emotion,
            intervention: intervention,
            baseDelay: delay
        )
        
        let content = generateEmotionContent(emotion: emotion, intervention: intervention)
        let personalizationData = await generatePersonalizationData(emotion: emotion)
        
        // Convert to OneSignal API format
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "buttons": content.actionButtons?.map { button in
                ["id": button.id, "text": button.text]
            } ?? [],
            "data": [
                "type": "emotion_triggered",
                "emotion": emotion.rawValue,
                "intervention": intervention.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "scheduled_time": ISO8601DateFormatter().string(from: optimalTime)
            ].merging(content.customData) { _, new in new },
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""],
            "send_after": ISO8601DateFormatter().string(from: optimalTime)
        ]
        
        // Send via OneSignal API
        await OneSignalService.shared.sendNotificationViaAPI(data)
        
      
    }
    
    func schedulePredictiveIntervention(
        prediction: EmotionalPrediction
    ) async {
        
        let optimalTime = await optimizePredictiveTime(
            basedOn: prediction,
            userBehavior: await behaviorAnalyzer.getCurrentBehaviorPattern()
        )
        
        let content = generatePredictiveContent(prediction: prediction)
        let personalizationData = await generatePersonalizationData(emotion: prediction.predictedEmotion)
        
        // Check if scheduling is within OneSignal's 24-hour limit
        let timeUntilScheduled = optimalTime.timeIntervalSince(Date())
        guard timeUntilScheduled > 0 && timeUntilScheduled <= 86400 else {

            return
        }
        
        // Convert to OneSignal API format
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "buttons": content.actionButtons?.map { button in
                ["id": button.id, "text": button.text]
            } ?? [],
            "data": [
                "type": "predictive_intervention",
                "emotion": prediction.predictedEmotion.rawValue,
                "intervention": prediction.recommendedIntervention.rawValue,
                "confidence": prediction.confidence,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "scheduled_time": ISO8601DateFormatter().string(from: optimalTime)
            ].merging(content.customData) { _, new in new },
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""],
            "send_after": ISO8601DateFormatter().string(from: optimalTime)
        ]
        
        // Send via OneSignal API
        await OneSignalService.shared.sendNotificationViaAPI(data)
        
    
    }
    
    func scheduleDailyCheckIn() async {
        // Schedule for 8AM user's local timezone
        let checkInTime = await get8AMUserTime()
        
        let content = generatePersonalizedDailyCheckInContent()

        // Convert to OneSignal API format with proper timezone scheduling
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "buttons": content.actionButtons?.map { button in
                ["id": button.id, "text": button.text]
            } ?? [],
            "data": [
                "type": "daily_checkin",
                "emotion": "neutral",
                "intervention": "mindfulness_check",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "scheduled_time": ISO8601DateFormatter().string(from: checkInTime),
                "timezone": TimeZone.current.identifier,
                "personalized": "false"
            ].merging(content.customData) { _, new in new },
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""],
            "send_after": ISO8601DateFormatter().string(from: checkInTime)
        ]

        // Send via OneSignal API
        await OneSignalService.shared.sendNotificationViaAPI(data)

    }
    
    // MARK: - Streak Maintenance Reminder
    func scheduleStreakMaintenanceReminder() async {
        // Schedule for 6PM user's local timezone (evening reminder)
        let reminderTime = await get6PMUserTime()
        
        let content = generateStreakMaintenanceContent()

        // Convert to OneSignal API format
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "buttons": content.actionButtons?.map { button in
                ["id": button.id, "text": button.text]
            } ?? [],
            "data": [
                "type": "reminder",
                "reminder_type": "streak_maintenance",
                "emotion": "motivation",
                "intervention": "streak_reminder",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "scheduled_time": ISO8601DateFormatter().string(from: reminderTime),
                "timezone": TimeZone.current.identifier
            ].merging(content.customData) { _, new in new },
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""],
            "send_after": ISO8601DateFormatter().string(from: reminderTime)
        ]

        // Send via OneSignal API
        await OneSignalService.shared.sendNotificationViaAPI(data)


    }
    
    // MARK: - 8AM User Time Scheduling
    private func get8AMUserTime() async -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get today's 8AM in user's timezone
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 8
        components.minute = 0
        components.second = 0
        
        guard let today8AM = calendar.date(from: components) else {
            // Fallback to 1 hour from now if date creation fails
            return now.addingTimeInterval(3600)
        }
        
        // If 8AM has passed today, schedule for tomorrow 8AM
        if today8AM <= now {
            return calendar.date(byAdding: .day, value: 1, to: today8AM) ?? now.addingTimeInterval(3600)
        }
        
        return today8AM
    }
    
    private func get6PMUserTime() async -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get today's 6PM in user's timezone
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 18
        components.minute = 0
        components.second = 0
        
        guard let today6PM = calendar.date(from: components) else {
            // Fallback to 1 hour from now if date creation fails
            return now.addingTimeInterval(3600)
        }
        
        // If 6PM has passed today, schedule for tomorrow 6PM
        if today6PM <= now {
            return calendar.date(byAdding: .day, value: 1, to: today6PM) ?? now.addingTimeInterval(3600)
        }
        
        return today6PM
    }
    
    private func get2PMUserTime() async -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get today's 2PM in user's timezone
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 14
        components.minute = 0
        components.second = 0
        
        guard let today2PM = calendar.date(from: components) else {
            // Fallback to 1 hour from now if date creation fails
            return now.addingTimeInterval(3600)
        }
        
        // If 2PM has passed today, schedule for tomorrow 2PM
        if today2PM <= now {
            return calendar.date(byAdding: .day, value: 1, to: today2PM) ?? now.addingTimeInterval(3600)
        }
        
        return today2PM
    }
    
    // MARK: - Personalized Timing
    private func getPersonalizedCheckInTime() async -> Date {
        let behaviorPattern = await behaviorAnalyzer.getCurrentBehaviorPattern()
        let calendar = Calendar.current
        let now = Date()
        
        // Get user's preferred app usage hours
        let preferredHours = behaviorPattern.averageAppUsageHours.isEmpty ? [9, 12, 18] : behaviorPattern.averageAppUsageHours
        
        // Find the next optimal time based on user behavior
        let nextOptimalHour = findNextOptimalHour(from: now, preferredHours: preferredHours)
        
        // Get today's optimal time
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = nextOptimalHour
        components.minute = 0
        components.second = 0
        
        let todayOptimalTime = calendar.date(from: components)!
        
        // If it's already past the optimal time today, schedule for tomorrow
        if now > todayOptimalTime {
            return calendar.date(byAdding: .day, value: 1, to: todayOptimalTime)!
        } else {
            return todayOptimalTime
        }
    }
    
    private func findNextOptimalHour(from date: Date, preferredHours: [Int]) -> Int {
        let currentHour = Calendar.current.component(.hour, from: date)
        
        // Find the next preferred hour
        for hour in preferredHours.sorted() {
            if hour > currentHour {
                return hour
            }
        }
        
        // If no preferred hour is later today, use the first preferred hour tomorrow
        return preferredHours.min() ?? 9
    }
    
    private func generatePersonalizedDailyCheckInContent() -> NotificationContent {
        let personalizedMessages = [
            ("🌅 Good morning! Time for your check-in", "How are you feeling today? Let's start your day with emotional awareness."),
            ("💫 Your daily emotional check-in awaits", "Take a moment to connect with your feelings and set your emotional intention."),
            ("🌟 Ready for your mindful moment?", "Your personalized emotional wellness check-in is here. How are you doing?"),
            ("🎯 Daily emotional check-in time", "Let's check in with your emotional state and continue your growth journey.")
        ]
        
        let randomMessage = personalizedMessages.randomElement()!
        
        return NotificationContent(
            title: randomMessage.0,
            body: randomMessage.1,
            actionButtons: [
                NotificationActionButton(id: "quick_checkin", text: "Quick Check-in"),
                NotificationActionButton(id: "voice_analysis", text: "Voice Analysis"),
                NotificationActionButton(id: "mindfulness", text: "Mindfulness")
            ],
            customData: [
                "personalized": "true",
                "checkin_type": "daily_personalized"
            ],
            categoryIdentifier: "DAILY_CHECKIN",
            sound: .default,
            badge: 1,
            userInfo: [:]
        )
    }
    
    private func calculateNext9AM() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get today's 9 AM
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 9
        components.minute = 0
        components.second = 0
        
        let today9AM = calendar.date(from: components)!
        
        // If it's already past 9 AM today, schedule for tomorrow 9 AM
        if now > today9AM {
            return calendar.date(byAdding: .day, value: 1, to: today9AM)!
        } else {
            return today9AM
        }
    }
    
    func scheduleAchievementCelebration(
        achievement: Achievement,
        delay: TimeInterval = 300 // 5 minutes delay
    ) async {
        
        let celebrationTime = Date().addingTimeInterval(delay)
        
        let content = generateAchievementContent(achievement: achievement)
        let personalizationData = await generatePersonalizationData(emotion: .joy)
        
        // Convert to OneSignal API format
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "buttons": content.actionButtons?.map { button in
                ["id": button.id, "text": button.text]
            } ?? [],
            "data": [
                "type": "achievement",
                "emotion": "joy",
                "intervention": "gratitude_practice",
                "achievement_id": achievement.id,
                "achievement_type": achievement.type.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "scheduled_time": ISO8601DateFormatter().string(from: celebrationTime)
            ].merging(content.customData) { _, new in new },
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""],
            "send_after": ISO8601DateFormatter().string(from: celebrationTime)
        ]
        
        // Send via OneSignal API
        await OneSignalService.shared.sendNotificationViaAPI(data)
        
    
    }
    
    // MARK: - Goal Progress Reminders
    func scheduleGoalProgressReminder(for goal: GoalEntity) async {
        // Check if goal has reminder enabled and is not completed
        guard goal.reminderEnabled && !goal.isCompleted else { return }
        
        // Schedule for 2PM user's local timezone (afternoon reminder)
        let reminderTime = await get2PMUserTime()
        
        let content = generateGoalProgressReminderContent(for: goal)
        
        // Convert to OneSignal API format
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": content.title],
            "contents": ["en": content.body],
            "buttons": content.actionButtons?.map { button in
                ["id": button.id, "text": button.text]
            } ?? [],
            "data": [
                "type": "reminder",
                "reminder_type": "goal_progress",
                "goal_id": goal.id?.uuidString ?? "",
                "goal_title": goal.title ?? "Your Goal",
                "goal_category": goal.category ?? "personal",
                "current_progress": String(goal.progress),
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "scheduled_time": ISO8601DateFormatter().string(from: reminderTime),
                "timezone": TimeZone.current.identifier
            ].merging(content.customData) { _, new in new },
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""],
            "send_after": ISO8601DateFormatter().string(from: reminderTime)
        ]
        
        // Send via OneSignal API
        await OneSignalService.shared.sendNotificationViaAPI(data)
        
       
    }
    
    // MARK: - Goal Reminder Management
    func scheduleRemindersForActiveGoals() async {
        // Get all active goals with reminders enabled
        let activeGoals = await getActiveGoalsWithReminders()
        
        for goal in activeGoals {
            await scheduleGoalProgressReminder(for: goal)
        }
        
    }
    
    func scheduleReminderForGoal(_ goal: GoalEntity) async {
        // Schedule reminder for a specific goal
        await scheduleGoalProgressReminder(for: goal)
  
    }
    
    func cancelRemindersForGoal(_ goalId: UUID) async {
        // Cancel existing reminders for a specific goal
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        let goalReminders = pendingRequests.filter { request in
            if let userInfo = request.content.userInfo as? [String: Any],
               let reminderGoalId = userInfo["goal_id"] as? String {
                return UUID(uuidString: reminderGoalId) == goalId
            }
            return false
        }
        
        let identifiers = goalReminders.map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        

    }
    
    private func getActiveGoalsWithReminders() async -> [GoalEntity] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        
        // Fetch goals that have reminders enabled and are not completed
        request.predicate = NSPredicate(format: "reminderEnabled == YES AND isCompleted == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GoalEntity.createdAt, ascending: false)]
        
        do {
            let goals = try context.fetch(request)
          
            return goals
        } catch {
           
            return []
        }
    }
    
    private func getPersonalizedGoalReminderTime(for goal: GoalEntity) async -> Date {
        let behaviorPattern = await behaviorAnalyzer.getCurrentBehaviorPattern()
        let calendar = Calendar.current
        let now = Date()
        
        // Use goal's custom reminder time if set, otherwise use behavior-based timing
        if let customReminderTime = goal.reminderTime {
            let customHour = calendar.component(.hour, from: customReminderTime)
            let customMinute = calendar.component(.minute, from: customReminderTime)
            
            // Get today's custom time
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = customHour
            components.minute = customMinute
            components.second = 0
            
            let todayCustomTime = calendar.date(from: components)!
            
            // If it's already past the custom time today, schedule for tomorrow
            if now > todayCustomTime {
                return calendar.date(byAdding: .day, value: 1, to: todayCustomTime)!
            } else {
                return todayCustomTime
            }
        } else {
            // Use behavior-based timing (preferred app usage hours)
            let preferredHours = behaviorPattern.averageAppUsageHours.isEmpty ? [10, 14, 19] : behaviorPattern.averageAppUsageHours
            let nextOptimalHour = findNextOptimalHour(from: now, preferredHours: preferredHours)
            
            // Get today's optimal time
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = nextOptimalHour
            components.minute = 30 // 30 minutes past the hour for variety
            components.second = 0
            
            let todayOptimalTime = calendar.date(from: components)!
            
            // If it's already past the optimal time today, schedule for tomorrow
            if now > todayOptimalTime {
                return calendar.date(byAdding: .day, value: 1, to: todayOptimalTime)!
            } else {
                return todayOptimalTime
            }
        }
    }
    
    private func generateGoalProgressReminderContent(for goal: GoalEntity) -> NotificationContent {
        let goalTitle = goal.title ?? "Your Goal"
        let progress = Int(goal.progress * 100)
        let category = goal.category ?? "personal"
        
        let progressMessages = [
            ("🎯 Your goal '\(goalTitle)' awaits", "You're \(progress)% there! Keep the momentum going."),
            ("💪 Don't forget '\(goalTitle)'", "You've made great progress (\(progress)%). Time to take the next step!"),
            ("🌟 '\(goalTitle)' progress check", "You're doing amazing! \(progress)% complete. Ready for more?"),
            ("🚀 Keep pushing towards '\(goalTitle)'", "You're \(progress)% of the way there. Every step counts!")
        ]
        
        let randomMessage = progressMessages.randomElement()!
        
        return NotificationContent(
            title: randomMessage.0,
            body: randomMessage.1,
            actionButtons: [
                NotificationActionButton(id: "update_progress", text: "Update Progress"),
                NotificationActionButton(id: "view_goal", text: "View Goal"),
                NotificationActionButton(id: "remind_later", text: "Remind Later")
            ],
            customData: [
                "goal_id": goal.id?.uuidString ?? "",
                "goal_category": category,
                "current_progress": String(progress)
            ],
            categoryIdentifier: "GOAL_REMINDER",
            sound: .default,
            badge: 1,
            userInfo: [:]
        )
    }
    
    func scheduleGoalCompletionCelebration(
        goal: GoalEntity,
        delay: TimeInterval = 30 // 30 seconds delay
    ) async {
       
        
        // Send goal completion notification via OneSignal API to ensure it's saved to history
        let goalTitle = goal.title ?? "Your Goal"
        let goalCategory = goal.category ?? "personal"
        
        let celebrationMessages = [
            ("🎯 Goal Achieved!", "Congratulations! You've completed '\(goalTitle)'. Your dedication is inspiring!"),
            ("🌟 Mission Accomplished", "You did it! '\(goalTitle)' is now complete. Time to celebrate your success!"),
            ("🏆 Goal Completed", "Amazing work! You've successfully achieved '\(goalTitle)'. Keep up the momentum!"),
            ("✨ Achievement Unlocked", "Fantastic! '\(goalTitle)' is done. Your emotional growth journey continues!")
        ]
        
        let randomMessage = celebrationMessages.randomElement()!
        
        let data: [String: Any] = [
            "app_id": config.appId,
            "headings": ["en": randomMessage.0],
            "contents": ["en": randomMessage.1],
            "buttons": [
                ["id": "view_goals", "text": "View Goals"],
                ["text": "Set New Goal", "id": "set_new_goal"]
            ],
            "data": [
                "type": "goal_completion",
                "goal_id": goal.id?.uuidString ?? "",
                "goal_title": goalTitle,
                "goal_category": goalCategory,
                "campaign_type": "goal_completion",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            "include_player_ids": [OneSignal.User.pushSubscription.id ?? ""]
        ]
        
        // Send via OneSignal API with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task {
                await OneSignalService.shared.sendNotificationViaAPI(data)
            }
        }
    }
    
    // MARK: - Missing Methods Implementation
    
    private func calculatePriority(for emotion: EmotionType) -> NotificationPriority {
        switch emotion {
        case .sadness, .anger, .fear:
            return .high // High priority for negative emotions
        case .joy, .surprise:
            return .medium // Medium priority for positive emotions
        case .disgust, .neutral:
            return .low // Low priority for neutral emotions
        }
    }
    
    private func optimizePredictiveTime(
        basedOn prediction: EmotionalPrediction,
        userBehavior: UserBehaviorPattern
    ) async -> Date {
        
        let calendar = Calendar.current
        let currentTime = Date()
        
        // Use ML prediction if available and valid (regardless of confidence)
        if prediction.optimalTime > currentTime {
            return prediction.optimalTime
        }
        
        // Fallback to behavioral analysis
        let optimalHour = findOptimalHourFromBehavior(userBehavior, for: prediction.predictedEmotion)
        
        // Schedule for next occurrence of optimal hour
        var components = calendar.dateComponents([.year, .month, .day], from: currentTime)
        components.hour = optimalHour
        components.minute = 0
        components.second = 0
        
        guard let targetTime = calendar.date(from: components) else {
            return currentTime.addingTimeInterval(3600) // 1 hour fallback
        }
        
        // If optimal hour has passed today, schedule for tomorrow
        if targetTime <= currentTime {
            return calendar.date(byAdding: .day, value: 1, to: targetTime) ?? currentTime.addingTimeInterval(3600)
        }
        
        return targetTime
    }
    
    private func calculateOptimalCheckInTime() async -> Date {
        let calendar = Calendar.current
        let currentTime = Date()
        
        // Get user behavior patterns
        let behaviorPattern = await behaviorAnalyzer.getCurrentBehaviorPattern()
        
        // Find the most active hour from behavior data
        let optimalHour = findMostActiveHour(from: behaviorPattern)
        
        // Schedule for today if optimal hour hasn't passed
        var components = calendar.dateComponents([.year, .month, .day], from: currentTime)
        components.hour = optimalHour
        components.minute = 0
        components.second = 0
        
        guard let targetTime = calendar.date(from: components) else {
            return currentTime.addingTimeInterval(3600) // 1 hour fallback
        }
        
        // If optimal hour has passed today, schedule for tomorrow
        if targetTime <= currentTime {
            return calendar.date(byAdding: .day, value: 1, to: targetTime) ?? currentTime.addingTimeInterval(3600)
        }
        
        return targetTime
    }
    
    private func findOptimalHourFromBehavior(_ behavior: UserBehaviorPattern, for emotion: EmotionType) -> Int {
        // Use emotional peak times if available
        if !behavior.emotionalPeakTimes.isEmpty {
            return behavior.emotionalPeakTimes.first ?? config.defaultSendTimeHour
        }
        
        // Use average app usage hours
        if !behavior.averageAppUsageHours.isEmpty {
            return behavior.averageAppUsageHours.first ?? config.defaultSendTimeHour
        }
        
        return config.defaultSendTimeHour
    }
    
    private func findMostActiveHour(from behavior: UserBehaviorPattern) -> Int {
        // Use average app usage hours for check-in timing
        if !behavior.averageAppUsageHours.isEmpty {
            return behavior.averageAppUsageHours.first ?? config.defaultSendTimeHour
        }
        
        return config.defaultSendTimeHour
    }
    
    // MARK: - Optimal Timing Calculation
    private func calculateOptimalSendTime(
        for emotion: EmotionType,
        intervention: OneSignaInterventionType,
        baseDelay: TimeInterval
    ) async -> Date {
        
        let baseTime = Date().addingTimeInterval(baseDelay)
        
        // Get user behavior patterns
        let behaviorPattern = await behaviorAnalyzer.getCurrentBehaviorPattern()
        
        // Use ML to predict optimal time if available
        if let mlOptimalTime = await interventionPredictor.predictOptimalInterventionTime(
            for: emotion,
            userBehaviorPattern: behaviorPattern
        ) {
            return mlOptimalTime
        }
        
        // Fallback to rule-based optimization
        return optimizeTimeRuleBased(
            baseTime: baseTime,
            emotion: emotion,
            intervention: intervention,
            behaviorPattern: behaviorPattern
        )
    }
    
    private func optimizeTimeRuleBased(
        baseTime: Date,
        emotion: EmotionType,
        intervention: OneSignaInterventionType,
        behaviorPattern: UserBehaviorPattern
    ) -> Date {
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: baseTime)
        
        // Avoid quiet hours
        if hour >= config.quietHoursStart || hour < config.quietHoursEnd {
            // Schedule for next morning
            var components = calendar.dateComponents([.year, .month, .day], from: baseTime)
            components.hour = config.defaultSendTimeHour
            components.minute = 0
            components.second = 0
            
            if let nextMorning = calendar.date(from: components) {
                return nextMorning > baseTime ? nextMorning : calendar.date(byAdding: .day, value: 1, to: nextMorning)!
            }
        }
        
        // Optimize based on emotion type
        let optimalHour = getOptimalHourForEmotion(emotion)
        
        // If we're past the optimal hour today, schedule for tomorrow
        if hour > optimalHour {
            var components = calendar.dateComponents([.year, .month, .day], from: baseTime)
            components.hour = optimalHour
            components.minute = 0
            components.second = 0
            
            if let optimizedTime = calendar.date(from: components) {
                return calendar.date(byAdding: .day, value: 1, to: optimizedTime)!
            }
        }
        
        // Adjust to optimal hour today
        var components = calendar.dateComponents([.year, .month, .day, .minute, .second], from: baseTime)
        components.hour = optimalHour
        
        return calendar.date(from: components) ?? baseTime
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
    
    // MARK: - Content Generation
    private func generateEmotionContent(emotion: EmotionType, intervention: OneSignaInterventionType) -> NotificationContent {
        let (title, body) = getEmotionSpecificContent(emotion: emotion, intervention: intervention)
        
        return NotificationContent(
            title: title,
            body: body,
            actionButtons: getActionButtons(for: intervention),
            customData: [
                "emotion": emotion.rawValue,
                "intervention": intervention.rawValue,
                "type": "emotion_triggered"
            ],
            categoryIdentifier: "EMOTION_INTERVENTION",
            sound: getEmotionSpecificSound(emotion),
            badge: 1,
            userInfo: [
                "emotion": emotion.rawValue,
                "intervention": intervention.rawValue,
                "type": "emotion_triggered"
            ]
        )
    }
    
    private func generatePredictiveContent(prediction: EmotionalPrediction) -> NotificationContent {
        let (title, body) = getPredictiveContent(prediction: prediction)
        
        return NotificationContent(
            title: title,
            body: body,
            actionButtons: getActionButtons(for: prediction.recommendedIntervention),
            customData: [
                "emotion": prediction.predictedEmotion.rawValue,
                "intervention": prediction.recommendedIntervention.rawValue,
                "type": "predictive_intervention",
                "confidence": String(prediction.confidence)
            ],
            categoryIdentifier: "EMOTION_INTERVENTION",
            sound: .default,
            badge: 1,
            userInfo: [
                "emotion": prediction.predictedEmotion.rawValue,
                "intervention": prediction.recommendedIntervention.rawValue,
                "type": "predictive_intervention",
                "confidence": String(prediction.confidence)
            ]
        )
    }
    
    private func generateStreakMaintenanceContent() -> NotificationContent {
        let streakMessages = [
            ("🔥 Don't lose your streak!", "You've been doing great! Don't let your emotional wellness journey slip away."),
            ("💪 Keep the momentum!", "Your consistency is inspiring. Let's continue your emotional growth journey!"),
            ("🌟 You're on fire!", "Don't break your amazing streak! Your emotional wellness matters."),
            ("🎯 Stay consistent!", "You've built something beautiful. Keep nurturing your emotional growth!")
        ]
        
        let randomMessage = streakMessages.randomElement()!
        
        return NotificationContent(
            title: randomMessage.0,
            body: randomMessage.1,
            actionButtons: [
                NotificationActionButton(id: "continue_streak", text: "Continue Streak"),
                NotificationActionButton(id: "voice_check", text: "Voice Check"),
                NotificationActionButton(id: "remind_later", text: "Remind Later")
            ],
            customData: [
                "type": "reminder",
                "reminder_type": "streak_maintenance",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            categoryIdentifier: "STREAK_REMINDER",
            sound: .default,
            badge: 1,
            userInfo: [
                "type": "reminder",
                "reminder_type": "streak_maintenance",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }
    
    private func generateDailyCheckInContent() -> NotificationContent {
        let checkInMessages = [
            ("🌅 Morning Check-in", "How are you feeling today? Let's start with a quick emotional check-in."),
            ("💫 Daily Reflection", "Take a moment to connect with your emotions. Your wellbeing matters."),
            ("🎯 Emotional Awareness", "Ready to explore your emotional landscape today?"),
            ("🌱 Growth Moment", "Every check-in is a step toward greater emotional intelligence.")
        ]
        
        let randomMessage = checkInMessages.randomElement()!
        
        return NotificationContent(
            title: randomMessage.0,
            body: randomMessage.1,
            actionButtons: [
                NotificationActionButton(id: "start_checkin", text: "Start Check-in"),
                NotificationActionButton(id: "remind_later", text: "Remind Later")
            ],
            customData: [
                "type": "daily_checkin",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            categoryIdentifier: "DAILY_CHECKIN",
            sound: .default,
            badge: 1,
            userInfo: [
                "type": "daily_checkin",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }
    
    private func generateAchievementContent(achievement: Achievement) -> NotificationContent {
        return NotificationContent(
            title: "🎉 \(achievement.title)",
            body: achievement.description,
            actionButtons: [
                NotificationActionButton(id: "view_achievement", text: "View Achievement"),
                NotificationActionButton(id: "share", text: "Share")
            ],
            customData: [
                "type": "achievement",
                "achievement_id": achievement.id,
                "achievement_type": achievement.type.rawValue
            ],
            categoryIdentifier: "ACHIEVEMENT",
            sound: .default,
            badge: 1,
            userInfo: [
                "type": "achievement",
                "achievement_id": achievement.id,
                "achievement_type": achievement.type.rawValue
            ]
        )
    }
    
    private func generateGoalCompletionContent(goal: GoalEntity) -> NotificationContent {
        let goalTitle = goal.title ?? "Your Goal"
        let goalCategory = goal.category ?? "personal"
        
        let celebrationMessages = [
            ("🎯 Goal Achieved!", "Congratulations! You've completed '\(goalTitle)'. Your dedication is inspiring!"),
            ("🌟 Mission Accomplished", "You did it! '\(goalTitle)' is now complete. Time to celebrate your success!"),
            ("🏆 Goal Completed", "Amazing work! You've successfully achieved '\(goalTitle)'. Keep up the momentum!"),
            ("✨ Achievement Unlocked", "Fantastic! '\(goalTitle)' is done. Your emotional growth journey continues!")
        ]
        
        let randomMessage = celebrationMessages.randomElement()!
        
        return NotificationContent(
            title: randomMessage.0,
            body: randomMessage.1,
            actionButtons: [
                NotificationActionButton(id: "view_goals", text: "View Goals"),
                NotificationActionButton(id: "set_new_goal", text: "Set New Goal")
            ],
            customData: [
                "type": "goal_completion",
                "goal_id": goal.id?.uuidString ?? "",
                "goal_title": goalTitle,
                "goal_category": goalCategory
            ],
            categoryIdentifier: "GOAL_COMPLETION",
            sound: .default,
            badge: 1,
            userInfo: [
                "type": "goal_completion",
                "goal_id": goal.id?.uuidString ?? "",
                "goal_title": goalTitle,
                "goal_category": goalCategory
            ]
        )
    }
    
    private func getEmotionSpecificContent(emotion: EmotionType, intervention: OneSignaInterventionType) -> (String, String) {
        switch emotion {
        case .joy:
            return ("✨ Amplify Your Joy", "You're feeling great! Let's make this positive energy last even longer with a gratitude practice.")
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
    
    private func getPredictiveContent(prediction: EmotionalPrediction) -> (String, String) {
        let confidenceText = prediction.confidence > 0.8 ? "highly likely" : "might"
        
        switch prediction.predictedEmotion {
        case .sadness:
            return ("🔮 Proactive Support", "Based on your patterns, you \(confidenceText) need some emotional support soon. Let's prepare together.")
        case .anger:
            return ("⚡ Energy Management", "I sense you \(confidenceText) experience some intense emotions. Ready for a proactive cooling session?")
        case .fear:
            return ("🛡️ Courage Preparation", "Your patterns suggest you \(confidenceText) face some challenges. Let's build your confidence now.")
        default:
            return ("🎯 Emotional Preparation", "Based on your patterns, let's prepare for optimal emotional wellbeing.")
        }
    }
    
    private func getEmotionSpecificSound(_ emotion: EmotionType) -> UNNotificationSound {
        // Use different sounds for different emotions
        switch emotion {
        case .joy:
            return UNNotificationSound(named: UNNotificationSoundName("joy_chime.wav"))
        case .sadness:
            return UNNotificationSound(named: UNNotificationSoundName("gentle_bell.wav"))
        case .anger:
            return UNNotificationSound(named: UNNotificationSoundName("calming_tone.wav"))
        default:
            return .default
        }
    }
    
    // MARK: - Notification Scheduling
    // DEPRECATED: This method is no longer used. All notifications now go through OneSignal API
    // to ensure they are saved to notification history and prevent duplicates.
    @available(*, deprecated, message: "Use OneSignal API methods instead for proper history tracking")
    private func scheduleNotification(_ notification: ScheduledNotification) async {
    
        
        // Create UNNotificationRequest
        let content = UNMutableNotificationContent()
        content.title = notification.content.title
        content.body = notification.content.body
        content.categoryIdentifier = notification.content.categoryIdentifier
        content.sound = notification.content.sound
        content.badge = NSNumber(value: notification.content.badge)
        content.userInfo = notification.content.userInfo
        
        // Calculate time interval
        let timeInterval = notification.scheduledTime.timeIntervalSince(Date())
        guard timeInterval > 0 else {
          
            return
        }
        
        // Create trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            // Add to scheduled notifications
            scheduledNotifications.append(notification)
            
            // Update analytics
            notificationAnalytics.notificationsScheduled += 1
            
            
        } catch {
           
        }
    }
    
    // MARK: - Behavior Analysis Integration
    private func trackNotificationEngagement(_ notification: Notification) async {
        // Extract notification data
        if let userInfo = notification.userInfo as? [String: Any],
           let notificationId = userInfo["notification_id"] as? String {
            
            // Find the scheduled notification
            if let scheduledNotification = scheduledNotifications.first(where: { $0.id == notificationId }) {
                
                // Update analytics
                notificationAnalytics.notificationsOpened += 1
                
                // Track engagement by emotion type
                notificationAnalytics.trackEngagement(
                    emotion: scheduledNotification.emotion,
                    intervention: scheduledNotification.intervention,
                    timeOfDay: Calendar.current.component(.hour, from: Date())
                )
                
                // Feed data to behavior analyzer
                await behaviorAnalyzer.recordNotificationEngagement(
                    emotion: scheduledNotification.emotion,
                    intervention: scheduledNotification.intervention,
                    scheduledTime: scheduledNotification.scheduledTime,
                    actualEngagementTime: Date()
                )
            }
        }
    }
    
    private func trackNotificationDismiss(_ notification: UNNotification) async {
        // Track notification dismiss for analytics
        let userInfo = notification.request.content.userInfo
        
        // Update dismiss analytics
        notificationAnalytics.notificationDismissed += 1
        
        // Record dismiss in behavior analyzer
        if let notificationType = userInfo["notification_type"] as? String {
            await behaviorAnalyzer.recordNotificationEngagement(
                emotion: .neutral, // Default for dismiss tracking
                intervention: .mindfulnessCheck, // Default for dismiss tracking
                scheduledTime: Date(),
                actualEngagementTime: Date()
            )
        }
    }
    
    private func trackAppUsage() async {
        let currentHour = Calendar.current.component(.hour, from: Date())
        await behaviorAnalyzer.recordAppUsage(
            hour: currentHour,
            dayOfWeek: Calendar.current.component(.weekday, from: Date())
        )
    }
    
    // MARK: - Optimization
    private func scheduleOptimization() {
        Timer.scheduledTimer(withTimeInterval: config.optimizationInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.optimizeNotificationTiming()
            }
        }
    }
    
    private func optimizeNotificationTiming() async {
        isOptimizing = true
        
        // Analyze recent notification performance
        let recentPerformance = await analyzeRecentNotificationPerformance()
        
        // Update optimal timing based on performance
        await updateOptimalTimingRules(basedOn: recentPerformance)
        
        // Clean up old scheduled notifications
        await cleanupOldNotifications()
        
        lastOptimizationDate = Date()
        isOptimizing = false
        
    }
    
    private func analyzeRecentNotificationPerformance() async -> NotificationPerformanceAnalysis {
        let oneWeekAgo = Date().addingTimeInterval(-config.engagementTrackingWindow)
        
        // Analyze engagement rates by time of day, emotion, and intervention type
        let analysis = NotificationPerformanceAnalysis()
        
        // Calculate engagement rates
        for notification in scheduledNotifications {
            if notification.scheduledTime >= oneWeekAgo {
                analysis.addDataPoint(
                    hour: Calendar.current.component(.hour, from: notification.scheduledTime),
                    emotion: notification.emotion,
                    intervention: notification.intervention,
                    wasEngaged: notification.wasEngaged
                )
            }
        }
        
        return analysis
    }
    
    // MARK: - Helper Methods
    // Removed notification limit helper methods - no limits enforced
    
    private func generatePersonalizationData(emotion: EmotionType) async -> [String: Any] {
        let behaviorPattern = await behaviorAnalyzer.getCurrentBehaviorPattern()
        
        return [
            "emotion": emotion.rawValue,
            "user_active_hours": behaviorPattern.averageAppUsageHours,
            "preferred_interventions": behaviorPattern.preferredInterventionTypes.map { $0.rawValue },
            "engagement_score": behaviorPattern.engagementHistory.last ?? 0.5
        ]
    }
    
    private func loadScheduledNotifications() {
        // Load previously scheduled notifications from UserDefaults or Core Data
        // Implementation would restore scheduled notifications across app launches
    }
    
    private func cleanupOldNotifications() async {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        
        // Remove old notifications
        scheduledNotifications.removeAll { notification in
            notification.scheduledTime < oneDayAgo
        }
        
        // Remove from notification center
        let identifiersToRemove = scheduledNotifications
            .filter { $0.scheduledTime < oneDayAgo }
            .map { $0.id }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
    }
    
    private func updateOptimalTimingRules(basedOn analysis: NotificationPerformanceAnalysis) async {
        // Update internal timing rules based on performance analysis
        // This would adjust the optimal hours for different emotions and interventions
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension SmartNotificationScheduler: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        
        Task { @MainActor in
            await handleNotificationResponse(response)
            completionHandler()
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didDismissNotification notification: UNNotification,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification dismiss
        Task { @MainActor in
            await handleNotificationDismiss(notification)
            completionHandler()
        }
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Track the response
        await trackNotificationEngagement(Notification(name: .notificationOpened, object: nil, userInfo: userInfo))
        
        // Handle specific actions
        switch actionIdentifier {
        case "start_analysis":
            await handleStartVoiceAnalysis(userInfo)
        case "explore_app":
            await handleExploreApp(userInfo)
        case "START_INTERVENTION":
            await handleStartIntervention(userInfo)
        case "REMIND_LATER":
            await handleRemindLater(userInfo)
        case "QUICK_CHECKIN":
            await handleQuickCheckIn(userInfo)
        case "VOICE_ANALYSIS":
            await handleVoiceAnalysis(userInfo)
        case "update_progress", "view_goal", "remind_later":
            await handleGoalReminderAction(userInfo, action: actionIdentifier)
        default:
            break
        }
        
        // Trigger haptic feedback
        if let emotionString = userInfo["emotion"] as? String,
           let emotion = EmotionType(rawValue: emotionString) {
            hapticManager.emotionalFeedback(for: emotion)
        }
    }
    
    private func handleNotificationDismiss(_ notification: UNNotification) async {
        let userInfo = notification.request.content.userInfo
        
        // Track dismiss action
        if let notificationType = userInfo["notification_type"] as? String {
            switch notificationType {
            case "welcome":
                // Track welcome notification dismiss
                OneSignal.User.addTags([
                    "welcome_notification_dismissed": "true",
                    "welcome_dismiss_timestamp": ISO8601DateFormatter().string(from: Date())
                ])
                
            default:
                break
            }
        }
        
        // Track general dismiss analytics
        await trackNotificationDismiss(notification)
    }
    
    private func handleStartVoiceAnalysis(_ userInfo: [AnyHashable: Any]) async {
        // Navigate to voice analysis using deep link
        if let url = URL(string: "emotiq://voice-analysis") {
            await openDeepLink(url: url)
        } else {
            // Fallback to notification center
            NotificationCenter.default.post(
                name: Notification.Name("navigateToVoiceAnalysis"),
                object: nil,
                userInfo: ["source": "notification_action"]
            )
        }
    }
    
    private func handleExploreApp(_ userInfo: [AnyHashable: Any]) async {
        // Navigate to main app using deep link
        if let url = URL(string: "emotiq://dashboard") {
            await openDeepLink(url: url)
        } else {
            // Fallback to notification center
            NotificationCenter.default.post(
                name: Notification.Name("navigateToMainApp"),
                object: nil,
                userInfo: ["source": "notification_action"]
            )
        }
    }
    
    private func openDeepLink(url: URL) async {
        await MainActor.run {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    // Fallback to notification center if deep link fails
                    NotificationCenter.default.post(
                        name: Notification.Name("navigateToVoiceAnalysis"),
                        object: nil,
                        userInfo: ["source": "deep_link_fallback"]
                    )
                }
            }
        }
    }
    
    private func handleStartIntervention(_ userInfo: [AnyHashable: Any]) async {
        // Navigate to intervention based on notification data
        if let interventionString = userInfo["intervention"] as? String,
           let intervention = OneSignaInterventionType(rawValue: interventionString) {
            
            // Post notification to navigate to intervention
            NotificationCenter.default.post(
                name: .navigateToIntervention,
                object: intervention
            )
        }
    }
    
    private func handleRemindLater(_ userInfo: [AnyHashable: Any]) async {
        // Reschedule notification for later
        if let emotionString = userInfo["emotion"] as? String,
           let emotion = EmotionType(rawValue: emotionString),
           let interventionString = userInfo["intervention"] as? String,
           let intervention = OneSignaInterventionType(rawValue: interventionString) {
            
            await scheduleEmotionTriggeredNotification(
                emotion: emotion,
                intervention: intervention,
                delay: 3600 // 1 hour later
            )
        }
    }
    
    private func handleQuickCheckIn(_ userInfo: [AnyHashable: Any]) async {
        // Navigate to quick check-in
        NotificationCenter.default.post(name: .navigateToQuickCheckIn, object: nil)
    }
    
    private func handleVoiceAnalysis(_ userInfo: [AnyHashable: Any]) async {
        // Navigate to voice analysis
        NotificationCenter.default.post(name: .navigateToVoiceAnalysis, object: nil)
    }
    
    private func handleGoalReminderAction(_ userInfo: [AnyHashable: Any], action: String) async {
        guard let goalIdString = userInfo["goal_id"] as? String,
              let goalId = UUID(uuidString: goalIdString) else {
          
            return
        }
        
        switch action {
        case "update_progress":
            // Navigate to goal progress update
            NotificationCenter.default.post(
                name: Notification.Name("navigateToGoalProgress"),
                object: nil,
                userInfo: ["goal_id": goalId]
            )
        case "view_goal":
            // Navigate to goal details
            NotificationCenter.default.post(
                name: Notification.Name("navigateToGoalDetails"),
                object: nil,
                userInfo: ["goal_id": goalId]
            )
        case "remind_later":
            // Reschedule reminder for 2 hours later
            await rescheduleGoalReminder(goalId: goalId, delayHours: 2)
        default:
           "Unknown goal"
        }
    }
    
    private func rescheduleGoalReminder(goalId: UUID, delayHours: Int) async {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", goalId as CVarArg)
        
        do {
            let goals = try context.fetch(request)
            if let goal = goals.first {
                // Reschedule the reminder
                await scheduleGoalProgressReminder(for: goal)
            
            }
        } catch {
        
        }
    }
}

// MARK: - Supporting Models
struct ScheduledNotification {
    let id: String
    let type: NotificationType
    let emotion: EmotionType
    let intervention: OneSignaInterventionType
    let scheduledTime: Date
    let content: NotificationContent
    let priority: NotificationPriority
    let personalizationData: [String: Any]
    var wasEngaged: Bool = false
}

enum NotificationType {
    case emotionTriggered
    case predictiveIntervention
    case dailyCheckIn
    case achievement
    case reminder
}

enum NotificationPriority: Codable {
    case low
    case medium
    case high
    case urgent
    
    var stringValue: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .urgent: return "urgent"
        }
    }
}


struct Achievement {
    let id: String
    let title: String
    let description: String
    let type: AchievementType
}

enum AchievementType: String {
    case dailyGoal = "daily_goal"
    case weeklyGoal = "weekly_goal"
    case streak = "streak"
    case milestone = "milestone"
}

// MARK: - Analytics
class SchedulerAnalytics: ObservableObject {
    @Published var notificationsScheduled: Int = 0
    @Published var notificationsOpened: Int = 0
    @Published var notificationDismissed: Int = 0
    @Published var engagementRate: Double = 0.0
    
    private var engagementData: [EngagementDataPoint] = []
    
    func trackEngagement(emotion: EmotionType, intervention: OneSignaInterventionType, timeOfDay: Int) {
        let dataPoint = EngagementDataPoint(
            emotion: emotion,
            intervention: intervention,
            timeOfDay: timeOfDay,
            timestamp: Date()
        )
        
        engagementData.append(dataPoint)
        updateEngagementRate()
    }
    
    private func updateEngagementRate() {
        guard notificationsScheduled > 0 else {
            engagementRate = 0.0
            return
        }
        
        engagementRate = Double(notificationsOpened) / Double(notificationsScheduled)
    }
}

struct EngagementDataPoint {
    let emotion: EmotionType
    let intervention: OneSignaInterventionType
    let timeOfDay: Int
    let timestamp: Date
}

class NotificationPerformanceAnalysis {
    private var dataPoints: [PerformanceDataPoint] = []
    
    func addDataPoint(hour: Int, emotion: EmotionType, intervention: OneSignaInterventionType, wasEngaged: Bool) {
        let dataPoint = PerformanceDataPoint(
            hour: hour,
            emotion: emotion,
            intervention: intervention,
            wasEngaged: wasEngaged
        )
        dataPoints.append(dataPoint)
    }
    
    func getEngagementRate(for hour: Int) -> Double {
        let hourData = dataPoints.filter { $0.hour == hour }
        guard !hourData.isEmpty else { return 0.0 }
        
        let engagedCount = hourData.filter { $0.wasEngaged }.count
        return Double(engagedCount) / Double(hourData.count)
    }
    
    func getBestHours() -> [Int] {
        let hours = Array(0...23)
        return hours.sorted { getEngagementRate(for: $0) > getEngagementRate(for: $1) }
    }
}

struct PerformanceDataPoint {
    let hour: Int
    let emotion: EmotionType
    let intervention: OneSignaInterventionType
    let wasEngaged: Bool
}

// MARK: - Helper Methods
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

// MARK: - Notification Extensions
extension Notification.Name {
    static let notificationOpened = Notification.Name("notificationOpened")
    static let navigateToIntervention = Notification.Name("navigateToIntervention")
    static let navigateToQuickCheckIn = Notification.Name("navigateToQuickCheckIn")
}

