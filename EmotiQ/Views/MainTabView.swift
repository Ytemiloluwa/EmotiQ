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
    @StateObject private var notificationManager = OneSignalNotificationManager.shared
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var emotionService: CoreMLEmotionService

    
    var body: some View {
        TabView(selection: $tabViewModel.selectedTab) {
            // MARK: - Dashboard Tab
            DashboardView(tabViewModel: tabViewModel)
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
                            FeatureGateView(feature: .advancedAnalytics) {
                    InsightsView()
                }
                .tabItem {
                    Image(systemName: tabViewModel.selectedTab == .insights ? "chart.line.uptrend.xyaxis.circle.fill" : "chart.line.uptrend.xyaxis.circle")
                    Text("Insights")
                }
                .tag(TabItem.insights)
            
            // MARK: - Coaching Tab
                            FeatureGateView(feature: .personalizedCoaching) {
                    CoachingView()
                }
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
        .onChange(of: tabViewModel.selectedTab) { oldValue, newValue in
            // Provide haptic feedback when tab bar items are tapped
            HapticManager.shared.tabSwitch()
        }
        .sheet(isPresented: $tabViewModel.showingSubscriptionPaywall) {
            SubscriptionPaywallView()
        }
        .onChange(of: tabViewModel.showingSubscriptionPaywall) { oldValue, newValue in
            if !newValue {
                // Sheet was dismissed
                HapticManager.shared.buttonPress(.subtle)
            }
        }
        .alert("Premium Feature", isPresented: $tabViewModel.showingPremiumAlert) {
            Button("Upgrade") {
                HapticManager.shared.buttonPress(.primary)
                tabViewModel.showingSubscriptionPaywall = true
            }
            Button("Cancel", role: .cancel) {
                HapticManager.shared.buttonPress(.subtle)
            }
        } message: {
            Text("This feature requires a Premium subscription. Upgrade now to unlock unlimited access to EmotiQ's Emotional coaching features.")
        }
        .alert("Open Settings", isPresented: $notificationManager.showingNotificationSettingsAlert) {
            Button("Open Settings") {
                HapticManager.shared.buttonPress(.primary)
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {
                HapticManager.shared.buttonPress(.subtle)
            }
        } message: {
            Text("You currently have notifications turned off for this application. You can open Settings to re-enable them.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToVoiceAnalysis)) { _ in
            // Navigate to voice analysis tab
            tabViewModel.selectedTab = .voice
            HapticManager.shared.buttonPress(.primary)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToMainApp)) { _ in
            // Navigate to dashboard tab
            tabViewModel.selectedTab = .dashboard
            HapticManager.shared.buttonPress(.primary)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToInsights)) { _ in
            // Navigate to insights tab
            tabViewModel.selectedTab = .insights
            HapticManager.shared.buttonPress(.primary)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("navigateToGoals"))) { _ in
            // Navigate to coaching tab (where goals are located)
            tabViewModel.selectedTab = .coaching
            HapticManager.shared.buttonPress(.primary)
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
        
        // Only trigger haptic if actually changing tabs
        if selectedTab != tab {
            HapticManager.shared.tabSwitch()
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
    let tabViewModel: TabViewModel
    @EnvironmentObject private var emotionService: CoreMLEmotionService
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var showingVoiceGuidedIntervention = false
    @State private var showingAllPrompts = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Header
                    DashboardHeaderView()
                    
                    // MARK: - Quick Actions
                    QuickActionsView(
                        onVoiceGuidedIntervention: {
                            showingVoiceGuidedIntervention = true
                        },
                        onVoiceCheck: {
                            tabViewModel.selectedTab = .voice
                        },
                        onPrompts: {
                            showingAllPrompts = true
                        },
                        onInsights: {
                            tabViewModel.selectedTab = .insights
                        }
                    )
                    
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
            .navigationDestination(isPresented: $showingVoiceGuidedIntervention) {
                VoiceGuidedInterventionView(intervention: nil)
            }
            .navigationDestination(isPresented: $showingAllPrompts) {
                AllEmotionalPromptsView(viewModel: MicroInterventionsViewModel())
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
                Button(action: {
                    HapticManager.shared.buttonPress(.subtle)
                }) {
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
        case 5..<11: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Evening"
        }
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    let onVoiceGuidedIntervention: () -> Void
    let onVoiceCheck: () -> Void
    let onPrompts: () -> Void
    let onInsights: () -> Void
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
                    action: onVoiceCheck
                )
                
                QuickActionButton(
                    title: "Breathing",
                    icon: "lungs.fill",
                    color: .blue,
                    action: onVoiceGuidedIntervention
                )
                
                QuickActionButton(
                    title: "Prompts",
                    icon: "book.fill",
                    color: ThemeColors.success,
                    action: onPrompts
                )
                
                QuickActionButton(
                    title: "Insights",
                    icon: "chart.bar.fill",
                    color: ThemeColors.warning,
                    action: onInsights
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
        Button(action: {
            HapticManager.shared.buttonPress(.standard)
            action()
        }) {
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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Voice check ins in the last 7 days")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    HapticManager.shared.buttonPress(.subtle)
                    // Navigate to InsightsView
                    NotificationCenter.default.post(name: .navigateToInsights, object: nil)
                }
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            

            // Line Chart with fallback
            if viewModel.weeklyTrendData.isEmpty {
                Text("Loading chart data...")
                    .foregroundColor(.secondary)
                    .frame(height: 140)
            } else {
                EmotionLineChart(data: viewModel.weeklyTrendData)
                    .frame(height: 140)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
    
    func formatDate(_ date: Date) -> String {
        
        let dateformatter = DateFormatter()
        
        dateformatter.dateFormat = "MMM d"
        
        return dateformatter.string(from: date)
    }
}

struct EmotionLineChart: View {
    let data: [EmotionTrendData]
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Y-axis labels
            VStack(alignment: .trailing, spacing: 0) {
                ForEach((0...5).reversed(), id: \.self) { i in
                    Text("\(i * 2)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(height: 16.67) // 100 height / 6 labels = 16.67 each
                }
            }
            .frame(width: 20)
            
            VStack(spacing: 8) {
                // Chart area
                GeometryReader { geometry in
                    ZStack {
                        // Grid lines
                        VStack(spacing: 0) {
                            ForEach(0..<6) { i in
                                Divider()
                                    .opacity(0.9)
                                if i < 5 {
                                    Spacer()
                                }
                            }
                        }
                        .offset(y: -1) // Align grid lines with Y-axis labels
                        
                        
                        // Chart lines
                        Path { path in
                            guard !data.isEmpty else { return }
                            
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let stepX = width / CGFloat(max(data.count - 1, 1))
                            
                            // Primary emotion line (blue)
                            let primaryPoints = data.enumerated().map { index, item in
                                CGPoint(
                                    x: CGFloat(index) * stepX,
                                    y: height - (CGFloat(item.primaryEmotionCount) / 10.0) * height
                                )
                            }
                            
                            path.move(to: primaryPoints[0])
                            for point in primaryPoints.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(Color.blue, lineWidth: 2)
                        
                        
                        // Data points
                        ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let stepX = width / CGFloat(max(data.count - 1, 1))
                            
                            // Primary emotion points (circles)
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                                .position(
                                    x: CGFloat(index) * stepX,
                                    y: height - (CGFloat(item.primaryEmotionCount) / 10.0) * height
                                )
                        
                        }
                    }
                }
                .frame(height: 100)
                
                // X-axis labels (dates)
                HStack {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                        Text(formatDate(item.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if index < data.count - 1 {
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
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
        // Refresh daily usage to check for daily reset
        SubscriptionService.shared.refreshDailyUsage()
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
        print("🔍 DEBUG: loadTodayData() started")
        
        // Monitor memory usage
        let memoryUsage = getMemoryUsage()
        print("🔍 DEBUG: Memory usage before loading: \(memoryUsage) MB")
        
        // Load real data from Core Data
        loadTodayCheckIns()
        loadCurrentStreak()
        loadAverageMood()
        loadWeeklyTrendData()
        
        let memoryUsageAfter = getMemoryUsage()
        print("🔍 DEBUG: Memory usage after loading: \(memoryUsageAfter) MB")
        print("🔍 DEBUG: Memory increase: \(memoryUsageAfter - memoryUsage) MB")
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0.0
        }
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
        print("🔍 DEBUG: loadWeeklyTrendData() started")
        
        guard let user = persistenceController.getCurrentUser() else {
            print("❌ DEBUG: No current user found")
            return
        }
        
        let calendar = Calendar.current
        let today = Date()
        print("🔍 DEBUG: Today's date: \(today)")
        
        // Find the first recording date
        let firstRecordingRequest: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        firstRecordingRequest.predicate = NSPredicate(format: "user == %@", user)
        firstRecordingRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: true)]
        firstRecordingRequest.fetchLimit = 1
        
        print("🔍 DEBUG: Fetching first recording date...")
        
        do {
            let firstRecordings = try persistenceController.container.viewContext.fetch(firstRecordingRequest)
            print("🔍 DEBUG: Found \(firstRecordings.count) first recordings")
            
            if let firstRecording = firstRecordings.first, let firstDate = firstRecording.timestamp {
                print("🔍 DEBUG: First recording date: \(firstDate)")
                
                // Start from the first recording date
                let startDate = calendar.startOfDay(for: firstDate)
                let daysSinceFirst = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
                let daysToShow = min(max(daysSinceFirst + 1, 7), 30) // Show at least 7 days, max 30
                
                print("🔍 DEBUG: Days since first: \(daysSinceFirst), Days to show: \(daysToShow)")
                
                // Limit to prevent memory issues
                let safeDaysToShow = min(daysToShow, 14) // Cap at 14 days for safety
                print("🔍 DEBUG: Safe days to show: \(safeDaysToShow)")
                
                weeklyTrendData = (0..<safeDaysToShow).map { dayOffset in
                    print("🔍 DEBUG: Processing day \(dayOffset + 1)/\(safeDaysToShow)")
                    
                    guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                        print("❌ DEBUG: Failed to calculate date for day \(dayOffset)")
                        return EmotionTrendData(date: Date(), checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                    }
                    
                    let dayStart = calendar.startOfDay(for: date)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
                    
                    print("🔍 DEBUG: Day \(dayOffset + 1): Querying from \(dayStart) to \(dayEnd)")
                    
                    let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "user == %@ AND timestamp >= %@ AND timestamp < %@", user, dayStart as NSDate, dayEnd as NSDate)
                    
                    // Add fetch limit to prevent memory issues
                    request.fetchLimit = 100
                    
                    do {
                        let results = try persistenceController.container.viewContext.fetch(request)
                        print("🔍 DEBUG: Day \(dayOffset + 1): Found \(results.count) recordings")
                        
                        // Debug individual recordings
                        for (index, entity) in results.enumerated() {
                            print("🔍 DEBUG: Recording \(index + 1): timestamp=\(entity.timestamp ?? Date()), emotion=\(entity.primaryEmotion ?? "nil"), confidence=\(entity.confidence)")
                        }
                        
                        // Calculate emotion counts for the chart
                        let emotions = results.compactMap { entity -> EmotionCategory? in
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
                        
                        let trendData = EmotionTrendData(
                            date: date,
                            checkInCount: results.count,
                            hasData: !results.isEmpty,
                            primaryEmotionCount: primaryCount,
                            secondaryEmotionCount: secondaryCount
                        )
                        
                        print("🔍 DEBUG: Created trend data: date=\(date), checkInCount=\(trendData.checkInCount), primary=\(trendData.primaryEmotionCount), secondary=\(trendData.secondaryEmotionCount)")
                        
                        return trendData
                    } catch {
                        print("❌ DEBUG: Failed to fetch trend data for day \(dayOffset): \(error)")
                        return EmotionTrendData(date: date, checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                    }
                }
                
                print("🔍 DEBUG: Successfully loaded \(weeklyTrendData.count) days of trend data")
                
                // Debug final data
                for (index, data) in weeklyTrendData.enumerated() {
                    print("🔍 DEBUG: Final data \(index + 1): \(formatDate(data.date)) - Count: \(data.checkInCount), Primary: \(data.primaryEmotionCount), Secondary: \(data.secondaryEmotionCount)")
                }
                
                func formatDate(_ date: Date) -> String {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    return formatter.string(from: date)
                }
                
            } else {
                print("🔍 DEBUG: No first recording found, showing empty chart")
                // No data yet, show empty chart for last 7 days
                weeklyTrendData = (0..<7).map { dayOffset in
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                        return EmotionTrendData(date: Date(), checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                    }
                    return EmotionTrendData(date: date, checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                }.reversed()
            }
        } catch {
            print("❌ DEBUG: Failed to fetch first recording date: \(error)")
            // Fallback to last 7 days
            weeklyTrendData = (0..<7).map { dayOffset in
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                    return EmotionTrendData(date: Date(), checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                }
                return EmotionTrendData(date: date, checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
            }.reversed()
        }
        
        print("🔍 DEBUG: loadWeeklyTrendData() completed with \(weeklyTrendData.count) data points")
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
            .environmentObject(HapticManager.shared)
    }
}
