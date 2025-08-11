//
//  SubscriptionManagementView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 08-08-2025.
//

import SwiftUI
import Combine
import RevenueCat

struct SubscriptionManagementView: View {
    @StateObject private var viewModel = SubscriptionManagementViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hex: Config.UI.primaryPurple),
                        Color(hex: Config.UI.primaryCyan)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("Subscription Management")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        // Current Subscription Status
                        VStack(spacing: 16) {
                            Text("Current Plan")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            CurrentSubscriptionCard(
                                subscription: viewModel.currentSubscription,
                                expirationDate: viewModel.expirationDate
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Usage Statistics
                        if viewModel.currentSubscription == .free {
                            VStack(spacing: 16) {
                                Text("Usage This Month")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                UsageStatsCard(
                                    dailyUsageRemaining: viewModel.dailyUsageRemaining,
                                    totalUsageThisMonth: viewModel.totalUsageThisMonth
                                )
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            if viewModel.currentSubscription == .free {
                                Button(action: {
                                    viewModel.showUpgradePaywall = true
                                }) {
                                    HStack {
                                        Image(systemName: "crown.fill")
                                        Text("Upgrade to Premium")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(Color(hex: Config.UI.primaryPurple))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.white)
                                    .cornerRadius(28)
                                }
                            } else {
                                Button(action: {
                                    viewModel.showUpgradePaywall = true
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                        Text(viewModel.currentSubscription == .premium ? "Upgrade to Pro" : "Manage Subscription")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                                }
                            }
                            
                            Button(action: {
                                viewModel.restorePurchases()
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Restore Purchases")
                                    }
                                }
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                            }
                            .disabled(viewModel.isLoading)
                        }
                        .padding(.horizontal, 24)
                        
                        // Support Links
                        VStack(spacing: 16) {
                            Text("Need Help?")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                Button("Contact Support") {
                                    viewModel.contactSupport()
                                }
                                .foregroundColor(.white.opacity(0.8))
                                
                                Button("Manage Subscription in App Store") {
                                    viewModel.openAppStoreSubscriptions()
                                }
                                .foregroundColor(.white.opacity(0.8))
                                
                                HStack(spacing: 20) {
                                    Button("Terms of Service") {
                                        viewModel.openTermsOfService()
                                    }
                                    
                                    Button("Privacy Policy") {
                                        viewModel.openPrivacyPolicy()
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $viewModel.showUpgradePaywall) {
            SubscriptionPaywallView()
        }
        .alert("Success", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            viewModel.loadSubscriptionInfo()
        }
    }
}

struct CurrentSubscriptionCard: View {
    let subscription: SubscriptionStatus
    let expirationDate: Date?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(subscription.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(subscription.monthlyPrice + (subscription != .free ? "/month" : ""))
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: subscription == .free ? "person" : subscription == .premium ? "star.fill" : "crown.fill")
                    .font(.title)
                    .foregroundColor(subscription == .free ? .white.opacity(0.6) : .yellow)
            }
            
            if let expirationDate = expirationDate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expires on")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(DateFormatter.subscriptionFormatter.string(from: expirationDate))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                Text("Included Features:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                
                ForEach(subscription.features.prefix(3), id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(feature)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                    }
                }
                
                if subscription.features.count > 3 {
                    Text("+ \(subscription.features.count - 3) more features")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.2))
        )
    }
}

struct UsageStatsCard: View {
    let dailyUsageRemaining: Int
    let totalUsageThisMonth: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(dailyUsageRemaining) remaining")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(totalUsageThisMonth) used")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            // Progress bar for daily usage
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Progress")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(
                                width: geometry.size.width * CGFloat(max(0, Config.Subscription.freeDailyLimit - dailyUsageRemaining)) / CGFloat(Config.Subscription.freeDailyLimit),
                                height: 8
                            )
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.2))
        )
    }
}

// MARK: - ViewModel

class SubscriptionManagementViewModel: ObservableObject {
    @Published var currentSubscription: SubscriptionStatus = .free
    @Published var expirationDate: Date?
    @Published var dailyUsageRemaining: Int = 3
    @Published var totalUsageThisMonth: Int = 0
    @Published var isLoading = false
    @Published var showError = false
    @Published var showSuccessAlert = false
    @Published var showUpgradePaywall = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let revenueCatService: RevenueCatServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(subscriptionService: SubscriptionServiceProtocol = SubscriptionService(),
         revenueCatService: RevenueCatServiceProtocol = RevenueCatService()) {
        self.subscriptionService = subscriptionService
        self.revenueCatService = revenueCatService
        
        setupBindings()
    }
    
    private func setupBindings() {
        subscriptionService.currentSubscription
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentSubscription, on: self)
            .store(in: &cancellables)
        
        subscriptionService.dailyUsageRemaining
            .receive(on: DispatchQueue.main)
            .assign(to: \.dailyUsageRemaining, on: self)
            .store(in: &cancellables)
    }
    
    func loadSubscriptionInfo() {
        isLoading = true
        
        subscriptionService.checkSubscriptionStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.showError(message: error.localizedDescription)
                    }
                },
                receiveValue: { status in
                    // Additional subscription info loaded
                    if Config.isDebugMode {
                        print("📱 Subscription info loaded: \(status.displayName)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func restorePurchases() {
        isLoading = true
        
        revenueCatService.restorePurchases()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.showError(message: error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] customerInfo in
                    if !customerInfo.activeSubscriptions.isEmpty {
                        self?.showSuccess(message: "Purchases restored successfully!")
                    } else {
                        self?.showError(message: "No previous purchases found to restore.")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func contactSupport() {
        if let url = URL(string: "mailto:support@emotiq.app?subject=EmotiQ Support Request") {
            UIApplication.shared.open(url)
        }
    }
    
    func openAppStoreSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    func openTermsOfService() {
        if let url = URL(string: "https://emotiq.app/terms") {
            UIApplication.shared.open(url)
        }
    }
    
    func openPrivacyPolicy() {
        if let url = URL(string: "https://emotiq.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        
        if Config.isDebugMode {
            print("❌ Subscription Management Error: \(message)")
        }
    }
    
    private func showSuccess(message: String) {
        successMessage = message
        showSuccessAlert = true
        
        if Config.isDebugMode {
            print("✅ Subscription Management Success: \(message)")
        }
    }
}

// MARK: - Extensions




#Preview {
    SubscriptionManagementView()
}
