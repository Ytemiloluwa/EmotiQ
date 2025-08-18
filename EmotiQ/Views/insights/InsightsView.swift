//
//  InsightsView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//


import SwiftUI
import Charts
import CoreData

// MARK: - Insights View
/// Production-ready insights and analytics view with emotion visualization
/// Provides comprehensive emotional intelligence tracking and trends
struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var showingSubscriptionPaywall = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.cyan.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // TODO: Re-enable paywall check when InsightsView is production ready
                // if subscriptionService.hasActiveSubscription {
                
                    // Premium insights content
                    ScrollView {
                        VStack(spacing: 20) {
                            // MARK: - Overview Cards
                            InsightsOverviewSection(viewModel: viewModel)
                            
                            // MARK: - Emotion Trends Chart
                            EmotionTrendsChart(viewModel: viewModel)
                            
                            // MARK: - Weekly Summary
                            WeeklySummarySection(viewModel: viewModel)
                            
                            // MARK: - Emotion Distribution
                            EmotionDistributionChart(viewModel: viewModel)
                            
                            // MARK: - Patterns & Insights
                            PatternsInsightsSection(viewModel: viewModel)
                            
                            Spacer(minLength: 100) // Tab bar spacing
                        }
                        .padding(.horizontal)
                    }
                
                // TODO: Re-enable premium feature locked state
                // } else {
                //     // Premium feature locked state
                //     PremiumFeatureLockedView {
                //         showingSubscriptionPaywall = true
                //     }
                // }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            // TODO: Re-enable subscription paywall sheet when InsightsView is production ready
            // .sheet(isPresented: $showingSubscriptionPaywall) {
            //     SubscriptionPaywallView()
            // }
            .onAppear {
                // TODO: Re-enable subscription check when InsightsView is production ready
                // if subscriptionService.hasActiveSubscription {
                    viewModel.loadInsightsData()
                // }
            }
        }
    }
}

// MARK: - Premium Feature Locked View
struct PremiumFeatureLockedView: View {
    let upgradeAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Premium Feature")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Unlock detailed insights and analytics about your emotional patterns with Premium")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Preview features
            VStack(alignment: .leading, spacing: 12) {
                FeaturePreviewRow(icon: "chart.line.uptrend.xyaxis", title: "Emotion Trends Over Time")
                FeaturePreviewRow(icon: "chart.pie", title: "Emotion Distribution Analysis")
                FeaturePreviewRow(icon: "brain.head.profile", title: "AI-Powered Pattern Recognition")
                FeaturePreviewRow(icon: "calendar", title: "Weekly & Monthly Reports")
                FeaturePreviewRow(icon: "target", title: "Personalized Recommendations")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            
            Button(action: upgradeAction) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Premium")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
        }
        .padding()
    }
}

struct FeaturePreviewRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "checkmark")
                .foregroundColor(.green)
                .font(.caption)
        }
    }
}

// MARK: - Insights Overview Section
struct InsightsOverviewSection: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 15) {
                OverviewCard(
                    title: "This Week",
                    value: "\(viewModel.weeklyCheckIns)",
                    subtitle: "Check-ins",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                OverviewCard(
                    title: "Avg Mood",
                    value: viewModel.averageMood.emoji,
                    subtitle: viewModel.averageMood.displayName,
                    icon: "heart.fill",
                    color: .pink
                )
                
                OverviewCard(
                    title: "Streak",
                    value: "\(viewModel.currentStreak)",
                    subtitle: "Days",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
    }
}

struct OverviewCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Emotion Trends Chart
struct EmotionTrendsChart: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Emotion Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    Text("Week").tag(InsightsPeriod.week)
                    Text("Month").tag(InsightsPeriod.month)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 120)
            }
            
            // Chart placeholder - would use Swift Charts in production
            VStack {
                HStack {
                    Text("Emotional Intensity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                // Mock chart visualization
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(viewModel.trendData, id: \.date) { dataPoint in
                        VStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(dataPoint.emotion.color)
                                .frame(width: 12, height: CGFloat(dataPoint.intensity * 80))
                            
                            Text(dataPoint.emotion.emoji)
                                .font(.caption2)
                        }
                    }
                }
                .frame(height: 100)
                
                HStack {
                    Text(viewModel.selectedPeriod == .week ? "Last 7 Days" : "Last 30 Days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
}

// MARK: - Weekly Summary Section
struct WeeklySummarySection: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                SummaryRow(
                    title: "Most Common Emotion",
                    value: viewModel.mostCommonEmotion.displayName,
                    emoji: viewModel.mostCommonEmotion.emoji
                )
                
                SummaryRow(
                    title: "Emotional Stability",
                    value: viewModel.emotionalStability,
                    emoji: "📊"
                )
                
                SummaryRow(
                    title: "Best Day",
                    value: viewModel.bestDay,
                    emoji: "⭐"
                )
                
                SummaryRow(
                    title: "Growth Area",
                    value: viewModel.growthArea,
                    emoji: "🌱"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    let emoji: String
    
    var body: some View {
        HStack {
            Text(emoji)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
}

// MARK: - Emotion Distribution Chart
struct EmotionDistributionChart: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emotion Distribution")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(viewModel.emotionDistribution, id: \.emotion) { data in
                    EmotionDistributionRow(
                        emotion: data.emotion,
                        percentage: data.percentage
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
}

struct EmotionDistributionRow: View {
    let emotion: EmotionCategory
    let percentage: Double
    
    var body: some View {
        HStack {
            Text(emotion.emoji)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(emotion.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ProgressView(value: percentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: emotion.color))
            }
            
            Text("\(Int(percentage))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Patterns & Insights Section
struct PatternsInsightsSection: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(viewModel.aiInsights, id: \.id) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }
}

struct InsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .foregroundColor(insight.color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Data Models
struct EmotionTrendData {
    let date: Date
    let emotion: EmotionCategory
    let intensity: Double
}

struct EmotionDistributionData {
    let emotion: EmotionCategory
    let percentage: Double
}

struct AIInsight {
    let id = UUID()
    let title: String
    let description: String
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
    @Published var weeklyCheckIns = 0
    @Published var averageMood: EmotionCategory = .neutral
    @Published var currentStreak = 0
    @Published var mostCommonEmotion: EmotionCategory = .joy
    @Published var emotionalStability = "Stable"
    @Published var bestDay = "Tuesday"
    @Published var growthArea = "Stress Management"
    @Published var trendData: [EmotionTrendData] = []
    @Published var emotionDistribution: [EmotionDistributionData] = []
    @Published var aiInsights: [AIInsight] = []
    
    private let persistenceController = PersistenceController.shared
    
    func loadInsightsData() {
        loadRealData()
    }
    
    private func loadRealData() {
        guard let user = persistenceController.getCurrentUser() else {
            // No user data available, show empty state
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
        request.predicate = NSPredicate(format: "user == %@", user)
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
        
        // Generate distribution data
        emotionDistribution = generateDistributionData(from: emotions)
        
        // Generate AI insights
        aiInsights = generateAIInsights(from: emotionalData, emotions: emotions)
        
        // Calculate other metrics
        emotionalStability = calculateEmotionalStability(from: emotionalData)
        bestDay = calculateBestDay(from: emotionalData)
        growthArea = calculateGrowthArea(from: emotionalData)
    }
    
    private func resetToEmptyState() {
        weeklyCheckIns = 0
        averageMood = .neutral
        currentStreak = 0
        mostCommonEmotion = .neutral
        emotionalStability = "No Data"
        bestDay = "No Data"
        growthArea = "No Data"
        trendData = []
        emotionDistribution = []
        aiInsights = []
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
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
            
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
            
            let dayData = emotionalData.filter { entity in
                guard let timestamp = entity.timestamp else { return false }
                return timestamp >= dayStart && timestamp < dayEnd
            }
            
            if let lastData = dayData.first,
               let emotionString = lastData.primaryEmotion,
               let emotion = EmotionCategory(rawValue: emotionString) {
            return EmotionTrendData(
                date: date,
                    emotion: emotion,
                    intensity: lastData.intensity
            )
            }
            
            return nil
        }.reversed()
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
    
    private func generateAIInsights(from emotionalData: [EmotionalDataEntity], emotions: [EmotionCategory]) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Insight 1: Most common emotion
        let mostCommon = calculateMostCommonEmotion(from: emotions)
        insights.append(AIInsight(
            title: "Most Common Emotion",
            description: "You've been feeling \(mostCommon.displayName.lowercased()) most often recently.",
            icon: "brain.head.profile",
            color: .blue
        ))
        
        // Insight 2: Streak information
        if currentStreak > 0 {
            insights.append(AIInsight(
                title: "Consistent Check-ins",
                description: "You've been checking in for \(currentStreak) consecutive days. Great consistency!",
                icon: "flame.fill",
                color: .orange
            ))
        }
        
        // Insight 3: Weekly activity
        if weeklyCheckIns > 0 {
            insights.append(AIInsight(
                title: "Weekly Activity",
                description: "You've completed \(weeklyCheckIns) emotional check-ins this week.",
                icon: "chart.bar.fill",
                color: .green
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
        formatter.weekdaySymbols[bestWeekday - 1]
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

// MARK: - Preview
struct InsightsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightsView()
            .environmentObject(SubscriptionService())
    }
}

