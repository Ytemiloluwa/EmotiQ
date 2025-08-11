//
//  SubscriptionPaywallView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 08-08-2025.
//

import SwiftUI
import Combine
import RevenueCat

struct SubscriptionPaywallView: View {
    @StateObject private var viewModel = SubscriptionPaywallViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: SubscriptionStatus = .premium
    
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
                            Image(systemName: "crown.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.yellow)
                            
                            Text("Unlock Your Full Potential")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Text("Get unlimited voice check-ins and advanced emotional insights")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Features List
                        VStack(spacing: 16) {
                            FeatureRowView(
                                icon: "infinity",
                                title: "Unlimited Voice Check-ins",
                                description: "No daily limits on emotional analysis"
                            )
                            
                            FeatureRowView(
                                icon: "brain.head.profile",
                                title: "Advanced AI Coaching",
                                description: "Personalized insights and recommendations"
                            )
                            
                            FeatureRowView(
                                icon: "waveform.path",
                                title: "Voice Affirmations",
                                description: "Personalized affirmations in your own voice"
                            )
                            
                            FeatureRowView(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Detailed Analytics",
                                description: "Track your emotional patterns over time"
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Subscription Plans
                        VStack(spacing: 16) {
                            Text("Choose Your Plan")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                // Premium Plan
                                SubscriptionPlanView(
                                    tier: .premium,
                                    isSelected: selectedTier == .premium,
                                    isPopular: true,
                                    onTap: { selectedTier = .premium }
                                )
                                
                                // Pro Plan
                                SubscriptionPlanView(
                                    tier: .pro,
                                    isSelected: selectedTier == .pro,
                                    isPopular: false,
                                    onTap: { selectedTier = .pro }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Trial Information
                        if viewModel.isTrialEligible {
                            VStack(spacing: 8) {
                                Text("🎉 Start Your Free Trial")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("7 days free, then \(selectedTier.monthlyPrice)/month")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.2))
                            )
                            .padding(.horizontal, 24)
                        }
                        
                        // Purchase Button
                        Button(action: {
                            viewModel.purchaseSubscription(selectedTier)
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: Config.UI.primaryPurple)))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(viewModel.isTrialEligible ? "Start Free Trial" : "Subscribe Now")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(Color(hex: Config.UI.primaryPurple))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                        }
                        .disabled(viewModel.isLoading)
                        .padding(.horizontal, 24)
                        
                        // Secondary Actions
                        VStack(spacing: 16) {
                            Button("Restore Purchases") {
                                viewModel.restorePurchases()
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .disabled(viewModel.isLoading)
                            
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
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .alert("Purchase Successful", isPresented: $viewModel.showSuccessAlert) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Welcome to EmotiQ \(selectedTier.displayName)! Enjoy unlimited access to all features.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            viewModel.loadOfferings()
            viewModel.checkTrialEligibility()
        }
        .onChange(of: viewModel.purchaseCompleted) { completed in
            if completed {
                dismiss()
            }
        }
    }
}

struct FeatureRowView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
        )
    }
}

struct SubscriptionPlanView: View {
    let tier: SubscriptionStatus
    let isSelected: Bool
    let isPopular: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header with popular badge
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(isSelected ? Color(hex: Config.UI.primaryPurple) : .white)
                        
                        Text(tier.monthlyPrice + "/month")
                            .font(.headline)
                            .foregroundColor(isSelected ? Color(hex: Config.UI.primaryPurple) : .white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    if isPopular {
                        Text("POPULAR")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                }
                
                // Features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(isSelected ? Color(hex: Config.UI.primaryCyan) : .white.opacity(0.8))
                            
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(isSelected ? Color(hex: Config.UI.primaryPurple) : .white.opacity(0.9))
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white : Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color(hex: Config.UI.primaryCyan) : Color.white.opacity(0.3),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - ViewModel

class SubscriptionPaywallViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showError = false
    @Published var showSuccessAlert = false
    @Published var errorMessage = ""
    @Published var isTrialEligible = false
    @Published var purchaseCompleted = false
    @Published var offerings: RevenueCat.Offerings?
    
    // Testing
    
    @Published var currentOffering: Offering?
    @Published var premiumPackage: Package?
    @Published var proPackage: Package?
    
    // SANBOX testing //
    
    private let revenueCatService: RevenueCatServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(revenueCatService: RevenueCatServiceProtocol = RevenueCatService(),
         subscriptionService: SubscriptionServiceProtocol = SubscriptionService()) {
        self.revenueCatService = revenueCatService
        self.subscriptionService = subscriptionService
    }
    // SANBOX testing //
    
//    func loadOfferings() {
//        isLoading = true
//        
//        Purchases.shared.getOfferings { [weak self] offerings, error in
//            DispatchQueue.main.async {
//                self?.isLoading = false
//                
//                if let error = error {
//                    self?.showError(message: "Failed to load subscription options: \(error.localizedDescription)")
//                    return
//                }
//                
//                guard let offering = offerings?.current else {
//                    self?.showError(message: "No subscription options available")
//                    return
//                }
//                
//                self?.currentOffering = offering
//                self?.premiumPackage = offering.package(identifier: "premium_monthly")
//                self?.proPackage = offering.package(identifier: "pro_monthly")
//                
//                if Config.isDebugMode {
//                    print("✅ Offerings loaded successfully")
//                    print("Premium package: \(self?.premiumPackage?.storeProduct.localizedTitle ?? "nil")")
//                    print("Pro package: \(self?.proPackage?.storeProduct.localizedTitle ?? "nil")")
//                }
//            }
//        }
//    }
    // SANBOX testing //
    
    func loadOfferings() {
        isLoading = true
        
        revenueCatService.getOfferings()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.showError(message: error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] offerings in
                    self?.offerings = offerings
                    
                    if Config.isDebugMode {
                        print("📦 Loaded \(offerings.all.count) subscription offerings")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func checkTrialEligibility() {
        revenueCatService.checkTrialEligibility()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion, Config.isDebugMode {
                        print("❌ Failed to check trial eligibility: \(error)")
                    }
                },
                receiveValue: { [weak self] isEligible in
                    self?.isTrialEligible = isEligible
                    
                    if Config.isDebugMode {
                        print("🎁 Trial eligibility: \(isEligible ? "Eligible" : "Not eligible")")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func purchaseSubscription(_ tier: SubscriptionStatus) {
        guard tier != .free else { return }
        
        isLoading = true
        
        if Config.isDebugMode {
            print("🛒 Attempting to purchase: \(tier.displayName) (\(tier.monthlyPrice))")
        }
        
        revenueCatService.purchaseProduct(tier.productIdentifier)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.showError(message: error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.showSuccessAlert = true
                        self?.purchaseCompleted = true
                        
                        // Track purchase for analytics
                        if Config.isDebugMode {
                            print("✅ Purchase completed successfully: \(tier.displayName)")
                        }
                    } else {
                        self?.showError(message: "Purchase failed. Please try again.")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func restorePurchases() {
        isLoading = true
        
        if Config.isDebugMode {
            print("🔄 Restoring purchases...")
        }
        
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
                        self?.showSuccessAlert = true
                        self?.purchaseCompleted = true
                        
                        if Config.isDebugMode {
                            print("✅ Purchases restored successfully")
                        }
                    } else {
                        self?.showError(message: "No previous purchases found to restore.")
                    }
                }
            )
            .store(in: &cancellables)
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
            print("❌ Subscription Error: \(message)")
        }
    }
}

#Preview {
    SubscriptionPaywallView()
}
