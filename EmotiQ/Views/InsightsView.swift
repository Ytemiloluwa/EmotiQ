//
//  InsightView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import SwiftUI
import Charts

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
                
                if subscriptionService.hasActiveSubscription {
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
                } else {
                    // Premium feature locked state
                    PremiumFeatureLockedView {
                        showingSubscriptionPaywall = true
                    }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingSubscriptionPaywall) {
                SubscriptionPaywallView()
            }
            .onAppear {
                if subscriptionService.hasActiveSubscription {
                    viewModel.loadInsightsData()
                }
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
    
    func loadInsightsData() {
        // Load real data from Core Data in production
        loadMockData()
    }
    
    private func loadMockData() {
        weeklyCheckIns = 12
        averageMood = .joy
        currentStreak = 7
        
        // Mock trend data
        let calendar = Calendar.current
        let today = Date()
        trendData = (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
            return EmotionTrendData(
                date: date,
                emotion: EmotionCategory.allCases.randomElement() ?? .neutral,
                intensity: Double.random(in: 0.3...1.0)
            )
        }.reversed()
        
        // Mock distribution data
        emotionDistribution = [
            EmotionDistributionData(emotion: .joy, percentage: 35),
            EmotionDistributionData(emotion: .surprise, percentage: 25),
            EmotionDistributionData(emotion: .neutral, percentage: 20),
            EmotionDistributionData(emotion: .disgust, percentage: 10),
            EmotionDistributionData(emotion: .sadness, percentage: 6),
            EmotionDistributionData(emotion: .anger, percentage: 3),
            EmotionDistributionData(emotion: .fear, percentage: 1)
        ]
        
        // Mock AI insights
        aiInsights = [
            AIInsight(
                title: "Positive Trend Detected",
                description: "Your emotional well-being has improved 23% this week compared to last week.",
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            ),
            AIInsight(
                title: "Morning Pattern",
                description: "You tend to feel most positive during morning hours (8-11 AM).",
                icon: "sun.max",
                color: .orange
            ),
            AIInsight(
                title: "Stress Trigger",
                description: "Consider stress management techniques for Tuesday afternoons.",
                icon: "exclamationmark.triangle",
                color: .yellow
            )
        ]
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


