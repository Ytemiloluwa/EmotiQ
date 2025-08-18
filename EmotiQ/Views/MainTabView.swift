//
//  MainTabView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import SwiftUI
import CoreData
import Combine

// MARK: - Main Tab View
/// Production-ready tab navigation structure for EmotiQ
/// Provides intuitive access to all core features with beautiful design
struct MainTabView: View {
    @StateObject private var tabViewModel = TabViewModel()
    @StateObject private var themeManager = ThemeManager()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var emotionService: CoreMLEmotionService
    
    var body: some View {
        TabView(selection: $tabViewModel.selectedTab) {
            // MARK: - Dashboard Tab
            DashboardView()
                .tabItem {
                    Image(systemName: tabViewModel.selectedTab == .dashboard ? "brain.head.profile.fill" : "brain.head.profile")
                    Text("Dashboard")
                }
                .tag(TabItem.dashboard)
            
            // MARK: - Voice Analysis Tab
            VoiceAnalysisView()
                .tabItem {
                    Image(systemName: tabViewModel.selectedTab == .voice ? "waveform.circle.fill" : "waveform.circle")
                    Text("Voice Check")
                }
                .tag(TabItem.voice)
            
            // MARK: - Insights Tab
            InsightsView()
                .tabItem {
                    Image(systemName: tabViewModel.selectedTab == .insights ? "chart.line.uptrend.xyaxis.circle.fill" : "chart.line.uptrend.xyaxis.circle")
                    Text("Insights")
                }
                .tag(TabItem.insights)
            
            // MARK: - Coaching Tab
            CoachingView()
                .tabItem {
                    Image(systemName: tabViewModel.selectedTab == .coaching ? "person.crop.circle.badge.checkmark.fill" : "person.crop.circle.badge.checkmark")
                    Text("Coaching")
                }
                .tag(TabItem.coaching)
            
            // MARK: - Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: tabViewModel.selectedTab == .profile ? "person.circle.fill" : "person.circle")
                    Text("Profile")
                }
                .tag(TabItem.profile)
        }
        .accentColor(ThemeColors.accent)
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.getColorScheme())
        .onAppear {
            setupTabBarAppearance()
            tabViewModel.setSubscriptionService(subscriptionService)
        }
        .sheet(isPresented: $tabViewModel.showingSubscriptionPaywall) {
            SubscriptionPaywallView()
        }
        .alert("Premium Feature", isPresented: $tabViewModel.showingPremiumAlert) {
            Button("Upgrade") {
                tabViewModel.showingSubscriptionPaywall = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This feature requires a Premium subscription. Upgrade now to unlock unlimited access to EmotiQ's Emotional coaching features.")
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Dynamic background color based on theme
        if themeManager.isDarkMode {
            appearance.backgroundColor = UIColor.systemBackground
        } else {
            appearance.backgroundColor = UIColor.systemBackground
        }
        
        // Selected tab color - use theme accent
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(ThemeColors.accent)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(ThemeColors.accent)
        ]
        
        // Normal tab color - adaptive
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Tab Items
enum TabItem: String, CaseIterable {
    case dashboard = "dashboard"
    case voice = "voice"
    case insights = "insights"
    case coaching = "coaching"
    case profile = "profile"
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .voice: return "Voice Check"
        case .insights: return "Insights"
        case .coaching: return "Coaching"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "brain.head.profile"
        case .voice: return "waveform.circle"
        case .insights: return "chart.line.uptrend.xyaxis.circle"
        case .coaching: return "person.crop.circle.badge.checkmark"
        case .profile: return "person.circle"
        }
    }
    
    var filledIcon: String {
        return icon + ".fill"
    }
    
    var requiresPremium: Bool {
        switch self {
        case .dashboard, .voice, .profile:
            return false
        case .insights, .coaching:
            // TODO: Re-enable paywall after development/testing
            return false // Temporarily disabled for development
            // return true
        }
    }
}

// MARK: - Tab View Model
@MainActor
class TabViewModel: ObservableObject {
    @Published var selectedTab: TabItem = .dashboard
    @Published var showingSubscriptionPaywall = false
    @Published var showingPremiumAlert = false
    
    private var subscriptionService: SubscriptionService?
    
    func setSubscriptionService(_ service: SubscriptionService) {
        self.subscriptionService = service
    }
    
    func selectTab(_ tab: TabItem) {
        // Check if premium feature requires subscription
        if tab.requiresPremium && !(subscriptionService?.hasActiveSubscription ?? false) {
            showingPremiumAlert = true
            return
        }
        
        selectedTab = tab
    }
    
    func handlePremiumFeatureAccess() {
        if subscriptionService?.hasActiveSubscription ?? false {
            return // User has access
        }
        
        showingPremiumAlert = true
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject private var emotionService: CoreMLEmotionService
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var dashboardViewModel = DashboardViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Header
                    DashboardHeaderView()
                    
                    // MARK: - Quick Actions
                    QuickActionsView()
                    
                    // MARK: - Recent Analysis
                    if let lastResult = emotionService.lastAnalysisResult {
                        RecentAnalysisCard(result: lastResult)
                    }
                    
                    // MARK: - Today's Summary
                    TodaySummaryCard(viewModel: dashboardViewModel)
                    
                    // MARK: - Emotion Trends
                    EmotionTrendsCard(viewModel: dashboardViewModel)
                    
                    Spacer(minLength: 100) // Tab bar spacing
                }
                .padding(.horizontal)
            }
            .navigationTitle("EmotiQ")
            .navigationBarTitleDisplayMode(.large)
            .themedBackground(.gradient)
            .background(ThemeColors.backgroundGradient)
            .onAppear {
                dashboardViewModel.refreshData()
            }
        }
    }
}

// MARK: - Dashboard Header
struct DashboardHeaderView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var currentTime = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(greetingText)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("How are you feeling today?")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Spacer()
                
                // Notification bell
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.title2)
                        .foregroundColor(ThemeColors.accent)
                }
            }
        }
        .onAppear {
            currentTime = Date()
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Evening"
        }
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            HStack(spacing: 15) {
                QuickActionButton(
                    title: "Voice Check",
                    icon: "waveform.circle.fill",
                    color: ThemeColors.accent,
                    action: {}
                )
                
                QuickActionButton(
                    title: "Breathing",
                    icon: "lungs.fill",
                    color: .blue,
                    action: {}
                )
                
                QuickActionButton(
                    title: "Journal",
                    icon: "book.fill",
                    color: ThemeColors.success,
                    action: {}
                )
                
                QuickActionButton(
                    title: "Insights",
                    icon: "chart.bar.fill",
                    color: ThemeColors.warning,
                    action: {}
                )
            }
        }
    }
}

struct QuickActionButton: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(themeManager.isDarkMode ? 0.2 : 0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Analysis Card
struct RecentAnalysisCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let result: EmotionAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
            }
            
            HStack(spacing: 15) {
                // Emotion display
                VStack {
                    Text(result.primaryEmotion.emoji)
                        .font(.system(size: 40))
                    
                    Text(result.primaryEmotion.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                }
                
                Spacer()
                
                // Confidence meter
                VStack(alignment: .trailing) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    Text("\(result.confidencePercentage)%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(result.isHighConfidence ? ThemeColors.success : ThemeColors.warning)
                }
            }
            
            // Coaching tip preview
            Text(result.primaryEmotion.coachingTip)
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
                .lineLimit(2)
        }
        .padding()
        .themedCard()
    }
}

// MARK: - Today's Summary Card
struct TodaySummaryCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                SummaryItem(title: "Check-ins", value: "\(viewModel.todayCheckIns)", icon: "checkmark.circle.fill", color: .green)
                SummaryItem(title: "Avg Mood", value: viewModel.averageMood.emoji, icon: "heart.fill", color: .pink)
                SummaryItem(title: "Streak", value: "\(viewModel.currentStreak)", icon: "flame.fill", color: .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
}

struct SummaryItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Emotion Trends Card
struct EmotionTrendsCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week's Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {}
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            HStack(spacing: 8) {
                ForEach(Array(viewModel.weeklyTrendData.enumerated()), id: \.offset) { index, data in
                    VStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(data.emotion.color.opacity(0.7))
                            .frame(width: 8, height: CGFloat(data.intensity * 60))
                        
                        Text("\(index + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Dashboard View Model
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var todayCheckIns = 0
    @Published var currentStreak = 0
    @Published var averageMood: EmotionCategory = .neutral
    @Published var weeklyTrendData: [EmotionTrendData] = []
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadTodayData()
        setupNotifications()
    }
    
    func refreshData() {
        loadTodayData()
    }
    
    private func setupNotifications() {
        // Listen for new emotional data being saved
        NotificationCenter.default.publisher(for: .emotionalDataSaved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
    
    private func loadTodayData() {
        // Load real data from Core Data
        loadTodayCheckIns()
        loadCurrentStreak()
        loadAverageMood()
        loadWeeklyTrendData()
    }
    
    private func loadTodayCheckIns() {
        guard let user = persistenceController.getCurrentUser() else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND timestamp >= %@ AND timestamp < %@", user, today as NSDate, tomorrow as NSDate)
        
        do {
            let results = try persistenceController.container.viewContext.fetch(request)
            todayCheckIns = results.count
        } catch {
            print("❌ Failed to fetch today's check-ins: \(error)")
            todayCheckIns = 0
        }
    }
    
    private func loadCurrentStreak() {
        guard let user = persistenceController.getCurrentUser() else { return }
        
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: false)]
        
        do {
            let emotionalData = try persistenceController.container.viewContext.fetch(request)
            currentStreak = calculateCurrentStreak(from: emotionalData)
        } catch {
            print("❌ Failed to fetch emotional data for streak: \(error)")
            currentStreak = 0
        }
    }
    
    private func loadAverageMood() {
        guard let user = persistenceController.getCurrentUser() else { return }
        
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND timestamp >= %@", user, weekAgo as NSDate)
        
        do {
            let emotionalData = try persistenceController.container.viewContext.fetch(request)
            let emotions = emotionalData.compactMap { entity -> EmotionCategory? in
                guard let emotionString = entity.primaryEmotion else { return nil }
                return EmotionCategory(rawValue: emotionString)
            }
            
            if !emotions.isEmpty {
                averageMood = calculateAverageMood(from: emotions)
            }
        } catch {
            print("❌ Failed to fetch emotional data for average mood: \(error)")
            averageMood = .neutral
        }
    }
    
    private func loadWeeklyTrendData() {
        guard let user = persistenceController.getCurrentUser() else { return }
        
        let calendar = Calendar.current
        let today = Date()
        
        weeklyTrendData = (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
            
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
            
            let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
            request.predicate = NSPredicate(format: "user == %@ AND timestamp >= %@ AND timestamp < %@", user, dayStart as NSDate, dayEnd as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: false)]
            request.fetchLimit = 1
            
            do {
                let results = try persistenceController.container.viewContext.fetch(request)
                if let lastData = results.first,
                   let emotionString = lastData.primaryEmotion,
                   let emotion = EmotionCategory(rawValue: emotionString) {
                    return EmotionTrendData(
                        date: date,
                        emotion: emotion,
                        intensity: lastData.intensity
                    )
                }
            } catch {
                print("❌ Failed to fetch trend data for day \(dayOffset): \(error)")
            }
            
            return nil
        }.reversed()
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
    
    private func calculateAverageMood(from emotions: [EmotionCategory]) -> EmotionCategory {
        let emotionCounts = emotions.reduce(into: [EmotionCategory: Int]()) { counts, emotion in
            counts[emotion, default: 0] += 1
        }
        
        return emotionCounts.max(by: { $0.value < $1.value })?.key ?? .neutral
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(SubscriptionService())
            .environmentObject(CoreMLEmotionService())
    }
}
