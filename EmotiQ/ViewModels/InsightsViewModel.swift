
//
//  InsightsViewModel.swift
//  EmotiQ
//
//  Created by Temiloluwa on 11-08-2025.
//

import SwiftUI
import CoreData
import Foundation

// MARK: - Data Models
struct EmotionTrendData: Identifiable {
    let id = UUID()
    let date: Date
    let checkInCount: Int
    let hasData: Bool
    let primaryEmotionCount: Int
    let secondaryEmotionCount: Int
}

// Enhanced data model for emotion intensity trends
struct EmotionIntensityDataPoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let emotion: EmotionCategory
    let intensity: Double
    let confidence: Double
}

struct EmotionDistributionData: Identifiable {
    let id = UUID()
    let emotion: EmotionCategory
    let percentage: Double
    var color: Color { emotion.color }
}

struct WeeklyPatternData: Identifiable {
    let id = UUID()
    let dayOfWeek: String
    let averageMood: Double
    let color: Color
    let hasData: Bool
    let count: Int
}

struct AIInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
}

// MARK: - Voice Characteristics Data Models

struct VoiceCharacteristicsDataPoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let pitch: Double
    let energy: Double
    let spectralCentroid: Double
    let jitter: Double?
    let shimmer: Double?
    let formantFrequencies: [Double]?
    let harmonicToNoiseRatio: Double?
    let zeroCrossingRate: Double?
    let spectralRolloff: Double?
    let voiceOnsetTime: Double?
    let emotion: EmotionCategory
    let confidence: Double
}

struct VoiceInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    let icon: String
    let color: Color
}

enum InsightsPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

// MARK: - Insights View Model
@MainActor
class InsightsViewModel: ObservableObject {
    @Published var selectedPeriod: InsightsPeriod = .week
    @Published var totalCheckIns = 0
    @Published var weeklyCheckIns = 0
    @Published var averageMood: EmotionCategory = .neutral
    @Published var currentStreak = 0
    @Published var mostCommonEmotion: EmotionCategory = .joy
    @Published var emotionalStability = "Stable"
    @Published var bestDay = "Tues"
    @Published var growthArea = "Stress Management"
    @Published var emotionalValence: EmotionValence = .neutral
    @Published var averageIntensity: EmotionIntensity = .medium
    @Published var trendData: [EmotionTrendData] = []
    @Published var emotionIntensityData: [EmotionIntensityDataPoint] = []
    @Published var emotionDistribution: [EmotionDistributionData] = []
    @Published var weeklyPatternData: [WeeklyPatternData] = []
    @Published var aiInsights: [AIInsight] = []
    @Published var voiceCharacteristicsData: [VoiceCharacteristicsDataPoint] = []
    @Published var voiceInsights: [VoiceInsight] = []
    let data: [VoiceCharacteristicsDataPoint] = []
    var uniqueEmotions: [EmotionCategory] {
        Array(Set(emotionIntensityData.map { $0.emotion }))
    }
    
    private let persistenceController = PersistenceController.shared
    
    func loadInsightsData() {
        // Refresh daily usage to check for daily reset
        SubscriptionService.shared.refreshDailyUsage()
        loadRealData()
    }
    
    func refreshData() {
        // Refresh daily usage to check for daily reset
        SubscriptionService.shared.refreshDailyUsage()
        loadRealData()
    }
    
    private func loadRealData() {
        guard let user = persistenceController.getCurrentUser() else {
            resetToEmptyState()
            return
        }
        
        // Load real emotional data from Core Data
        let emotionalData = loadEmotionalData(for: user)
        
        // Calculate insights from real data
        calculateInsights(from: emotionalData)
    }
    
    private func loadEmotionalData(for user: User) -> [EmotionalDataEntity] {
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        
        // Filter by selected period
        let calendar = Calendar.current
        let daysToFilter = selectedPeriod == .week ? 7 : 30
        let startDate = calendar.date(byAdding: .day, value: -daysToFilter, to: Date()) ?? Date()
        
        request.predicate = NSPredicate(format: "user == %@ AND timestamp >= %@", user, startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: false)]
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("❌ Failed to fetch emotional data: \(error)")
            return []
        }
    }
    
    private func calculateInsights(from emotionalData: [EmotionalDataEntity]) {
        guard !emotionalData.isEmpty else {
            resetToEmptyState()
            return
        }
        
        // Calculate total check-ins
        totalCheckIns = emotionalData.count
        
        // Calculate weekly check-ins
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        weeklyCheckIns = emotionalData.filter { $0.timestamp ?? Date() >= weekAgo }.count
        
        // Calculate average mood
        let emotions = emotionalData.compactMap { entity -> EmotionCategory? in
            guard let emotionString = entity.primaryEmotion else { return nil }
            return EmotionCategory(rawValue: emotionString)
        }
        
        if !emotions.isEmpty {
            averageMood = calculateAverageMood(from: emotions)
            mostCommonEmotion = calculateMostCommonEmotion(from: emotions)
        }
        
        // Calculate current streak
        currentStreak = calculateCurrentStreak(from: emotionalData)
        
        // Generate trend data
        trendData = generateTrendData(from: emotionalData)
        
        // Generate emotion intensity data for charts
        emotionIntensityData = generateEmotionIntensityData(from: emotionalData)
        
        // Generate distribution data
        emotionDistribution = generateDistributionData(from: emotions)
        
        // Generate weekly pattern data
        weeklyPatternData = generateWeeklyPatternData(from: emotionalData)
        
        // Generate AI insights
        aiInsights = generateAIInsights(from: emotionalData, emotions: emotions)
        
        // Generate voice characteristics data
        voiceCharacteristicsData = generateVoiceCharacteristicsData(from: emotionalData)
        voiceInsights = generateVoiceInsights(from: voiceCharacteristicsData)
        
        // Calculate other metrics
        emotionalStability = calculateEmotionalStability(from: emotionalData)
        bestDay = calculateBestDay(from: emotionalData)
        growthArea = calculateGrowthArea(from: emotionalData)
        
        // Calculate emotional valence and intensity
        emotionalValence = calculateEmotionalValence(from: emotions)
        averageIntensity = calculateAverageIntensity(from: emotionalData)
    }
    
    private func resetToEmptyState() {
        totalCheckIns = 0
        weeklyCheckIns = 0
        averageMood = .neutral
        currentStreak = 0
        mostCommonEmotion = .neutral
        emotionalStability = "No Data"
        bestDay = "No Data"
        growthArea = "No Data"
        emotionalValence = .neutral
        averageIntensity = .medium
        trendData = []
        emotionIntensityData = []
        emotionDistribution = []
        weeklyPatternData = []
        aiInsights = []
        voiceCharacteristicsData = []
        voiceInsights = []
    }
    
    private func calculateAverageMood(from emotions: [EmotionCategory]) -> EmotionCategory {
        // Simple average - in production, you might want more sophisticated analysis
        let emotionCounts = emotions.reduce(into: [EmotionCategory: Int]()) { counts, emotion in
            counts[emotion, default: 0] += 1
        }
        
        return emotionCounts.max(by: { $0.value < $1.value })?.key ?? .neutral
    }
    
    private func calculateMostCommonEmotion(from emotions: [EmotionCategory]) -> EmotionCategory {
        let emotionCounts = emotions.reduce(into: [EmotionCategory: Int]()) { counts, emotion in
            counts[emotion, default: 0] += 1
        }
        
        return emotionCounts.max(by: { $0.value < $1.value })?.key ?? .neutral
    }
    
    private func calculateCurrentStreak(from emotionalData: [EmotionalDataEntity]) -> Int {
        let calendar = Calendar.current
        let sortedData = emotionalData.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
        
        var streak = 0
        var currentDate = Date()
        
        for data in sortedData {
            guard let timestamp = data.timestamp else { continue }
            
            let dataDate = calendar.startOfDay(for: timestamp)
            let expectedDate = calendar.startOfDay(for: currentDate)
            
            if calendar.isDate(dataDate, inSameDayAs: expectedDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if calendar.dateInterval(of: .day, for: dataDate)?.start ?? dataDate < expectedDate {
                break
            }
        }
        
        return streak
    }
    
    private func generateTrendData(from emotionalData: [EmotionalDataEntity]) -> [EmotionTrendData] {
        print("🔍 DEBUG: generateTrendData() started with \(emotionalData.count) records")
        
        let calendar = Calendar.current
        let today = Date()
        
        // Find the first recording date
        guard let firstRecording = emotionalData.min(by: { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }),
              let firstDate = firstRecording.timestamp else {
            print("🔍 DEBUG: No first recording found, showing empty chart")
            // No data, show empty chart
            let daysToShow = selectedPeriod == .week ? 7 : 14 // Reduced from 30 to 14
            return (0..<daysToShow).map { dayOffset in
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                    return EmotionTrendData(date: Date(), checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                }
                return EmotionTrendData(date: date, checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
            }.reversed()
        }
        
        print("🔍 DEBUG: First recording date: \(firstDate)")
        
        // Start from the first recording date
        let startDate = calendar.startOfDay(for: firstDate)
        let daysSinceFirst = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
        let maxDays = selectedPeriod == .week ? 7 : 14 // Reduced from 30 to 14
        let daysToShow = min(max(daysSinceFirst + 1, maxDays), maxDays)
        
        print("🔍 DEBUG: Days since first: \(daysSinceFirst), Days to show: \(daysToShow)")
        
        // Limit to prevent memory issues
        let safeDaysToShow = min(daysToShow, 14)
        print("🔍 DEBUG: Safe days to show: \(safeDaysToShow)")
        
        return (0..<safeDaysToShow).map { dayOffset in
            print("🔍 DEBUG: Processing day \(dayOffset + 1)/\(safeDaysToShow)")
            
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                print("❌ DEBUG: Failed to calculate date for day \(dayOffset)")
                return EmotionTrendData(date: Date(), checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
            }
            
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
            
            let dayData = emotionalData.filter { entity in
                guard let timestamp = entity.timestamp else { return false }
                return timestamp >= dayStart && timestamp < dayEnd
            }
            
            print("🔍 DEBUG: Day \(dayOffset + 1): Found \(dayData.count) recordings")
            
            // Calculate emotion counts for the chart
            let emotions = dayData.compactMap { entity -> EmotionCategory? in
                guard let emotionString = entity.primaryEmotion else { return nil }
                return EmotionCategory(rawValue: emotionString)
            }
            
            let emotionCounts = emotions.reduce(into: [EmotionCategory: Int]()) { counts, emotion in
                counts[emotion, default: 0] += 1
            }
            
            // Get primary and secondary emotion counts
            let sortedEmotions = emotionCounts.sorted { $0.value > $1.value }
            let primaryCount = sortedEmotions.first?.value ?? 0
            let secondaryCount = sortedEmotions.count > 1 ? sortedEmotions[1].value : 0
            
            print("🔍 DEBUG: Day \(dayOffset + 1): Primary=\(primaryCount), Secondary=\(secondaryCount)")
            
            return EmotionTrendData(
                date: date,
                checkInCount: dayData.count,
                hasData: !dayData.isEmpty,
                primaryEmotionCount: primaryCount,
                secondaryEmotionCount: secondaryCount
            )
        }
    }
    
    private func generateEmotionIntensityData(from emotionalData: [EmotionalDataEntity]) -> [EmotionIntensityDataPoint] {
        return emotionalData.compactMap { entity in
            guard let timestamp = entity.timestamp,
                  let emotionString = entity.primaryEmotion,
                  let emotion = EmotionCategory(rawValue: emotionString) else {
                return nil
            }
            
            return EmotionIntensityDataPoint(
                timestamp: timestamp,
                emotion: emotion,
                intensity: entity.intensity,
                confidence: entity.confidence
            )
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func generateDistributionData(from emotions: [EmotionCategory]) -> [EmotionDistributionData] {
        let emotionCounts = emotions.reduce(into: [EmotionCategory: Int]()) { counts, emotion in
            counts[emotion, default: 0] += 1
        }
        
        let total = emotions.count
        guard total > 0 else { return [] }
        
        var distributionData: [EmotionDistributionData] = []
        
        for emotion in EmotionCategory.allCases {
            let count = emotionCounts[emotion] ?? 0
            let percentage = Int((Double(count) / Double(total)) * 100)
            
            if percentage > 0 {
                let data = EmotionDistributionData(emotion: emotion, percentage: Double(percentage))
                distributionData.append(data)
            }
        }
        
        return distributionData
    }
    
    private func generateWeeklyPatternData(from emotionalData: [EmotionalDataEntity]) -> [WeeklyPatternData] {
        let calendar = Calendar.current
        let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        var weekdayData: [Int: [Double]] = [:]
        
        // Group emotional data by weekday
        for data in emotionalData {
            guard let timestamp = data.timestamp else { continue }
            let weekday = calendar.component(.weekday, from: timestamp) - 1 // Convert to 0-based index
            
            if weekdayData[weekday] == nil {
                weekdayData[weekday] = []
            }
            weekdayData[weekday]?.append(data.intensity)
        }
        
        // Calculate average mood for each weekday
        var patternData: [WeeklyPatternData] = []
        
        for i in 0..<7 {
            let averageMood = weekdayData[i]?.reduce(0, +) ?? 0
            let count = weekdayData[i]?.count ?? 0
            let finalAverage = count > 0 ? averageMood / Double(count) : 0.0
            let hasData = count > 0
            
            patternData.append(WeeklyPatternData(
                dayOfWeek: weekdayNames[i],
                averageMood: finalAverage,
                color: .blue,
                hasData: hasData,
                count: count
            ))
        }
        
        return patternData
    }
    
    private func generateAIInsights(from emotionalData: [EmotionalDataEntity], emotions: [EmotionCategory]) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Always provide insights, even with minimal data
        if emotionalData.isEmpty {
            insights.append(AIInsight(
                title: "Getting Started",
                description: "Start recording your emotions with voice analysis to unlock personalized insights and patterns.",
                icon: "waveform.circle",
                color: .blue
            ))
            
            insights.append(AIInsight(
                title: "Build Your Journey",
                description: "Regular emotional check-ins help you understand your patterns and improve your wellbeing.",
                icon: "heart.fill",
                color: .pink
            ))
            
            return insights
        }
        
        // Insight 1: Most common emotion (if we have emotions)
        if !emotions.isEmpty {
            let mostCommon = calculateMostCommonEmotion(from: emotions)
            insights.append(AIInsight(
                title: "Most Common Emotion",
                description: "You've been feeling \(mostCommon.displayName.lowercased()) most often recently. This gives us insight into your overall emotional state.",
                icon: "brain.head.profile",
                color: .blue
            ))
        }
        
        // Insight 2: Streak information
        if currentStreak > 0 {
            let streakMessage = currentStreak == 1 ?
                "You've started your emotional tracking journey! Keep it up to build healthy habits." :
                "You've been checking in for \(currentStreak) consecutive days. Great consistency builds self-awareness!"
            
            insights.append(AIInsight(
                title: "Consistency Streak",
                description: streakMessage,
                icon: "flame.fill",
                color: .orange
            ))
        } else {
            insights.append(AIInsight(
                title: "Build Consistency",
                description: "Try to check in daily to build a streak and better understand your emotional patterns.",
                icon: "calendar",
                color: .orange
            ))
        }
        
        // Insight 3: Weekly activity
        if weeklyCheckIns > 0 {
            let activityLevel = weeklyCheckIns >= 5 ? "excellent" : weeklyCheckIns >= 3 ? "good" : "light"
            insights.append(AIInsight(
                title: "Weekly Activity",
                description: "You've completed \(weeklyCheckIns) emotional check-ins this week. That's \(activityLevel) progress!",
                icon: "chart.bar.fill",
                color: .green
            ))
        }
        
        // Insight 4: Emotional diversity
        let uniqueEmotions = Set(emotions)
        if uniqueEmotions.count > 1 {
            let diversityMessage = uniqueEmotions.count >= 4 ?
                "You're experiencing a rich range of emotions, showing healthy emotional complexity." :
                "You're tracking \(uniqueEmotions.count) different emotions, building emotional awareness."
            
            insights.append(AIInsight(
                title: "Emotional Range",
                description: diversityMessage,
                icon: "heart.text.square",
                color: .purple
            ))
        }
        
        // Insight 5: Growth opportunity
        if !growthArea.isEmpty && growthArea != "No Data" {
            insights.append(AIInsight(
                title: "Growth Opportunity",
                description: "Focus on \(growthArea.lowercased()) to enhance your emotional wellbeing journey.",
                icon: "arrow.up.right.circle",
                color: .mint
            ))
        }
        
        return insights
    }
    
    private func calculateEmotionalStability(from emotionalData: [EmotionalDataEntity]) -> String {
        // Simple stability calculation based on emotion variety
        let uniqueEmotions = Set(emotionalData.compactMap { $0.primaryEmotion })
        
        switch uniqueEmotions.count {
        case 0...1: return "Very Stable"
        case 2...3: return "Stable"
        case 4...5: return "Variable"
        default: return "Dynamic"
        }
    }
    
    private func calculateBestDay(from emotionalData: [EmotionalDataEntity]) -> String {
        let calendar = Calendar.current
        let weekdayCounts = emotionalData.reduce(into: [Int: Int]()) { counts, data in
            guard let timestamp = data.timestamp else { return }
            let weekday = calendar.component(.weekday, from: timestamp)
            counts[weekday, default: 0] += 1
        }
        
        guard let bestWeekday = weekdayCounts.max(by: { $0.value < $1.value })?.key else {
            return "No Data"
        }
        
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[bestWeekday - 1]
    }
    
    private func calculateGrowthArea(from emotionalData: [EmotionalDataEntity]) -> String {
        // Simple growth area calculation
        let negativeEmotions = emotionalData.filter { entity in
            guard let emotionString = entity.primaryEmotion else { return false }
            let emotion = EmotionCategory(rawValue: emotionString)
            return emotion == .sadness || emotion == .anger || emotion == .fear
        }
        
        let negativePercentage = Double(negativeEmotions.count) / Double(emotionalData.count)
        
        if negativePercentage > 0.5 {
            return "Emotional Regulation"
        } else if negativePercentage > 0.3 {
            return "Stress Management"
        } else {
            return "Emotional Awareness"
        }
    }
    
    private func calculateEmotionalValence(from emotions: [EmotionCategory]) -> EmotionValence {
        let positiveCount = emotions.filter { $0.valence == .positive }.count
        let negativeCount = emotions.filter { $0.valence == .negative }.count
        let neutralCount = emotions.filter { $0.valence == .neutral }.count
        
        let total = emotions.count
        if total == 0 { return .neutral }
        
        let positiveRatio = Double(positiveCount) / Double(total)
        let negativeRatio = Double(negativeCount) / Double(total)
        
        if positiveRatio > 0.5 {
            return .positive
        } else if negativeRatio > 0.5 {
            return .negative
        } else {
            return .neutral
        }
    }
    
    private func calculateAverageIntensity(from emotionalData: [EmotionalDataEntity]) -> EmotionIntensity {
        let intensities = emotionalData.compactMap { entity -> EmotionIntensity? in
            guard let emotionString = entity.primaryEmotion else { return nil }
            let emotion = EmotionCategory(rawValue: emotionString)
            return emotion?.intensity
        }
        
        if intensities.isEmpty { return .medium }
        
        let highCount = intensities.filter { $0 == .high }.count
        let mediumCount = intensities.filter { $0 == .medium }.count
        let lowCount = intensities.filter { $0 == .low }.count
        
        let total = intensities.count
        let highRatio = Double(highCount) / Double(total)
        let mediumRatio = Double(mediumCount) / Double(total)
        
        if highRatio > 0.4 {
            return .high
        } else if mediumRatio > 0.4 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Extensions
extension EmotionCategory {
    var color: Color {
        switch self {
        case .joy: return .yellow
        case .sadness: return .blue
        case .anger: return .red
        case .fear: return .purple
        case .surprise: return .orange
        case .disgust: return .green
        case .neutral: return .gray
        }
    }
}

extension EmotionValence {
    var emoji: String {
        switch self {
        case .positive: return "😊"
        case .negative: return "😔"
        case .neutral: return "😐"
        }
    }
    
    var icon: String {
        switch self {
        case .positive: return "heart.fill"
        case .negative: return "heart.slash.fill"
        case .neutral: return "heart"
        }
    }
}

extension EmotionIntensity {
    var IntensitydisplayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var Intensitycolor: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

extension InsightsViewModel {

    private func generateVoiceCharacteristicsData(from emotionalData: [EmotionalDataEntity]) -> [VoiceCharacteristicsDataPoint] {
        print("🔍 DEBUG: generateVoiceCharacteristicsData() started with \(emotionalData.count) emotional data entities")
        
        let voiceData: [VoiceCharacteristicsDataPoint] = emotionalData.compactMap { (entity: EmotionalDataEntity) -> VoiceCharacteristicsDataPoint? in
            guard let timestamp = entity.timestamp,
                  let emotionString = entity.primaryEmotion,
                  let emotion = EmotionCategory(rawValue: emotionString),
                  let voiceFeaturesData = entity.voiceFeaturesData else {
                print("🔍 DEBUG: Entity missing required data: timestamp=\(entity.timestamp != nil), emotion=\(entity.primaryEmotion != nil), voiceFeaturesData=\(entity.voiceFeaturesData != nil)")
                return nil
            }
            
            // Decode voice features
            do {
                let decoder = JSONDecoder()
                let voiceFeatures = try decoder.decode(VoiceFeatures.self, from: voiceFeaturesData)
                
                print("🔍 DEBUG: Decoded voice features for \(timestamp): pitch=\(voiceFeatures.pitch), energy=\(voiceFeatures.energy), spectralCentroid=\(voiceFeatures.spectralCentroid)")
                
                return VoiceCharacteristicsDataPoint(
                    timestamp: timestamp,
                    pitch: voiceFeatures.pitch,
                    energy: voiceFeatures.energy,
                    spectralCentroid: voiceFeatures.spectralCentroid,
                    jitter: voiceFeatures.jitter,
                    shimmer: voiceFeatures.shimmer,
                    formantFrequencies: voiceFeatures.formantFrequencies,
                    harmonicToNoiseRatio: voiceFeatures.harmonicToNoiseRatio,
                    zeroCrossingRate: voiceFeatures.zeroCrossingRate,
                    spectralRolloff: voiceFeatures.spectralRolloff,
                    voiceOnsetTime: voiceFeatures.voiceOnsetTime,
                    emotion: emotion,
                    confidence: entity.confidence
                )
            } catch {
                print("❌ Failed to decode voice features: \(error)")
                print("🔍 DEBUG: Raw voiceFeaturesData: \(String(data: voiceFeaturesData, encoding: .utf8) ?? "nil")")
                return nil
            }
        }.sorted { (first: VoiceCharacteristicsDataPoint, second: VoiceCharacteristicsDataPoint) -> Bool in
            return first.timestamp < second.timestamp
        }
        
        print("🔍 DEBUG: Successfully generated \(voiceData.count) voice characteristics data points")
        
        // Debug first few data points
        let firstThree = Array(voiceData.prefix(3))
        for (index, data) in firstThree.enumerated() {
            print("🔍 DEBUG: Voice data \(index + 1): timestamp=\(data.timestamp), pitch=\(data.pitch), energy=\(data.energy)")
        }
        
        // Debug energy value analysis
        if !voiceData.isEmpty {
            let energyValues = voiceData.map { $0.energy }
            let minEnergy = energyValues.min() ?? 0.0
            let maxEnergy = energyValues.max() ?? 0.0
            let avgEnergy = energyValues.reduce(0.0, +) / Double(energyValues.count)
            
            print("🔍 DEBUG: Energy Analysis - Min: \(minEnergy), Max: \(maxEnergy), Avg: \(avgEnergy)")
            print("🔍 DEBUG: Energy value distribution:")
            for (index, energy) in energyValues.enumerated() {
                print("  Data point \(index + 1): \(energy)")
            }
        }
        
        return voiceData
    }
    
    private func generateVoiceInsights(from voiceData: [VoiceCharacteristicsDataPoint]) -> [VoiceInsight] {
        var insights: [VoiceInsight] = []
        
        guard !voiceData.isEmpty else {
            insights.append(VoiceInsight(
                title: "Start Emotion Tracking",
                description: "Record your voice while expressing emotions to see how your voice reflects your feelings and emotional patterns.",
                category: "Getting Started",
                icon: "waveform.circle",
                color: .blue
            ))
            return insights
        }
        
        // Constants for voice analysis - Updated for emotion tracking app
        enum VoiceAnalysisConstants {
            // Pitch thresholds (Hz) - research-based ranges
            static let malePitchRange = 85.0...155.0
            static let femalePitchRange = 165.0...255.0
            static let highPitchThreshold = 200.0
            
            // Energy thresholds (0-1 scale) - Adjusted for emotional expression
            static let lowEnergyThreshold = 0.3     // Calm, subdued emotions
            static let moderateEnergyThreshold = 0.6 // Normal conversation
            static let highEnergyThreshold = 0.8    // Excited, intense emotions
            
            // Voice quality thresholds
            static let excellentHNRThreshold = 15.0
            static let goodHNRThreshold = 10.0
            
            // Stability thresholds - Updated for emotion tracking (higher values are normal)
            static let calmJitterThreshold = 0.03      // 3.0% - Calm emotional expression
            static let calmShimmerThreshold = 0.03     // 3.0%
            static let normalJitterThreshold = 0.06    // 6.0% - Normal emotional expression
            static let normalShimmerThreshold = 0.06   // 6.0%
            static let expressiveThreshold = 0.10      // 10.0% - Highly expressive emotions
        }
        
        // Filter valid data for analysis
        let validVoiceData = voiceData.filter { point in
            point.pitch > 0 && point.pitch < 800 && // Valid human pitch range
            point.energy >= 0 && point.energy <= 1   // Valid energy range
        }
        
        guard !validVoiceData.isEmpty else {
            insights.append(VoiceInsight(
                title: "Data Quality Issue",
                description: "Voice data appears to have quality issues. Please ensure proper recording conditions.",
                category: "Data Quality",
                icon: "exclamationmark.triangle",
                color: .orange
            ))
            return insights
        }
        
        // Pitch Analysis with improved accuracy
        let pitches: [Double] = validVoiceData.map { $0.pitch }
        let avgPitch = pitches.reduce(0.0, +) / Double(pitches.count)
        let maxPitch = pitches.max() ?? 0.0
        let minPitch = pitches.min() ?? 0.0
        let pitchRange = maxPitch - minPitch
        
        // More nuanced pitch analysis
        if VoiceAnalysisConstants.femalePitchRange.contains(avgPitch) {
            insights.append(VoiceInsight(
                title: "Female Vocal Range",
                description: "Your average pitch is \(String(format: "%.0f", avgPitch)) Hz, within typical female range. Pitch variation: \(String(format: "%.0f", pitchRange)) Hz shows your emotional expressiveness.",
                category: "Pitch",
                icon: "waveform.path.ecg",
                color: .blue
            ))
        } else if VoiceAnalysisConstants.malePitchRange.contains(avgPitch) {
            insights.append(VoiceInsight(
                title: "Male Vocal Range",
                description: "Your average pitch is \(String(format: "%.0f", avgPitch)) Hz, within typical male range. Pitch variation: \(String(format: "%.0f", pitchRange)) Hz reflects your emotional engagement.",
                category: "Pitch",
                icon: "waveform.path.ecg",
                color: .blue
            ))
        } else if avgPitch > VoiceAnalysisConstants.highPitchThreshold {
            insights.append(VoiceInsight(
                title: "Higher Pitch Range",
                description: "Your average pitch is \(String(format: "%.0f", avgPitch)) Hz, indicating expressive or excited emotional patterns in your voice.",
                category: "Pitch",
                icon: "waveform.path.ecg",
                color: .blue
            ))
        } else {
            insights.append(VoiceInsight(
                title: "Lower Pitch Range",
                description: "Your average pitch is \(String(format: "%.0f", avgPitch)) Hz, showing calm and measured emotional expression patterns.",
                category: "Pitch",
                icon: "waveform.path.ecg",
                color: .blue
            ))
        }
        
        // Energy Analysis with emotion-focused thresholds
        let energies: [Double] = validVoiceData.map { $0.energy }
        let avgEnergy = energies.reduce(0.0, +) / Double(energies.count)
        let maxEnergy = energies.max() ?? 0.0
        let minEnergy = energies.min() ?? 0.0
        let energyVariation = maxEnergy - minEnergy
        
        if avgEnergy > VoiceAnalysisConstants.highEnergyThreshold {
            insights.append(VoiceInsight(
                title: "High Emotional Energy",
                description: "Your voice shows strong energy levels (\(String(format: "%.2f", avgEnergy))), indicating intense emotional expression and passionate communication.",
                category: "Energy",
                icon: "speaker.wave.3",
                color: .green
            ))
        } else if avgEnergy > VoiceAnalysisConstants.moderateEnergyThreshold {
            insights.append(VoiceInsight(
                title: "Balanced Emotional Energy",
                description: "Your voice shows balanced energy levels (\(String(format: "%.2f", avgEnergy))), indicating healthy emotional engagement in conversation.",
                category: "Energy",
                icon: "speaker.wave.2",
                color: .green
            ))
        } else {
            insights.append(VoiceInsight(
                title: "Calm Emotional Energy",
                description: "Your voice shows gentle energy levels (\(String(format: "%.2f", avgEnergy))), indicating calm, reflective emotional states.",
                category: "Energy",
                icon: "speaker.wave.1",
                color: .green
            ))
        }
        
        // Voice Stability Analysis with emotion-appropriate thresholds
        let jitterValues = validVoiceData.compactMap { point -> Double? in
            guard let jitter = point.jitter, jitter >= 0 && jitter <= 0.2 else { return nil }
            return jitter
        }
        let shimmerValues = validVoiceData.compactMap { point -> Double? in
            guard let shimmer = point.shimmer, shimmer >= 0 && shimmer <= 0.2 else { return nil }
            return shimmer
        }
        
        if !jitterValues.isEmpty && !shimmerValues.isEmpty {
            let avgJitter = jitterValues.reduce(0, +) / Double(jitterValues.count)
            let avgShimmer = shimmerValues.reduce(0, +) / Double(shimmerValues.count)
            let maxVariation = max(avgJitter, avgShimmer)
            
            if maxVariation < VoiceAnalysisConstants.calmJitterThreshold {
                insights.append(VoiceInsight(
                    title: "Calm Expression Style",
                    description: "Your voice shows controlled variation with jitter (\(String(format: "%.2f", avgJitter * 100))%) and shimmer (\(String(format: "%.2f", avgShimmer * 100))%), indicating calm emotional expression.",
                    category: "Expression",
                    icon: "leaf.circle",
                    color: .blue
                ))
            } else if maxVariation < VoiceAnalysisConstants.normalJitterThreshold {
                insights.append(VoiceInsight(
                    title: "Natural Expression Style",
                    description: "Your voice shows healthy variation with jitter (\(String(format: "%.2f", avgJitter * 100))%) and shimmer (\(String(format: "%.2f", avgShimmer * 100))%), indicating natural emotional engagement.",
                    category: "Expression",
                    icon: "heart.circle",
                    color: .green
                ))
            } else if maxVariation < VoiceAnalysisConstants.expressiveThreshold {
                insights.append(VoiceInsight(
                    title: "Expressive Communication Style",
                    description: "Your voice shows rich variation with jitter (\(String(format: "%.2f", avgJitter * 100))%) and shimmer (\(String(format: "%.2f", avgShimmer * 100))%), indicating highly expressive emotional communication.",
                    category: "Expression",
                    icon: "theatermasks.circle",
                    color: .purple
                ))
            } else {
                insights.append(VoiceInsight(
                    title: "Intense Expression Style",
                    description: "Your voice shows significant variation with jitter (\(String(format: "%.2f", avgJitter * 100))%) and shimmer (\(String(format: "%.2f", avgShimmer * 100))%), indicating very intense emotional expression.",
                    category: "Expression",
                    icon: "flame.circle",
                    color: .red
                ))
            }
        }
        
        // Voice Quality Analysis with safe HNR calculation
        let hnrValues = validVoiceData.compactMap { point -> Double? in
            guard let hnr = point.harmonicToNoiseRatio, hnr >= -10 && hnr <= 40 else { return nil }
            return hnr
        }
        
        if !hnrValues.isEmpty {
            let avgHNR = hnrValues.reduce(0, +) / Double(hnrValues.count)
            
            if avgHNR > VoiceAnalysisConstants.excellentHNRThreshold {
                insights.append(VoiceInsight(
                    title: "Excellent Voice Quality",
                    description: "Your harmonic-to-noise ratio is \(String(format: "%.1f", avgHNR)) dB, indicating excellent voice clarity that enhances emotional communication.",
                    category: "Quality",
                    icon: "waveform.path.ecg.rectangle",
                    color: .mint
                ))
            } else if avgHNR > VoiceAnalysisConstants.goodHNRThreshold {
                insights.append(VoiceInsight(
                    title: "Good Voice Quality",
                    description: "Your harmonic-to-noise ratio is \(String(format: "%.1f", avgHNR)) dB, showing good voice quality that supports clear emotional expression.",
                    category: "Quality",
                    icon: "waveform.path.ecg.rectangle",
                    color: .mint
                ))
            } else {
                insights.append(VoiceInsight(
                    title: "Voice Quality Considerations",
                    description: "Your harmonic-to-noise ratio is \(String(format: "%.1f", avgHNR)) dB. Consider vocal warm-ups or hydration to enhance emotional expression clarity.",
                    category: "Quality",
                    icon: "waveform.path.ecg.rectangle",
                    color: .yellow
                ))
            }
        }
        
        // Emotion-Voice Correlation Analysis
        let emotionGroups = Dictionary(grouping: validVoiceData) { $0.emotion }
        if emotionGroups.count > 1 {
            // Analyze pitch variation across emotions
            var emotionPitchAnalysis: [(emotion: EmotionCategory, avgPitch: Double)] = []
            for (emotion, dataPoints) in emotionGroups {
                let emotionPitches = dataPoints.map { $0.pitch }
                let avgEmotionPitch = emotionPitches.reduce(0, +) / Double(emotionPitches.count)
                emotionPitchAnalysis.append((emotion, avgEmotionPitch))
            }
            
            let emotionPitches = emotionPitchAnalysis.map { $0.avgPitch }
            let maxEmotionPitch = emotionPitches.max() ?? 0.0
            let minEmotionPitch = emotionPitches.min() ?? 0.0
            let pitchVariationAcrossEmotions = maxEmotionPitch - minEmotionPitch
            
            if pitchVariationAcrossEmotions > 50 { // Significant variation
                insights.append(VoiceInsight(
                    title: "Strong Voice-Emotion Patterns",
                    description: "Your voice shows significant pitch variation (\(String(format: "%.0f", pitchVariationAcrossEmotions)) Hz) across different emotions, indicating authentic and natural emotional expression.",
                    category: "Patterns",
                    icon: "brain.head.profile",
                    color: .pink
                ))
            } else {
                insights.append(VoiceInsight(
                    title: "Consistent Voice Patterns",
                    description: "Your voice maintains relatively consistent characteristics across emotions, showing emotional stability and controlled expression.",
                    category: "Patterns",
                    icon: "brain.head.profile",
                    color: .pink
                ))
            }
        }
        
        // Data quality insight
        let dataQualityScore = Double(validVoiceData.count) / Double(voiceData.count)
        if dataQualityScore < 0.8 {
            insights.append(VoiceInsight(
                title: "Recording Quality",
                description: "Consider improving recording conditions for more accurate emotion-voice analysis. \(String(format: "%.0f", dataQualityScore * 100))% of data was usable.",
                category: "Data Quality",
                icon: "mic.badge.xmark",
                color: .orange
            ))
        }
        
        return insights
    }
    
    // Updated constants for emotion tracking
    private enum StabilityConstants {
        static let chartHeight = 200.0
        static let maxDisplayRange = 0.12 // 12% maximum for emotion tracking
        static let calmThreshold = 0.03   // 3.0% - Calm emotions
        static let normalThreshold = 0.06 // 6.0% - Normal emotional expression
        static let expressiveThreshold = 0.10 // 10.0% - Highly expressive
        static let barWidth = 8.0
    }

    // Prepare data for side-by-side visualization
    private var chartData: [(timestamp: Date, jitter: Double?, shimmer: Double?, hasData: Bool)] {
        return data.map { point in
            (
                timestamp: point.timestamp,
                jitter: point.jitter,
                shimmer: point.shimmer,
                hasData: point.jitter != nil || point.shimmer != nil
            )
        }.filter { $0.hasData }
    }
    
    // Quality indicator based on average values - Updated for emotion tracking
    private var stabilityQualityIndicator: some View {
        
        let validJitterValues = data.compactMap { $0.jitter }.filter { $0 >= 0 && $0 <= 0.2 }
        let validShimmerValues = data.compactMap { $0.shimmer }.filter { $0 >= 0 && $0 <= 0.2 }
        
        let avgJitter = validJitterValues.isEmpty ? 0 : validJitterValues.reduce(0, +) / Double(validJitterValues.count)
        let avgShimmer = validShimmerValues.isEmpty ? 0 : validShimmerValues.reduce(0, +) / Double(validShimmerValues.count)
        
        let overallExpression = max(avgJitter, avgShimmer)
        
        let (color, text) = {
            if overallExpression < StabilityConstants.calmThreshold {
                return (Color.blue, "Calm")
            } else if overallExpression < StabilityConstants.normalThreshold {
                return (Color.green, "Natural")
            } else if overallExpression < StabilityConstants.expressiveThreshold {
                return (Color.purple, "Expressive")
            } else {
                return (Color.red, "Intense")
            }
        }()
        
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}
