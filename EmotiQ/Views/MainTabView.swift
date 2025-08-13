//
//  MainTabView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import SwiftUI

// MARK: - Main Tab View
/// Production-ready tab navigation structure for EmotiQ
/// Provides intuitive access to all core features with beautiful design
struct MainTabView: View {
    @StateObject private var tabViewModel = TabViewModel()
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
        .accentColor(.purple)
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
        appearance.backgroundColor = UIColor.systemBackground
        
        // Selected tab color
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemPurple
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemPurple
        ]
        
        // Normal tab color
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
            return true
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
                    TodaySummaryCard()
                    
                    // MARK: - Emotion Trends
                    EmotionTrendsCard()
                    
                    Spacer(minLength: 100) // Tab bar spacing
                }
                .padding(.horizontal)
            }
            .navigationTitle("EmotiQ")
            .navigationBarTitleDisplayMode(.large)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.cyan.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

// MARK: - Dashboard Header
struct DashboardHeaderView: View {
    @State private var currentTime = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(greetingText)
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("How are you feeling today?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Notification bell
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.title2)
                        .foregroundColor(.purple)
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
        default: return "Good Night"
        }
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 15) {
                QuickActionButton(
                    title: "Voice Check",
                    icon: "waveform.circle.fill",
                    color: .purple,
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
                    color: .green,
                    action: {}
                )
                
                QuickActionButton(
                    title: "Insights",
                    icon: "chart.bar.fill",
                    color: .orange,
                    action: {}
                )
            }
        }
    }
}

struct QuickActionButton: View {
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
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Analysis Card
struct RecentAnalysisCard: View {
    let result: EmotionAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 15) {
                // Emotion display
                VStack {
                    Text(result.primaryEmotion.emoji)
                        .font(.system(size: 40))
                    
                    Text(result.primaryEmotion.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // Confidence meter
                VStack(alignment: .trailing) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(result.confidencePercentage)%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(result.isHighConfidence ? .green : .orange)
                }
            }
            
            // Coaching tip preview
            Text(result.primaryEmotion.coachingTip)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Today's Summary Card
struct TodaySummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                SummaryItem(title: "Check-ins", value: "3", icon: "checkmark.circle.fill", color: .green)
                SummaryItem(title: "Avg Mood", value: "😊", icon: "heart.fill", color: .pink)
                SummaryItem(title: "Streak", value: "7", icon: "flame.fill", color: .orange)
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
            
            // Mini trend chart placeholder
            HStack(spacing: 8) {
                ForEach(0..<7) { day in
                    VStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple.opacity(0.7))
                            .frame(width: 8, height: CGFloat.random(in: 20...60))
                        
                        Text("\(day + 1)")
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
    
    init() {
        loadTodayData()
    }
    
    private func loadTodayData() {
        // Load today's data from Core Data
        // This would be implemented with actual data fetching
        todayCheckIns = 3
        currentStreak = 7
        averageMood = .joy
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


