//
//  ProfileView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//

import Foundation
import SwiftUI
import LocalAuthentication
import StoreKit

// MARK: - Profile View

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var showingSubscriptionPaywall = false
    @State private var showingSettingsSheet = false
    
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
                        SettingsSectionsView(
                            viewModel: viewModel,
                            settingsAction: { showingSettingsSheet = true }
                        )
                        
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
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .onAppear {
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
                
                StatCard(
                    title: "Goals",
                    value: "\(viewModel.completedGoals)",
                    icon: "target",
                    color: .blue
                )
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
    let settingsAction: () -> Void
    
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
                    action: settingsAction
                )
            }
            
            // App Settings
            SettingsSection(title: "App Settings") {
                SettingsRow(
                    icon: "bell",
                    title: "Notifications",
                    action: settingsAction
                )
                
                SettingsRow(
                    icon: "moon",
                    title: "Dark Mode",
                    subtitle: viewModel.darkModeEnabled ? "On" : "Off",
                    action: { viewModel.toggleDarkMode() }
                )
                
                SettingsRow(
                    icon: "speaker.wave.2",
                    title: "Audio Settings",
                    action: settingsAction
                )
            }
            
            // Support & Info
            SettingsSection(title: "Support & Info") {
                SettingsRow(
                    icon: "questionmark.circle",
                    title: "Help & Support",
                    action: { viewModel.openSupport() }
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
    @Published var currentStreak = 7
    @Published var totalCheckIns = 45
    @Published var totalInsights = 23
    @Published var completedGoals = 8
    @Published var profileImage: UIImage?
    @Published var faceIDEnabled = false
    @Published var darkModeEnabled = false
    @Published var showingImagePicker = false
    @Published var showingEditProfile = false
    @Published var showingFaceIDAlert = false
    @Published var faceIDAlertMessage = ""
    
    private let biometricService = BiometricAuthenticationService()
    
    func loadProfileData() {
        // Load user data from Core Data
        loadUserPreferences()
        checkBiometricAvailability()
    }
    
    func toggleFaceID() {
        Task {
            do {
                if faceIDEnabled {
                    // Disable Face ID
                    faceIDEnabled = false
                    UserDefaults.standard.set(false, forKey: "faceIDEnabled")
                } else {
                    // Enable Face ID - first authenticate
                    let success = try await biometricService.authenticateUser(reason: "Enable Face ID for EmotiQ")
                    if success {
                        faceIDEnabled = true
                        UserDefaults.standard.set(true, forKey: "faceIDEnabled")
                    }
                }
            } catch {
                faceIDAlertMessage = error.localizedDescription
                showingFaceIDAlert = true
            }
        }
    }
    
    func toggleDarkMode() {
        darkModeEnabled.toggle()
        UserDefaults.standard.set(darkModeEnabled, forKey: "darkModeEnabled")
        
        // Apply dark mode change
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.first?.overrideUserInterfaceStyle = darkModeEnabled ? .dark : .light
        }
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
        faceIDEnabled = UserDefaults.standard.bool(forKey: "faceIDEnabled")
        darkModeEnabled = UserDefaults.standard.bool(forKey: "darkModeEnabled")
        
        // Load display name from Core Data or UserDefaults
        displayName = UserDefaults.standard.string(forKey: "userDisplayName") ?? "User"
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
        } catch {
            throw BiometricError.authenticationFailed(error.localizedDescription)
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
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
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

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section("Notifications") {
                    Toggle("Daily Reminders", isOn: .constant(true))
                    Toggle("Coaching Tips", isOn: .constant(true))
                    Toggle("Weekly Reports", isOn: .constant(false))
                }
                
                Section("Privacy") {
                    Toggle("Analytics", isOn: .constant(false))
                    Toggle("Crash Reports", isOn: .constant(true))
                }
                
                Section("Audio") {
                    HStack {
                        Text("Recording Quality")
                        Spacer()
                        Text("High")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Noise Reduction", isOn: .constant(true))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(SubscriptionService())
    }
}
