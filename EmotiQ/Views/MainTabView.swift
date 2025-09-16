//
//  MainTabView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import SwiftUI
import CoreData
import Combine

struct MainTabView: View {
    @StateObject private var tabViewModel = TabViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var notificationManager = OneSignalNotificationManager.shared
    @StateObject private var notificationHistoryManager = NotificationHistoryManager.shared
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var emotionService: CoreMLEmotionService

    
    var body: some View {
        TabView(selection: $tabViewModel.selectedTab) {
            // MARK: - Dashboard Tab
            DashboardView(tabViewModel: tabViewModel)
                .environmentObject(notificationHistoryManager)
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
            
            // MARK: - Insights Tab (Conditional)
            if subscriptionService.hasActiveSubscription {
                FeatureGateView(feature: .advancedAnalytics) {
                    InsightsView()
                }
                .tabItem {
                    Image(systemName: tabViewModel.selectedTab == .insights ? "chart.line.uptrend.xyaxis.circle.fill" : "chart.line.uptrend.xyaxis.circle")
                    Text("Insights")
                }
                .tag(TabItem.insights)
            }
            
            // MARK: - Coaching Tab (Conditional)
            if subscriptionService.hasActiveSubscription {
                FeatureGateView(feature: .personalizedCoaching) {
                    CoachingView()
                }
                .tabItem {
                    Image(systemName: tabViewModel.selectedTab == .coaching ? "person.crop.circle.badge.checkmark.fill" : "person.crop.circle.badge.checkmark")
                    Text("Coaching")
                }
                .tag(TabItem.coaching)
            }
            
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
        .onReceive(subscriptionService.currentSubscription) { subscriptionStatus in
            // When subscription changes, ensure we're not on a premium tab if subscription is lost
            if !subscriptionService.hasActiveSubscription &&
               (tabViewModel.selectedTab == .insights || tabViewModel.selectedTab == .coaching) {
                tabViewModel.selectedTab = .dashboard
            }
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
            Text("This feature requires a Pro/Premium subscription. Upgrade now to unlock unlimited access to EmotiQ's Emotional coaching features.")
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
            tabViewModel.selectTab(.voice)
            HapticManager.shared.buttonPress(.primary)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToMainApp)) { _ in
            // Navigate to dashboard tab
            tabViewModel.selectTab(.dashboard)
            HapticManager.shared.buttonPress(.primary)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToInsights)) { _ in
            // Navigate to insights tab
            tabViewModel.selectTab(.insights)
            HapticManager.shared.buttonPress(.primary)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("navigateToGoals"))) { _ in
            // Navigate to coaching tab (where goals are located)
            tabViewModel.selectTab(.coaching)
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
        case .insights:
            return true // Requires advancedAnalytics feature
        case .coaching:
            return true // Requires personalizedCoaching feature
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
    @EnvironmentObject private var notificationHistoryManager: NotificationHistoryManager
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var showingVoiceGuidedIntervention = false
    @State private var showingAllPrompts = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Header
                    DashboardHeaderView()
                        .environmentObject(notificationHistoryManager)
                    
                    // MARK: - Quick Actions
                    QuickActionsView(
                        onVoiceGuidedIntervention: {
                            showingVoiceGuidedIntervention = true
                        },
                        onVoiceCheck: {
                            tabViewModel.selectTab(.voice)
                        },
                        onPrompts: {
                            showingAllPrompts = true
                        },
                        onInsights: {
                            tabViewModel.selectTab(.insights)
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
            .navigationBarTitleDisplayMode(.inline)
            .themedBackground(.gradient)
            .background(ThemeColors.primaryBackground)
            .onAppear {
                dashboardViewModel.refreshData()
            }
            .navigationDestination(isPresented: $showingVoiceGuidedIntervention) {
                FeatureGateView(feature: .personalizedCoaching) {
                    VoiceGuidedInterventionView(intervention: nil)
                }
            }
            .navigationDestination(isPresented: $showingAllPrompts) {
                FeatureGateView(feature: .personalizedCoaching) {
                    AllEmotionalPromptsView(viewModel: MicroInterventionsViewModel())
                }
            }
        }
    }
}

// MARK: - Dashboard Header
struct DashboardHeaderView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var notificationHistoryManager: NotificationHistoryManager
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
                
                // Notification bell with badge
                NavigationLink(destination: NotificationHistoryView().environmentObject(notificationHistoryManager)) {
                    ZStack {
                        Image(systemName: notificationHistoryManager.unreadCount > 0 ? "bell" : "bell")
                            .font(.title)
                            .foregroundColor(ThemeColors.accent)
                        
                        // Badge for unread notifications
                        if notificationHistoryManager.unreadCount > 0 {
                            Text("\(notificationHistoryManager.unreadCount > 99 ? "99+" : "\(notificationHistoryManager.unreadCount)")")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, notificationHistoryManager.unreadCount > 9 ? 4 : 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .offset(x: 12, y: -10)
                                .scaleEffect(0.8)
                        }
                    }
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticManager.shared.buttonPress(.subtle)
                })
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
                SummaryItem(title: "Avg Mood", value: viewModel.averageMood.emoji, icon: "person.fill", color: .gray)
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
                Text("Chart data will appear here.")
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
        // Compute dynamic Y-axis ticks based on max check-ins
        let maxCheckIns = data.map { $0.checkInCount }.max() ?? 0
        let ticks = yAxisTicks(maxValue: maxCheckIns, targetTicks: 6)
        let tickCount = max(ticks.count, 2)
        let maxScale = max(ticks.last ?? 1, 1)
        let rowHeight: CGFloat = 100.0 / CGFloat(tickCount)
        
        return HStack(alignment: .top, spacing: 8) {
            // Y-axis labels
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(ticks.reversed(), id: \.self) { value in
                    Text("\(value)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(height: rowHeight)
                }
            }
            .frame(width: 20)
            
            VStack(spacing: 8) {
                // Chart area
                GeometryReader { geometry in
                    ZStack {
                        // Grid lines
                        VStack(spacing: 0) {
                            ForEach(0..<tickCount, id: \.self) { i in
                                Divider()
                                    .opacity(0.9)
                                if i < tickCount - 1 {
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
                            
                            // Check-ins line (blue)
                            let primaryPoints = data.enumerated().map { index, item in
                                CGPoint(
                                    x: CGFloat(index) * stepX,
                                    y: height - (CGFloat(item.checkInCount) / CGFloat(maxScale)) * height
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
                                    y: height - (CGFloat(item.checkInCount) / CGFloat(maxScale)) * height
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
    
    // MARK: - Y-axis tick helpers
    private func yAxisTicks(maxValue: Int, targetTicks: Int) -> [Int] {
        // Handle zero safely
        guard maxValue > 0 else { return [0, 1] }
        let step = niceStep(maxValue: maxValue, targetTicks: targetTicks)
        let maxScale = ((maxValue + step - 1) / step) * step
        var ticks: [Int] = []
        var value = 0
        while value <= maxScale {
            ticks.append(value)
            value += step
        }
        return ticks
    }
    
    private func niceStep(maxValue: Int, targetTicks: Int) -> Int {
        if maxValue <= 0 { return 1 }
        let rough = Double(maxValue) / Double(max(targetTicks, 1))
        if rough == 0 { return 1 }
        let magnitude = pow(10.0, floor(log10(rough)))
        let residual = rough / magnitude
        let niceResidual: Double
        if residual <= 1.0 {
            niceResidual = 1.0
        } else if residual <= 2.0 {
            niceResidual = 2.0
        } else if residual <= 5.0 {
            niceResidual = 5.0
        } else {
            niceResidual = 10.0
        }
        return max(1, Int(niceResidual * magnitude))
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

        
        // Monitor memory usage
        let memoryUsage = getMemoryUsage()
        
        // Load real data from Core Data
        loadTodayCheckIns()
        loadCurrentStreak()
        loadAverageMood()
        loadWeeklyTrendData()
        
        let memoryUsageAfter = getMemoryUsage()

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
 
            averageMood = .neutral
        }
    }
    
    private func loadWeeklyTrendData() {

        
        guard let user = persistenceController.getCurrentUser() else {
   
            return
        }
        
        let calendar = Calendar.current
        let today = Date()
  
        
        // Find the first recording date
        let firstRecordingRequest: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        firstRecordingRequest.predicate = NSPredicate(format: "user == %@", user)
        firstRecordingRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: true)]
        firstRecordingRequest.fetchLimit = 1
        
        
        do {
            let firstRecordings = try persistenceController.container.viewContext.fetch(firstRecordingRequest)
     
            
            if let firstRecording = firstRecordings.first, let firstDate = firstRecording.timestamp {
             
                
                // Start from the first recording date
                let startDate = calendar.startOfDay(for: firstDate)
                let daysSinceFirst = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
                let daysToShow = min(max(daysSinceFirst + 1, 7), 30) // Show at least 7 days, max 30
                
                
                // Limit to prevent memory issues
                let safeDaysToShow = min(daysToShow, 14) // Cap at 14 days for safety
        
                
                weeklyTrendData = (0..<safeDaysToShow).map { dayOffset in
        
                    
                    guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
 
                        return EmotionTrendData(date: Date(), checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                    }
                    
                    let dayStart = calendar.startOfDay(for: date)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
                    
                    
                    let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "user == %@ AND timestamp >= %@ AND timestamp < %@", user, dayStart as NSDate, dayEnd as NSDate)
                    
                    // Add fetch limit to prevent memory issues
                    request.fetchLimit = 100
                    
                    do {
                        let results = try persistenceController.container.viewContext.fetch(request)

                    
                        
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
                        
                        
                        let trendData = EmotionTrendData(
                            date: date,
                            checkInCount: results.count,
                            hasData: !results.isEmpty,
                            primaryEmotionCount: primaryCount,
                            secondaryEmotionCount: secondaryCount
                        )
                        
                        
                        return trendData
                    } catch {
                  
                        return EmotionTrendData(date: date, checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                    }
                }
                
                
                func formatDate(_ date: Date) -> String {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    return formatter.string(from: date)
                }
                
            } else {
          
                // No data yet, show empty chart for last 7 days
                weeklyTrendData = (0..<7).map { dayOffset in
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                        return EmotionTrendData(date: Date(), checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                    }
                    return EmotionTrendData(date: date, checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                }.reversed()
            }
        } catch {


            weeklyTrendData = (0..<7).map { dayOffset in
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                    return EmotionTrendData(date: Date(), checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
                }
                return EmotionTrendData(date: date, checkInCount: 0, hasData: false, primaryEmotionCount: 0, secondaryEmotionCount: 0)
            }.reversed()
        }
        
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
