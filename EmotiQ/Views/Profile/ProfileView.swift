//
//  ProfileView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 11-08-2025.
//

import SwiftUI
import LocalAuthentication
import StoreKit
import CoreData
import Combine

// MARK: - Profile View
/// Production-ready profile and settings view with Face ID authentication
/// Provides comprehensive user management and app configuration
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingSubscriptionPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background using ThemeColors
                ThemeColors.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Compact Profile Header
                        CompactProfileHeader(viewModel: viewModel)
                        
                        // MARK: - Horizontal Journey Metrics
                        HorizontalMetricsSection(viewModel: viewModel)
                        
                        // MARK: - Settings Sections
                        SettingsListView(viewModel: viewModel, subscriptionService: subscriptionService) {
                            showingSubscriptionPaywall = true
                        }
                        
                        Spacer(minLength: 100) // Tab bar spacing
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingSubscriptionPaywall) {
                SubscriptionPaywallView()
            }
            .sheet(isPresented: $viewModel.showingSubscriptionManagement) {
                SubscriptionManagementSheet()
            }
            .navigationDestination(isPresented: $viewModel.showingCompletedGoals) {
                CompletedGoalView()
            }
            .navigationDestination(isPresented: $viewModel.showingAccountPrivacy) {
                AccountPrivacyView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $viewModel.showingAppSettings) {
                AppSettingsView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $viewModel.showingSupportInfo) {
                SupportInfoView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $viewModel.showingInsights) {
                FeatureGateView(feature: .advancedAnalytics) {
                    InsightsView()
                }
            }
            .navigationDestination(isPresented: $viewModel.showingCheckIns) {
                CheckInsListView()
            }
            .onAppear {
                viewModel.setThemeManager(themeManager)
                viewModel.loadProfileData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showCheckInsFromProfile)) { _ in
                viewModel.showingCheckIns = true
            }
            .onChange(of: viewModel.profileImage) { newImage in
                viewModel.saveProfileImage(newImage)
            }
        }
    }
}

// MARK: - Compact Profile Header
struct CompactProfileHeader: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            viewModel.showingImagePicker = true
        }) {
            HStack(spacing: 16) {
                // Compact avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .cyan.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    if let profileImage = viewModel.profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.purple)
                    }
                    
                    // Edit button overlay
                    Image(systemName: "camera.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.purple)
                        .clipShape(Circle())
                        .offset(x: 20, y: 20)
                }
                
                // Profile info
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Joined \(viewModel.memberSince)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                //                Image(systemName: "chevron.right")
                //                    .foregroundColor(.secondary)
                //                    .font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(image: $viewModel.profileImage)
        }
    }
}

// MARK: - Horizontal Metrics Section
struct HorizontalMetricsSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Journey")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                
                Button(action: {
                    HapticManager.shared.selection()
                    viewModel.showingCheckIns = true
                }) {
                    CompactStatCard(
                        title: "Check-ins",
                        value: "\(viewModel.totalCheckIns)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    
                    HapticManager.shared.selection()
                    viewModel.showingInsights = true
                }){
                    
                    CompactStatCard(
                        title: "Insights",
                        value: "\(viewModel.totalInsights)",
                        icon: "chart.bar.fill",
                        color: .yellow
                    )
                    
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    HapticManager.shared.selection()
                    viewModel.showingCompletedGoals = true
                }) {
                    CompactStatCard(
                        title: "Goals",
                        value: "\(viewModel.completedGoals)",
                        icon: "target",
                        color: .blue
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct CompactStatCard: View {
    let title: String
    let value: String
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
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Settings List View
struct SettingsListView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let subscriptionService: SubscriptionService
    let upgradeAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Subscription Row
            FullWidthSettingsRow(
                icon: subscriptionService.hasActiveSubscription ? "crown.fill" : "crown",
                title: subscriptionService.hasActiveSubscription ? "Active Subscription" : "Free Plan",
                subtitle: subscriptionService.hasActiveSubscription ?
                    (subscriptionService.currentSubscriptionTier?.displayName ?? "Premium") :
                    "Upgrade to unlock premium features",
                action: upgradeAction
            )
            
            // Subscription Management (if active)
            if subscriptionService.hasActiveSubscription {
                FullWidthSettingsRow(
                    icon: "gear",
                    title: "Manage Subscription",
                    subtitle: "Cancel or modify your subscription",
                    action: { viewModel.showingSubscriptionManagement = true }
                )
            }
            
            // Edit Profile
            FullWidthSettingsRow(
                icon: "person.circle",
                title: "Edit Profile",
                action: { viewModel.showingEditProfile = true }
            )
            
            // Privacy Settings
            FullWidthSettingsRow(
                icon: "lock.shield",
                title: "Privacy Settings",
                action: { viewModel.showingAccountPrivacy = true }
            )
            
            // Notifications
            FullWidthSettingsRow(
                icon: "bell",
                title: "Notifications",
                action: { viewModel.showingAppSettings = true }
            )
            
            // Dark Mode
            FullWidthSettingsRow(
                icon: "moon",
                title: "Dark Mode",
                subtitle: viewModel.darkModeEnabled ? "On" : "Off",
                action: { viewModel.toggleDarkMode() }
            )
            
            // Help & Support
            FullWidthSettingsRow(
                icon: "questionmark.circle",
                title: "Help & Support",
                action: { viewModel.showingSupportInfo = true }
            )
            
            // Privacy Policy
            FullWidthSettingsRow(
                icon: "doc.text",
                title: "Privacy Policy",
                action: { viewModel.openPrivacyPolicy() }
            )
            
            // Terms of Use
            FullWidthSettingsRow(
                icon: "doc.plaintext",
                title: "Terms of Use",
                action: { viewModel.openTermsOfUse() }
            )
            
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .sheet(isPresented: $viewModel.showingEditProfile) {
            EditProfileView(viewModel: viewModel)
        }
        .alert("Face ID", isPresented: $viewModel.showingFaceIDAlert) {
            Button("Settings") {
                viewModel.openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(viewModel.faceIDAlertMessage)
        }
    }
}



// MARK: - Full Width Settings Row
struct FullWidthSettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
    }
}

// MARK: - Profile View Model
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var displayName = "User"
    @Published var memberSince = ""
    @Published var currentStreak = 0
    @Published var totalCheckIns = 0
    @Published var totalInsights = 0
    @Published var completedGoals = 0
    @Published var profileImage: UIImage?
    @Published var faceIDEnabled = false
    @Published var showingImagePicker = false
    @Published var showingEditProfile = false
    @Published var showingFaceIDAlert = false
    @Published var faceIDAlertMessage = ""
    
    // Navigation states for settings sections
    @Published var showingAccountPrivacy = false
    @Published var showingAppSettings = false
    @Published var showingSupportInfo = false
    @Published var showingCompletedGoals = false
    @Published var showingSubscriptionManagement = false
    @Published var showingInsights = false
    @Published var showingCheckIns = false
    
    private let persistenceController = PersistenceController.shared
    private var themeManager: ThemeManager?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
    }
    
    // Published property that syncs with ThemeManager
    @Published var darkModeEnabled: Bool = false
    
    func setThemeManager(_ themeManager: ThemeManager) {
        self.themeManager = themeManager
        self.darkModeEnabled = themeManager.isDarkMode
        
        // Observe changes to isDarkMode
        themeManager.$isDarkMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.darkModeEnabled = v
            }
            .store(in: &cancellables)
    }
    
    func loadProfileData() {
        // Load real user data from Core Data
        loadUserPreferences()
        loadUserStats()
        checkBiometricAvailability()
    }
    
    private func setupNotifications() {
        // Listen for goal completion
        NotificationCenter.default.publisher(for: .goalCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadProfileData()
            }
            .store(in: &cancellables)
    }
    
    func toggleFaceID() {
        Task {
            do {
                let securityManager = SecurityManager.shared
                
                if faceIDEnabled {
                    // Disable Face ID
                    let saved = securityManager.setFaceIDEnabled(false)
                    if saved {
                        await MainActor.run { self.faceIDEnabled = false }
                    }
                } else {
                    // Enable Face ID - first authenticate
                    let success = try await securityManager.authenticateWithBiometrics(reason: "Enable Face ID for EmotiQ")
                    if success {
                        let saved = securityManager.setFaceIDEnabled(true)
                        if saved {
                            await MainActor.run { self.faceIDEnabled = true }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.faceIDAlertMessage = error.localizedDescription
                    self.showingFaceIDAlert = true
                }
            }
        }
    }
    
    func toggleDarkMode() {
        guard let themeManager = themeManager else { return }
        
        // Toggle between light and dark themes using ThemeManager
        let currentTheme = themeManager.currentTheme
        let newTheme: AppTheme = currentTheme == .dark ? .light : .dark
        themeManager.setTheme(newTheme)
    }
    
    func openSupport() {
        if let url = URL(string: "mailto:emotiqapp@gmail.com") {
            UIApplication.shared.open(url)
        }
    }
    
    func openPrivacyPolicy() {
        
        if let url = URL(string: "https://ytemiloluwa.github.io/privacy-policy.html") {
            UIApplication.shared.open(url)
        }

    }
    
    func openTermsOfUse() {
        if let url = URL(string: "https://ytemiloluwa.github.io/Term-of-use.html") {
            UIApplication.shared.open(url)
        }
    }
    
    func requestAppReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func loadUserPreferences() {
        let securityManager = SecurityManager.shared
        faceIDEnabled = securityManager.isFaceIDEnabled()
        
        if let user = persistenceController.getCurrentUser() {
            if let name = user.name, !name.isEmpty {
                displayName = name
            } else {
                displayName = UserDefaults.standard.string(forKey: "userDisplayName") ?? "User"
            }
            loadProfileImage(for: user)
        } else {
            displayName = UserDefaults.standard.string(forKey: "userDisplayName") ?? "User"
        }
    }
    
    private func loadUserStats() {
        guard let user = persistenceController.getCurrentUser() else {
            // No user data available, keep default values
            return
        }
        
        // Ensure cached stats are up-to-date (idempotent)
        persistenceController.recalculateUserStats(for: user)
        totalCheckIns = Int(user.totalCheckIns)
        currentStreak = Int(user.currentStreak)
        
        // Load total check-ins
        //        loadTotalCheckIns(for: user)
        //
        //        // Load current streak
        //        loadCurrentStreak(for: user)
        
        // Load completed goals
        loadCompletedGoals(for: user)
        
        // Load member since date
        loadMemberSinceDate(for: user)
        
        // Calculate total insights (based on emotional data analysis)
        calculateTotalInsights(for: user)
    }
    

    
    private func loadCompletedGoals(for user: User) {
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND isCompleted == YES", user)
        
        do {
            let results = try persistenceController.container.viewContext.fetch(request)
            completedGoals = results.count
        } catch {
            
            completedGoals = 0
        }
    }
    
    private func loadMemberSinceDate(for user: User) {
        // Get the earliest emotional data entry to determine member since date
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: true)]
        request.fetchLimit = 1
        
        do {
            let results = try persistenceController.container.viewContext.fetch(request)
            if let firstEntry = results.first,
               let timestamp = firstEntry.timestamp {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM yyyy"
                memberSince = formatter.string(from: timestamp)
            } else {
                // No data available, use current date
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM yyyy"
                memberSince = formatter.string(from: Date())
            }
        } catch {
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            memberSince = formatter.string(from: Date())
        }
    }
    
    private func loadProfileImage(for user: User) {
        if let data = user.profileImageData, let image = UIImage(data: data) {
            profileImage = image
        } else {
            profileImage = nil
        }
    }
    
    func saveProfileImage(_ image: UIImage?) {
        guard let user = persistenceController.getCurrentUser() else { return }
        if let image = image {
            let jpeg = image.jpegData(compressionQuality: 0.9)
            let data = jpeg ?? image.pngData()
            user.profileImageData = data
        } else {
            user.profileImageData = nil
        }
        persistenceController.save()
    }
    
    func updateDisplayName(_ name: String) {
        displayName = name
        if let user = persistenceController.getCurrentUser() {
            user.name = name
            persistenceController.save()
        } else {
            UserDefaults.standard.set(name, forKey: "userDisplayName")
        }
    }
    
    private func calculateTotalInsights(for user: User) {
        // Calculate insights based on emotional data patterns
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        
        do {
            let emotionalData = try persistenceController.container.viewContext.fetch(request)
            
            // Count unique insights based on different emotion patterns
            var uniqueInsights = Set<String>()
            
            // Insight 1: Most common emotion
            let emotions = emotionalData.compactMap { $0.primaryEmotion }
            if let mostCommon = emotions.mostFrequent() {
                uniqueInsights.insert("Most common emotion: \(mostCommon)")
            }
            
            // Insight 2: Emotional patterns
            if emotionalData.count >= 7 {
                uniqueInsights.insert("Weekly emotional pattern detected")
            }
            
            // Insight 3: Streak achievements
            if currentStreak >= 7 {
                uniqueInsights.insert("7-day streak achieved")
            }
            if currentStreak >= 30 {
                uniqueInsights.insert("30-day streak achieved")
            }
            
            // Insight 4: Goal completion
            if completedGoals > 0 {
                uniqueInsights.insert("Goal completion milestone")
            }
            
            totalInsights = uniqueInsights.count
        } catch {
            
            totalInsights = 0
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
    
    private func checkBiometricAvailability() {
        Task {
            let isAvailable = await SecurityManager.shared.isBiometricAvailable()
            if !isAvailable && faceIDEnabled {
                // Disable Face ID if not available
                await MainActor.run {
                    self.faceIDEnabled = false
                    UserDefaults.standard.set(false, forKey: "faceIDEnabled")
                }
            }
        }
    }
}



// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var editedName: String = ""
    @FocusState private var isNameFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Display Name", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isNameFocused)
                        .padding(.vertical, 4)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.updateDisplayName(editedName)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            editedName = viewModel.displayName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true // Automatically focuses the text field
            }
        }
    }
}


// MARK: - Array Extension
extension Array where Element: Hashable {
    func mostFrequent() -> Element? {
        let counts = self.reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Subscription Management Sheet
struct SubscriptionManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var isRestoring = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.purple)
                    
                    Text("Manage Subscription")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Manage your EmotiQ subscription")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Current Plan Info
                VStack(spacing: 16) {
                    Text("Current Plan")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(subscriptionService.currentSubscriptionTier?.displayName ?? "Premium")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    
                    Text("Auto-renewing subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                )
                
                // Management Options
                VStack(spacing: 12) {
                    Button(action: {
                        // Open App Store subscription management
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .font(.system(size: 16, weight: .medium))
                            Text("Manage in App Store")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.primary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.regularMaterial)
                        )
                    }
                    
                    Button(action: {
                        restorePurchases()
                    }) {
                        HStack {
                            if isRestoring {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            Text(isRestoring ? "Restoring..." : "Restore Purchases")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.regularMaterial)
                        )
                    }
                    .disabled(isRestoring)
                }
                
                Spacer()
                
                // Important Notice
                VStack(spacing: 8) {
                    Text("Important")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("To cancel or modify your subscription, use the App Store subscription management. Changes will take effect at the end of your current billing period.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.orange.opacity(0.1))
                )
            }
            .padding(.horizontal, 20)
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Your purchases have been restored successfully!")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func restorePurchases() {
        isRestoring = true
        
        RevenueCatService.shared.restorePurchases()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isRestoring = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                },
                receiveValue: { customerInfo in
                    isRestoring = false
                    if !customerInfo.activeSubscriptions.isEmpty {
                        showSuccessAlert = true
                        
                    } else {
                        errorMessage = "No previous purchases found to restore."
                        showErrorAlert = true
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(SubscriptionService())
            .environmentObject(ThemeManager())
    }
}

