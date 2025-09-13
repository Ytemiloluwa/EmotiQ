//
//  UserBehaviorAnalyzer.swift
//  EmotiQ
//
//  Created by Temiloluwa on 25-08-2025.
//
import Foundation
import CoreML
import Combine
import UIKit
import CoreData

// MARK: - User Behavior Analyzer
@MainActor
class UserBehaviorAnalyzer: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentBehaviorPattern: UserBehaviorPattern = UserBehaviorPattern()
    @Published var emotionalPatterns: EmotionalPatternAnalysis = EmotionalPatternAnalysis()
    @Published var engagementMetrics: EngagementMetrics = EngagementMetrics()
    @Published var lastAnalysisUpdate: Date?
    
    // MARK: - Private Properties
    private var behaviorData: [BehaviorDataPoint] = []
    private var emotionHistory: [EmotionDataPoint] = []
    private var notificationEngagementHistory: [NotificationEngagementPoint] = []
    private let persistenceController = PersistenceController.shared
    private let hapticManager = HapticManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private struct Config {
        static let maxBehaviorDataPoints = 5000
        static let analysisWindow: TimeInterval = 86400 * 30 // 30 days
        static let patternUpdateInterval: TimeInterval = 3600 // 1 hour
        static let minDataPointsForAnalysis = 20
        static let engagementDecayFactor: Double = 0.95 // Daily decay
        static let isDebugMode = false // Set to false for production
    }
    
    // MARK: - Initialization
    init() {
        loadStoredBehaviorData()
        setupPeriodicAnalysis()
        setupDataObservers()
    }
    
    // MARK: - Data Collection
    func recordAppUsage(hour: Int, dayOfWeek: Int) async {
        let dataPoint = BehaviorDataPoint(
            timestamp: Date(),
            type: .appUsage,
            hour: hour,
            dayOfWeek: dayOfWeek,
            duration: nil,
            context: ["session_start": true]
        )
        
        behaviorData.append(dataPoint)
        await updateBehaviorPattern()
        await saveBehaviorData()
    }
    
    func recordEmotionAnalysis(
        emotion: EmotionType,
        confidence: Double,
        intensity: Double,
        context: [String: Any] = [:]
    ) async {
        let emotionPoint = EmotionDataPoint(
            timestamp: Date(),
            emotion: emotion,
            confidence: confidence,
            intensity: intensity,
            hour: Calendar.current.component(.hour, from: Date()),
            dayOfWeek: Calendar.current.component(.weekday, from: Date()),
            context: context
        )
        
        emotionHistory.append(emotionPoint)
        await updateEmotionalPatterns()
        await saveBehaviorData()
    }
    
    func recordNotificationEngagement(
        emotion: EmotionType,
        intervention: OneSignaInterventionType,
        scheduledTime: Date,
        actualEngagementTime: Date
    ) async {
        let engagementPoint = NotificationEngagementPoint(
            scheduledTime: scheduledTime,
            actualEngagementTime: actualEngagementTime,
            emotion: emotion,
            intervention: intervention,
            delayMinutes: Int(actualEngagementTime.timeIntervalSince(scheduledTime) / 60),
            wasEngaged: true
        )
        
        notificationEngagementHistory.append(engagementPoint)
        await updateEngagementMetrics()
        await saveBehaviorData()
        
        // Trigger haptic feedback for successful engagement
        hapticManager.notification(.success)
    }
    
    func recordInterventionCompletion(
        intervention: InterventionType,
        duration: TimeInterval,
        effectivenessScore: Double,
        userFeedback: String? = nil
    ) async {
        let dataPoint = BehaviorDataPoint(
            timestamp: Date(),
            type: .interventionCompletion,
            hour: Calendar.current.component(.hour, from: Date()),
            dayOfWeek: Calendar.current.component(.weekday, from: Date()),
            duration: duration,
            context: [
                "intervention": getInterventionString(intervention),
                "effectiveness": effectivenessScore,
                "feedback": userFeedback ?? ""
            ]
        )
        
        behaviorData.append(dataPoint)
        await updateBehaviorPattern()
        await saveBehaviorData()
        
        // Trigger celebration haptic for completed intervention
        hapticManager.celebration(.goalCompleted)
    }
    
    // MARK: - Pattern Analysis
    func analyzeEmotionalPatterns() async -> EmotionalPatternInsights {
        let recentEmotions = getRecentEmotionData()
        
        // Analyze dominant emotions
        let dominantEmotion = findDominantEmotion(in: recentEmotions)
        
        // Analyze stress peak hours
        let stressPeakHours = findStressPeakHours(in: recentEmotions)
        
        // Analyze optimal intervention times
        let optimalInterventionTimes = findOptimalInterventionTimes()
        
        // Analyze emotional volatility
        let volatilityScore = calculateEmotionalVolatility(in: recentEmotions)
        
        // Analyze weekly patterns
        let weeklyPatterns = analyzeWeeklyEmotionalPatterns(in: recentEmotions)
        
        return EmotionalPatternInsights(
            dominantPattern: dominantEmotion.rawValue,
            stressPeakHours: stressPeakHours,
            optimalInterventionTimes: optimalInterventionTimes,
            volatilityScore: volatilityScore,
            weeklyPatterns: weeklyPatterns,
            confidenceLevel: calculatePatternConfidence(dataPoints: recentEmotions.count)
        )
    }
    
    func getCurrentBehaviorPattern() async -> UserBehaviorPattern {
        await updateBehaviorPattern()
        return currentBehaviorPattern
    }
    
    private func updateBehaviorPattern() async {
        let recentBehavior = getRecentBehaviorData()
        
        // Analyze app usage patterns
        let usageHours = analyzeUsageHours(in: recentBehavior)
        
        // Analyze emotional peak times
        let emotionalPeakTimes = analyzeEmotionalPeakTimes()
        
        // Analyze preferred intervention types
        let preferredInterventions = analyzePreferredInterventions(in: recentBehavior)
        
        // Calculate engagement history
        let engagementHistory = calculateEngagementHistory()
        
        // Analyze session patterns
        let sessionPatterns = analyzeSessionPatterns(in: recentBehavior)
        
        currentBehaviorPattern = UserBehaviorPattern(
            averageAppUsageHours: usageHours,
            emotionalPeakTimes: emotionalPeakTimes,
            preferredInterventionTypes: preferredInterventions,
            engagementHistory: engagementHistory,
            sessionPatterns: sessionPatterns,
            lastUpdated: Date()
        )
    }
    
    private func updateEmotionalPatterns() async {
        let recentEmotions = getRecentEmotionData()
        
        // Calculate emotional stability
        let stability = calculateEmotionalStability(in: recentEmotions)
        
        // Analyze emotion transitions
        let transitions = analyzeEmotionTransitions(in: recentEmotions)
        
        // Find trigger patterns
        let triggerPatterns = findEmotionalTriggerPatterns(in: recentEmotions)
        
        // Calculate recovery patterns
        let recoveryPatterns = analyzeEmotionalRecoveryPatterns(in: recentEmotions)
        
        emotionalPatterns = EmotionalPatternAnalysis(
            stability: stability,
            transitions: transitions,
            triggerPatterns: triggerPatterns,
            recoveryPatterns: recoveryPatterns,
            lastAnalyzed: Date()
        )
    }
    
    private func updateEngagementMetrics() async {
        let recentEngagements = getRecentEngagementData()
        
        // Calculate overall engagement rate
        let overallRate = calculateOverallEngagementRate(in: recentEngagements)
        
        // Analyze engagement by time of day
        let timeBasedEngagement = analyzeTimeBasedEngagement(in: recentEngagements)
        
        // Analyze engagement by emotion
        let emotionBasedEngagement = analyzeEmotionBasedEngagement(in: recentEngagements)
        
        // Calculate response time patterns
        let responseTimePatterns = analyzeResponseTimePatterns(in: recentEngagements)
        
        engagementMetrics = EngagementMetrics(
            overallEngagementRate: overallRate,
            timeBasedEngagement: timeBasedEngagement,
            emotionBasedEngagement: emotionBasedEngagement,
            responseTimePatterns: responseTimePatterns,
            lastCalculated: Date()
        )
    }
    
    // MARK: - Specific Analysis Methods
    private func findDominantEmotion(in emotions: [EmotionDataPoint]) -> EmotionType {
        let emotionCounts = Dictionary(grouping: emotions, by: { $0.emotion })
            .mapValues { $0.count }
        
        return emotionCounts.max(by: { $0.value < $1.value })?.key ?? .neutral
    }
    
    private func findStressPeakHours(in emotions: [EmotionDataPoint]) -> [Int] {
        let stressEmotions: Set<EmotionType> = [.anger, .fear, .sadness, .disgust]
        
        let stressfulEmotions = emotions.filter { stressEmotions.contains($0.emotion) }
        let hourCounts = Dictionary(grouping: stressfulEmotions, by: { $0.hour })
            .mapValues { $0.count }
        
        // Return hours with above-average stress
        let averageStress = Double(hourCounts.values.reduce(0, +)) / Double(hourCounts.count)
        
        return hourCounts.compactMap { hour, count in
            Double(count) > averageStress ? hour : nil
        }.sorted()
    }
    
    private func findOptimalInterventionTimes() -> [Int] {
        let successfulInterventions = behaviorData.filter { dataPoint in
            dataPoint.type == .interventionCompletion &&
            (dataPoint.context["effectiveness"] as? Double ?? 0.0) > 0.7
        }
        
        let hourCounts = Dictionary(grouping: successfulInterventions, by: { $0.hour })
            .mapValues { $0.count }
        
        // Return top 3 hours with most successful interventions
        return hourCounts.sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    private func calculateEmotionalVolatility(in emotions: [EmotionDataPoint]) -> Double {
        guard emotions.count > 1 else { return 0.0 }
        
        // Calculate variance in emotional intensity
        let intensities = emotions.map { $0.intensity }
        let mean = intensities.reduce(0, +) / Double(intensities.count)
        let variance = intensities.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intensities.count)
        
        return sqrt(variance)
    }
    
    private func analyzeWeeklyEmotionalPatterns(in emotions: [EmotionDataPoint]) -> [Int: EmotionType] {
        var weeklyPatterns: [Int: EmotionType] = [:]
        
        for dayOfWeek in 1...7 {
            let dayEmotions = emotions.filter { $0.dayOfWeek == dayOfWeek }
            if !dayEmotions.isEmpty {
                weeklyPatterns[dayOfWeek] = findDominantEmotion(in: dayEmotions)
            }
        }
        
        return weeklyPatterns
    }
    
    private func analyzeUsageHours(in behavior: [BehaviorDataPoint]) -> [Int] {
        let usageData = behavior.filter { $0.type == .appUsage }
        let hourCounts = Dictionary(grouping: usageData, by: { $0.hour })
            .mapValues { $0.count }
        
        // Return hours with above-average usage
        let averageUsage = Double(hourCounts.values.reduce(0, +)) / Double(hourCounts.count)
        
        return hourCounts.compactMap { hour, count in
            Double(count) > averageUsage ? hour : nil
        }.sorted()
    }
    
    private func analyzeEmotionalPeakTimes() -> [Int] {
        let recentEmotions = getRecentEmotionData()
        let highIntensityEmotions = recentEmotions.filter { $0.intensity > 0.7 }
        
        let hourCounts = Dictionary(grouping: highIntensityEmotions, by: { $0.hour })
            .mapValues { $0.count }
        
        return hourCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    private func analyzePreferredInterventions(in behavior: [BehaviorDataPoint]) -> [OneSignaInterventionType] {
        let interventions = behavior.filter { $0.type == .interventionCompletion }
        
        let interventionCounts = Dictionary(grouping: interventions) { dataPoint in
            let interventionString = dataPoint.context["intervention"] as? String ?? ""
            return convertInterventionStringToOneSignaType(interventionString)
        }.mapValues { $0.count }
        
        return interventionCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    private func convertInterventionStringToOneSignaType(_ interventionString: String) -> OneSignaInterventionType {
        switch interventionString {
        case "gratitude":
            return .gratitudePractice
        case "self_compassion":
            return .selfCompassionBreak
        case "box_breathing", "equal_breathing":
            return .breathingExercise
        case "5_4_3_2_1":
            return .groundingExercise
        case "thought_observation", "body_awareness":
            return .mindfulnessCheck
        case "emotional_processing":
            return .emotionalReset
        case "loving_kindness":
            return .balanceMaintenance
        default:
            return .mindfulnessCheck
        }
    }
    
    private func calculateEngagementHistory() -> [Double] {
        let recentEngagements = getRecentEngagementData()
        let last7Days = Array(0..<7).map { dayOffset in
            let targetDate = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dayStart = Calendar.current.startOfDay(for: targetDate)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            
            let dayEngagements = recentEngagements.filter { engagement in
                engagement.actualEngagementTime >= dayStart && engagement.actualEngagementTime < dayEnd
            }
            
            return dayEngagements.isEmpty ? 0.0 : 1.0
        }
        
        return last7Days.reversed()
    }
    
    private func analyzeSessionPatterns(in behavior: [BehaviorDataPoint]) -> SessionPatterns {
        let sessions = behavior.filter { $0.type == .appUsage }
        
        // Calculate average session duration
        let durations = sessions.compactMap { $0.duration }
        let averageDuration = durations.isEmpty ? 0.0 : durations.reduce(0, +) / Double(durations.count)
        
        // Calculate sessions per day
        let uniqueDays = Set(sessions.map { Calendar.current.startOfDay(for: $0.timestamp) })
        let sessionsPerDay = uniqueDays.isEmpty ? 0.0 : Double(sessions.count) / Double(uniqueDays.count)
        
        // Find peak usage hours
        let hourCounts = Dictionary(grouping: sessions, by: { $0.hour })
            .mapValues { $0.count }
        let peakHours = hourCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        
        return SessionPatterns(
            averageDuration: averageDuration,
            sessionsPerDay: sessionsPerDay,
            peakUsageHours: peakHours
        )
    }
    
    // MARK: - Engagement Analysis
    private func calculateOverallEngagementRate(in engagements: [NotificationEngagementPoint]) -> Double {
        guard !engagements.isEmpty else { return 0.0 }
        
        let engagedCount = engagements.filter { $0.wasEngaged }.count
        return Double(engagedCount) / Double(engagements.count)
    }
    
    private func analyzeTimeBasedEngagement(in engagements: [NotificationEngagementPoint]) -> [Int: Double] {
        var timeBasedRates: [Int: Double] = [:]
        
        for hour in 0...23 {
            let hourEngagements = engagements.filter {
                Calendar.current.component(.hour, from: $0.scheduledTime) == hour
            }
            
            if !hourEngagements.isEmpty {
                let engagedCount = hourEngagements.filter { $0.wasEngaged }.count
                timeBasedRates[hour] = Double(engagedCount) / Double(hourEngagements.count)
            }
        }
        
        return timeBasedRates
    }
    
    private func analyzeEmotionBasedEngagement(in engagements: [NotificationEngagementPoint]) -> [EmotionType: Double] {
        var emotionBasedRates: [EmotionType: Double] = [:]
        
        for emotion in EmotionType.allCases {
            let emotionEngagements = engagements.filter { $0.emotion == emotion }
            
            if !emotionEngagements.isEmpty {
                let engagedCount = emotionEngagements.filter { $0.wasEngaged }.count
                emotionBasedRates[emotion] = Double(engagedCount) / Double(emotionEngagements.count)
            }
        }
        
        return emotionBasedRates
    }
    
    private func analyzeResponseTimePatterns(in engagements: [NotificationEngagementPoint]) -> ResponseTimePatterns {
        let responseTimes = engagements.compactMap { engagement in
            engagement.wasEngaged ? Double(engagement.delayMinutes) : nil
        }
        
        guard !responseTimes.isEmpty else {
            return ResponseTimePatterns(averageResponseTime: 0, medianResponseTime: 0, quickResponseRate: 0)
        }
        
        let averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let sortedTimes = responseTimes.sorted()
        let medianResponseTime = sortedTimes[sortedTimes.count / 2]
        let quickResponses = responseTimes.filter { $0 <= 5.0 } // Within 5 minutes
        let quickResponseRate = Double(quickResponses.count) / Double(responseTimes.count)
        
        return ResponseTimePatterns(
            averageResponseTime: averageResponseTime,
            medianResponseTime: medianResponseTime,
            quickResponseRate: quickResponseRate
        )
    }
    
    // MARK: - Emotional Pattern Analysis
    private func calculateEmotionalStability(in emotions: [EmotionDataPoint]) -> Double {
        guard emotions.count > 1 else { return 1.0 }
        
        // Calculate how often emotions change dramatically
        var stabilityScore = 0.0
        
        for i in 1..<emotions.count {
            let previous = emotions[i-1]
            let current = emotions[i]
            
            // Check if emotion type changed
            if previous.emotion == current.emotion {
                stabilityScore += 1.0
            }
            
            // Check intensity stability
            let intensityDiff = abs(current.intensity - previous.intensity)
            if intensityDiff < 0.3 {
                stabilityScore += 1.0
            }
        }
        
        return stabilityScore / Double((emotions.count - 1) * 2)
    }
    
    private func analyzeEmotionTransitions(in emotions: [EmotionDataPoint]) -> [EmotionTransition] {
        guard emotions.count > 1 else { return [] }
        
        var transitions: [EmotionTransition] = []
        
        for i in 1..<emotions.count {
            let from = emotions[i-1].emotion
            let to = emotions[i].emotion
            let timeInterval = emotions[i].timestamp.timeIntervalSince(emotions[i-1].timestamp)
            
            if from != to {
                transitions.append(EmotionTransition(
                    from: from,
                    to: to,
                    timeInterval: timeInterval,
                    timestamp: emotions[i].timestamp
                ))
            }
        }
        
        return transitions
    }
    
    private func findEmotionalTriggerPatterns(in emotions: [EmotionDataPoint]) -> [TriggerPattern] {
        // Analyze what contexts lead to specific emotions
        var patterns: [TriggerPattern] = []
        
        let negativeEmotions: Set<EmotionType> = [.anger, .fear, .sadness, .disgust]
        let negativeEmotionEvents = emotions.filter { negativeEmotions.contains($0.emotion) }
        
        // Group by hour to find time-based triggers
        let hourGroups = Dictionary(grouping: negativeEmotionEvents, by: { $0.hour })
        
        for (hour, emotionEvents) in hourGroups {
            if emotionEvents.count >= 3 { // Minimum threshold for pattern
                let dominantEmotion = findDominantEmotion(in: emotionEvents)
                patterns.append(TriggerPattern(
                    triggerType: .timeOfDay,
                    triggerValue: String(hour),
                    resultingEmotion: dominantEmotion,
                    frequency: emotionEvents.count,
                    confidence: min(1.0, Double(emotionEvents.count) / 10.0)
                ))
            }
        }
        
        return patterns
    }
    
    private func analyzeEmotionalRecoveryPatterns(in emotions: [EmotionDataPoint]) -> [RecoveryPattern] {
        var recoveryPatterns: [RecoveryPattern] = []
        
        // Guard against insufficient data
        guard emotions.count >= 2 else {
            return recoveryPatterns
        }
        
        let negativeEmotions: Set<EmotionType> = [.anger, .fear, .sadness, .disgust]
        let positiveEmotions: Set<EmotionType> = [.joy, .neutral]
        
        for i in 0..<(emotions.count - 1) {
            let current = emotions[i]
            
            if negativeEmotions.contains(current.emotion) {
                // Look for recovery to positive emotion
                for j in (i+1)..<emotions.count {
                    let future = emotions[j]
                    
                    if positiveEmotions.contains(future.emotion) {
                        let recoveryTime = future.timestamp.timeIntervalSince(current.timestamp)
                        
                        recoveryPatterns.append(RecoveryPattern(
                            fromEmotion: current.emotion,
                            toEmotion: future.emotion,
                            recoveryTime: recoveryTime,
                            recoveryMethod: determineRecoveryMethod(between: current, and: future)
                        ))
                        break
                    }
                }
            }
        }
        
        return recoveryPatterns
    }
    
    private func determineRecoveryMethod(between start: EmotionDataPoint, and end: EmotionDataPoint) -> RecoveryMethod {
        // Analyze what happened between the emotions to determine recovery method
        let timeInterval = end.timestamp.timeIntervalSince(start.timestamp)
        
        if timeInterval < 1800 { // Less than 30 minutes
            return .naturalRecovery
        } else if timeInterval < 3600 { // Less than 1 hour
            return .timeBasedRecovery
        } else {
            return .interventionBasedRecovery
        }
    }
    
    // MARK: - Data Management
    private func getRecentBehaviorData() -> [BehaviorDataPoint] {
        let cutoffDate = Date().addingTimeInterval(-Config.analysisWindow)
        return behaviorData.filter { $0.timestamp >= cutoffDate }
    }
    
    private func getRecentEmotionData() -> [EmotionDataPoint] {
        let cutoffDate = Date().addingTimeInterval(-Config.analysisWindow)
        return emotionHistory.filter { $0.timestamp >= cutoffDate }
    }
    
    private func getRecentEngagementData() -> [NotificationEngagementPoint] {
        let cutoffDate = Date().addingTimeInterval(-Config.analysisWindow)
        return notificationEngagementHistory.filter { $0.scheduledTime >= cutoffDate }
    }
    
    private func calculatePatternConfidence(dataPoints: Int) -> Double {
        return min(1.0, Double(dataPoints) / Double(Config.minDataPointsForAnalysis))
    }
    
    // MARK: - Persistence
    private func loadStoredBehaviorData() {
        // Load behavior data from Core Data with memory limits
        // Implementation would restore behavior data across app launches
        
        let context = persistenceController.container.viewContext
        
        // Load behavior data points with limit
        let behaviorRequest: NSFetchRequest<BehaviorDataEntity> = BehaviorDataEntity.fetchRequest()
        behaviorRequest.sortDescriptors = [NSSortDescriptor(keyPath: \BehaviorDataEntity.timestamp, ascending: false)] // Most recent first
        behaviorRequest.fetchLimit = 1000 // CRITICAL FIX: Limit to prevent memory issues
        
        do {
            let behaviorEntities = try context.fetch(behaviorRequest)
            behaviorData = behaviorEntities.compactMap { entity in
                guard let timestamp = entity.timestamp,
                      let typeString = entity.type,
                      let type = BehaviorType(rawValue: typeString) else { return nil }
                
                return BehaviorDataPoint(
                    timestamp: timestamp,
                    type: type,
                    hour: Int(entity.hour),
                    dayOfWeek: Int(entity.dayOfWeek),
                    duration: entity.duration ?? 0.0,
                    context: (entity.value(forKey: "contextData") as? NSDictionary) as? [String: Any] ?? [:]
                )
            }
        } catch {

        }
        
        // Load emotion history with limit
        let emotionRequest: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        emotionRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: false)] // Most recent first
        emotionRequest.fetchLimit = 1000 // CRITICAL FIX: Limit to prevent memory issues
        
        do {
            let emotionEntities = try context.fetch(emotionRequest)
            emotionHistory = emotionEntities.compactMap { entity in
                guard let timestamp = entity.timestamp,
                      let emotionString = entity.primaryEmotion,
                      let emotion = EmotionType(rawValue: emotionString) else { return nil }
                
                return EmotionDataPoint(
                    timestamp: timestamp,
                    emotion: emotion,
                    confidence: entity.confidence,
                    intensity: entity.intensity,
                    hour: Int(entity.hour),
                    dayOfWeek: Int(entity.dayOfWeek),
                    context: (entity.value(forKey: "contextData") as? NSDictionary) as? [String: Any] ?? [:]
                )
            }
        } catch {

        }
        
        // Load notification engagement history with limit
        let engagementRequest: NSFetchRequest<NotificationEngagementEntity> = NotificationEngagementEntity.fetchRequest()
        engagementRequest.sortDescriptors = [NSSortDescriptor(keyPath: \NotificationEngagementEntity.scheduledTime, ascending: false)] // Most recent first
        engagementRequest.fetchLimit = 1000 // CRITICAL FIX: Limit to prevent memory issues
        
        do {
            let engagementEntities = try context.fetch(engagementRequest)
            notificationEngagementHistory = engagementEntities.compactMap { entity in
                guard let scheduledTime = entity.scheduledTime,
                      let actualEngagementTime = entity.actualEngagementTime,
                      let emotionString = entity.emotion,
                      let emotion = EmotionType(rawValue: emotionString),
                      let interventionString = entity.intervention,
                      let intervention = OneSignaInterventionType(rawValue: interventionString) else { return nil }
                
                return NotificationEngagementPoint(
                    scheduledTime: scheduledTime,
                    actualEngagementTime: actualEngagementTime,
                    emotion: emotion,
                    intervention: intervention,
                    delayMinutes: Int(entity.delayMinutes),
                    wasEngaged: entity.wasEngaged
                )
            }
        } catch {

        }
        
    }
    
    private func saveBehaviorData() async {
        // Save behavior data to Core Data for persistence
        // Implementation would use PersistenceController to save data
        
        let context = persistenceController.container.viewContext
        
        // Get current user
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        userRequest.fetchLimit = 1
        
        guard let user = try? context.fetch(userRequest).first else {
            return
        }
        
        // Save behavior data points
        for dataPoint in behaviorData {
            let entity = BehaviorDataEntity(context: context)
            entity.id = UUID()
            entity.timestamp = dataPoint.timestamp
            entity.type = dataPoint.type.rawValue
            entity.hour = Int16(dataPoint.hour)
            entity.dayOfWeek = Int16(dataPoint.dayOfWeek)
            entity.duration = dataPoint.duration ?? 0.0
            // Ensure context data is NSSecureCoding compliant for Core Data storage
            let secureContext = dataPoint.context as NSDictionary
            entity.setValue(secureContext, forKey: "contextData")
            entity.user = user
        }
        
        // Note: EmotionalDataEntity records are saved by PersistenceController.saveEmotionalData()
        // We don't need to duplicate them here to avoid counting issues
        
        // Save notification engagement history
        for engagementPoint in notificationEngagementHistory {
            let entity = NotificationEngagementEntity(context: context)
            entity.id = UUID()
            entity.scheduledTime = engagementPoint.scheduledTime
            entity.actualEngagementTime = engagementPoint.actualEngagementTime
            entity.emotion = engagementPoint.emotion.rawValue
            entity.intervention = engagementPoint.intervention.rawValue
            entity.delayMinutes = Int16(engagementPoint.delayMinutes)
            entity.wasEngaged = engagementPoint.wasEngaged
            entity.user = user
        }
        
        // Save to Core Data
        do {
            try context.save()

        } catch {

        }
        
        // Limit data size
        if behaviorData.count > Config.maxBehaviorDataPoints {
            behaviorData.removeFirst(behaviorData.count - Config.maxBehaviorDataPoints)
        }
        
        if emotionHistory.count > Config.maxBehaviorDataPoints {
            emotionHistory.removeFirst(emotionHistory.count - Config.maxBehaviorDataPoints)
        }
        
        if notificationEngagementHistory.count > Config.maxBehaviorDataPoints {
            notificationEngagementHistory.removeFirst(notificationEngagementHistory.count - Config.maxBehaviorDataPoints)
        }
    }
    
    // MARK: - Setup Methods
    private func setupPeriodicAnalysis() {
        Timer.scheduledTimer(withTimeInterval: Config.patternUpdateInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.updateBehaviorPattern()
                await self.updateEmotionalPatterns()
                await self.updateEngagementMetrics()
                self.lastAnalysisUpdate = Date()
            }
        }
    }
    
    private func setupDataObservers() {
        
        // Observe app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.saveBehaviorData()
                }
            }
            .store(in: &cancellables)
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
    
    private func getInterventionString(_ intervention: InterventionType) -> String {
        switch intervention {
        case .emotionalPrompt(let type):
            return type.rawValue
        case .breathing(let type):
            return type.rawValue
        case .grounding(let type):
            return type.rawValue
        case .mindfulness(let type):
            return type.rawValue
        }
    }
}

// MARK: - Supporting Models
struct BehaviorDataPoint {
    let timestamp: Date
    let type: BehaviorType
    let hour: Int
    let dayOfWeek: Int
    let duration: TimeInterval?
    let context: [String: Any]
}

enum BehaviorType: String {
    case appUsage = "appUsage"
    case interventionCompletion = "interventionCompletion"
    case emotionAnalysis = "emotionAnalysis"
    case notificationEngagement = "notificationEngagement"
}

struct EmotionDataPoint {
    let timestamp: Date
    let emotion: EmotionType
    let confidence: Double
    let intensity: Double
    let hour: Int
    let dayOfWeek: Int
    let context: [String: Any]
}

struct NotificationEngagementPoint {
    let scheduledTime: Date
    let actualEngagementTime: Date
    let emotion: EmotionType
    let intervention: OneSignaInterventionType
    let delayMinutes: Int
    let wasEngaged: Bool
}

struct UserBehaviorPattern {
    let averageAppUsageHours: [Int]
    let emotionalPeakTimes: [Int]
    let preferredInterventionTypes: [OneSignaInterventionType]
    let engagementHistory: [Double]
    let sessionPatterns: SessionPatterns
    let lastUpdated: Date
    
    init() {
        self.averageAppUsageHours = []
        self.emotionalPeakTimes = []
        self.preferredInterventionTypes = []
        self.engagementHistory = []
        self.sessionPatterns = SessionPatterns(averageDuration: 0, sessionsPerDay: 0, peakUsageHours: [])
        self.lastUpdated = Date()
    }
    
    init(averageAppUsageHours: [Int], emotionalPeakTimes: [Int], preferredInterventionTypes: [OneSignaInterventionType], engagementHistory: [Double], sessionPatterns: SessionPatterns, lastUpdated: Date) {
        self.averageAppUsageHours = averageAppUsageHours
        self.emotionalPeakTimes = emotionalPeakTimes
        self.preferredInterventionTypes = preferredInterventionTypes
        self.engagementHistory = engagementHistory
        self.sessionPatterns = sessionPatterns
        self.lastUpdated = lastUpdated
    }
}

struct SessionPatterns {
    let averageDuration: TimeInterval
    let sessionsPerDay: Double
    let peakUsageHours: [Int]
}

struct EmotionalPatternAnalysis {
    let stability: Double
    let transitions: [EmotionTransition]
    let triggerPatterns: [TriggerPattern]
    let recoveryPatterns: [RecoveryPattern]
    let lastAnalyzed: Date
    
    init() {
        self.stability = 0.5
        self.transitions = []
        self.triggerPatterns = []
        self.recoveryPatterns = []
        self.lastAnalyzed = Date()
    }
    
    init(stability: Double, transitions: [EmotionTransition], triggerPatterns: [TriggerPattern], recoveryPatterns: [RecoveryPattern], lastAnalyzed: Date) {
        self.stability = stability
        self.transitions = transitions
        self.triggerPatterns = triggerPatterns
        self.recoveryPatterns = recoveryPatterns
        self.lastAnalyzed = lastAnalyzed
    }
}

struct EngagementMetrics {
    let overallEngagementRate: Double
    let timeBasedEngagement: [Int: Double]
    let emotionBasedEngagement: [EmotionType: Double]
    let responseTimePatterns: ResponseTimePatterns
    let lastCalculated: Date
    
    init() {
        self.overallEngagementRate = 0.0
        self.timeBasedEngagement = [:]
        self.emotionBasedEngagement = [:]
        self.responseTimePatterns = ResponseTimePatterns(averageResponseTime: 0, medianResponseTime: 0, quickResponseRate: 0)
        self.lastCalculated = Date()
    }
    
    init(overallEngagementRate: Double, timeBasedEngagement: [Int: Double], emotionBasedEngagement: [EmotionType: Double], responseTimePatterns: ResponseTimePatterns, lastCalculated: Date) {
        self.overallEngagementRate = overallEngagementRate
        self.timeBasedEngagement = timeBasedEngagement
        self.emotionBasedEngagement = emotionBasedEngagement
        self.responseTimePatterns = responseTimePatterns
        self.lastCalculated = lastCalculated
    }
}

struct EmotionalPatternInsights {
    let dominantPattern: String
    let stressPeakHours: [Int]
    let optimalInterventionTimes: [Int]
    let volatilityScore: Double
    let weeklyPatterns: [Int: EmotionType]
    let confidenceLevel: Double
}

struct EmotionTransition {
    let from: EmotionType
    let to: EmotionType
    let timeInterval: TimeInterval
    let timestamp: Date
}

struct TriggerPattern {
    let triggerType: TriggerType
    let triggerValue: String
    let resultingEmotion: EmotionType
    let frequency: Int
    let confidence: Double
}

enum TriggerType {
    case timeOfDay
    case dayOfWeek
    case context
    case sequence
}

struct RecoveryPattern {
    let fromEmotion: EmotionType
    let toEmotion: EmotionType
    let recoveryTime: TimeInterval
    let recoveryMethod: RecoveryMethod
}

enum RecoveryMethod {
    case naturalRecovery
    case timeBasedRecovery
    case interventionBasedRecovery
}

struct ResponseTimePatterns {
    let averageResponseTime: Double
    let medianResponseTime: Double
    let quickResponseRate: Double
}


