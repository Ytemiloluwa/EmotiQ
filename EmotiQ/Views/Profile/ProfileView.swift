//
//  ProfileView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
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
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.cyan.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: - Profile Header
                        ProfileHeaderSection(viewModel: viewModel)
                        
                        // MARK: - Subscription Status
                        SubscriptionStatusSection(
                            subscriptionService: subscriptionService,
                            upgradeAction: { showingSubscriptionPaywall = true }
                        )
                        
                        // MARK: - Quick Stats
                        QuickStatsSection(viewModel: viewModel)
                        
                        // MARK: - Settings Sections
                        SettingsSectionsView(viewModel: viewModel)
                        
                        Spacer(minLength: 100) // Tab bar spacing
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingSubscriptionPaywall) {
                SubscriptionPaywallView()
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
            .onAppear {
                viewModel.setThemeManager(themeManager)
                viewModel.loadProfileData()
            }
        }
    }
}

// MARK: - Profile Header Section
struct ProfileHeaderSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .cyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                if let profileImage = viewModel.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.purple)
                }
                
                // Edit button
                Button(action: {
                    viewModel.showingImagePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.purple)
                        .clipShape(Circle())
                }
                .offset(x: 35, y: 35)
            }
            
            VStack(spacing: 4) {
                Text(viewModel.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Member since \(viewModel.memberSince)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Streak badge
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(viewModel.currentStreak) day streak")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.regularMaterial)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(image: $viewModel.profileImage)
        }
    }
}

// MARK: - Subscription Status Section
struct SubscriptionStatusSection: View {
    let subscriptionService: SubscriptionService
    let upgradeAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Subscription")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if subscriptionService.hasActiveSubscription {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.green.opacity(0.2))
                        )
                }
            }
            
            if subscriptionService.hasActiveSubscription {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.purple)
                        
                        Text(subscriptionService.currentSubscriptionTier?.displayName ?? "Premium")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    
                    if let expiryDate = subscriptionService.subscriptionExpiryDate {
                        Text("Renews on \(expiryDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Manage Subscription") {
                        // Open subscription management
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Free Plan")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Upgrade to unlock unlimited voice analyses and Emotional coaching")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: upgradeAction) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Upgrade to Premium")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
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
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Quick Stats Section
struct QuickStatsSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Journey")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 15) {
                StatCard(
                    title: "Check-ins",
                    value: "\(viewModel.totalCheckIns)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Insights",
                    value: "\(viewModel.totalInsights)",
                    icon: "lightbulb.fill",
                    color: .yellow
                )
                
                Button(action: {
                    viewModel.showingCompletedGoals = true
                }) {
                    StatCard(
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

struct StatCard: View {
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
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Settings Sections View
struct SettingsSectionsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Account & Privacy
            SettingsSection(title: "Account & Privacy") {
                SettingsRow(
                    icon: "person.circle",
                    title: "Edit Profile",
                    action: { viewModel.showingEditProfile = true }
                )
                
                SettingsRow(
                    icon: "faceid",
                    title: "Face ID",
                    subtitle: viewModel.faceIDEnabled ? "Enabled" : "Disabled",
                    action: { viewModel.toggleFaceID() }
                )
                
                SettingsRow(
                    icon: "lock.shield",
                    title: "Privacy Settings",
                    action: { viewModel.showingAccountPrivacy = true }
                )
            }
            
            // App Settings
            SettingsSection(title: "App Settings") {
                SettingsRow(
                    icon: "bell",
                    title: "Notifications",
                    action: { viewModel.showingAppSettings = true }
                )
                
                SettingsRow(
                    icon: "moon",
                    title: "Dark Mode",
                    darkModeEnabled: viewModel.darkModeEnabled,
                    action: { viewModel.toggleDarkMode() }
                )
                
                SettingsRow(
                    icon: "gear",
                    title: "App Settings",
                    action: { viewModel.showingAppSettings = true }
                )
            }
            
            // Support & Info
            SettingsSection(title: "Support & Info") {
                SettingsRow(
                    icon: "questionmark.circle",
                    title: "Help & Support",
                    action: { viewModel.showingSupportInfo = true }
                )
                
                SettingsRow(
                    icon: "doc.text",
                    title: "Privacy Policy",
                    action: { viewModel.openPrivacyPolicy() }
                )
                
                SettingsRow(
                    icon: "star",
                    title: "Rate EmotiQ",
                    action: { viewModel.requestAppReview() }
                )
            }
        }
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

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 1) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
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
    
    // Reactive subtitle for dark mode
    init(icon: String, title: String, darkModeEnabled: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = darkModeEnabled ? "On" : "Off"
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
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
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Profile View Model
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var displayName = "User"
    @Published var memberSince = "Jan 2025"
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
    
    private let biometricService = BiometricAuthenticationService()
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
            .assign(to: \.darkModeEnabled, on: self)
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
                    if securityManager.setFaceIDEnabled(false) {
                        faceIDEnabled = false
                    }
                } else {
                    // Enable Face ID - first authenticate
                    let success = try await securityManager.authenticateWithBiometrics(reason: "Enable Face ID for EmotiQ")
                    if success && securityManager.setFaceIDEnabled(true) {
                        faceIDEnabled = true
                    }
                }
            } catch {
                faceIDAlertMessage = error.localizedDescription
                showingFaceIDAlert = true
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
        if let url = URL(string: "mailto:support@emotiq.app") {
            UIApplication.shared.open(url)
        }
    }
    
    func openPrivacyPolicy() {
        if let url = URL(string: "https://emotiq.app/privacy") {
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
        
        // Load display name from Core Data or UserDefaults
        displayName = UserDefaults.standard.string(forKey: "userDisplayName") ?? "User"
    }
    
    private func loadUserStats() {
        guard let user = persistenceController.getCurrentUser() else {
            // No user data available, keep default values
            return
        }
        
        // Load total check-ins
        loadTotalCheckIns(for: user)
        
        // Load current streak
        loadCurrentStreak(for: user)
        
        // Load completed goals
        loadCompletedGoals(for: user)
        
        // Load member since date
        loadMemberSinceDate(for: user)
        
        // Calculate total insights (based on emotional data analysis)
        calculateTotalInsights(for: user)
    }
    
    private func loadTotalCheckIns(for user: User) {
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        
        do {
            let results = try persistenceController.container.viewContext.fetch(request)
            totalCheckIns = results.count
        } catch {
            print("❌ Failed to fetch total check-ins: \(error)")
            totalCheckIns = 0
        }
    }
    
    private func loadCurrentStreak(for user: User) {
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
    
    private func loadCompletedGoals(for user: User) {
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND isCompleted == YES", user)
        
        do {
            let results = try persistenceController.container.viewContext.fetch(request)
            completedGoals = results.count
        } catch {
            print("❌ Failed to fetch completed goals: \(error)")
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
            print("❌ Failed to fetch member since date: \(error)")
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            memberSince = formatter.string(from: Date())
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
            print("❌ Failed to calculate total insights: \(error)")
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
            let isAvailable = await biometricService.isBiometricAvailable()
            if !isAvailable && faceIDEnabled {
                // Disable Face ID if not available
                faceIDEnabled = false
                UserDefaults.standard.set(false, forKey: "faceIDEnabled")
            }
        }
    }
}

// MARK: - Biometric Authentication Service
class BiometricAuthenticationService {
    private let context = LAContext()
    
    func isBiometricAvailable() async -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func authenticateUser(reason: String) async throws -> Bool {
        let context = LAContext()
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            throw BiometricError.notAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel:
                throw BiometricError.userCancelled
            case .userFallback:
                // User chose to enter passcode, but we need to verify it was successful
                // Let's try to authenticate again with passcode fallback
                return try await authenticateWithPasscode(reason: reason)
            case .authenticationFailed:
                throw BiometricError.authenticationFailed("Passcode verification failed")
            default:
                throw BiometricError.authenticationFailed(error.localizedDescription)
            }
        } catch {
            throw BiometricError.authenticationFailed(error.localizedDescription)
        }
    }
    
    private func authenticateWithPasscode(reason: String) async throws -> Bool {
        let context = LAContext()
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel:
                throw BiometricError.userCancelled
            case .authenticationFailed:
                throw BiometricError.authenticationFailed("Incorrect passcode")
            default:
                throw BiometricError.authenticationFailed(error.localizedDescription)
            }
        }
    }
    
    func getBiometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
}

// MARK: - Biometric Error
enum BiometricError: LocalizedError {
    case notAvailable
    case authenticationFailed(String)
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .userCancelled:
            return "Authentication was cancelled."
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

// MARK: - Edit Profile View
struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var editedName: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    HStack {
                        Text("Name")
                        TextField("Display Name", text: $editedName)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.displayName = editedName
                        UserDefaults.standard.set(editedName, forKey: "userDisplayName")
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            editedName = viewModel.displayName
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



// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(SubscriptionService())
            .environmentObject(ThemeManager())
    }
}
