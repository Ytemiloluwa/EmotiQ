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
    
    // Navigation callback for post-purchase flow
    let onPurchaseSuccess: (() -> Void)?
    
    init(onPurchaseSuccess: (() -> Void)? = nil) {
        self.onPurchaseSuccess = onPurchaseSuccess
    }
    
    // Default initializer for backward compatibility
    init() {
        self.onPurchaseSuccess = nil
    }
    
    var body: some View {
            ZStack {
            // Background gradient - covers entire view
                LinearGradient(
                    colors: [
                        Color(hex: Config.UI.primaryPurple),
                        Color(hex: Config.UI.primaryCyan)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom navigation bar
                HStack {
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.yellow)
                            
                            Text("Unlock EmotiQ Full Potential")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Track your emotions with unlimited access")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Subscription Plans with Integrated Features
                        VStack(spacing: 16) {
                            Text("Choose Your Plan")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            if let offerings = viewModel.offerings?.current, !offerings.availablePackages.isEmpty {
                                VStack(spacing: 12) {
                                    ForEach(offerings.availablePackages, id: \.identifier) { package in
                                        PackageCardView(
                                            package: package,
                                            isSelected: viewModel.selectedPackage?.identifier == package.identifier,
                                            onTap: { viewModel.selectedPackage = package }
                                        )
                                    }
                                }
                            } else if let allOfferings = viewModel.offerings?.all.values,
                                      let firstOffering = allOfferings.first(where: { !$0.availablePackages.isEmpty }) {
                                VStack(spacing: 12) {
                                    ForEach(firstOffering.availablePackages, id: \.identifier) { package in
                                        PackageCardView(
                                            package: package,
                                            isSelected: viewModel.selectedPackage?.identifier == package.identifier,
                                            onTap: { viewModel.selectedPackage = package }
                                        )
                                    }
                                }
                            } else {
                                // Loading state
                                VStack(spacing: 12) {
                                    ForEach(0..<2, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 120)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Trial Information
                        if viewModel.isTrialEligible {
                            VStack(spacing: 8) {
                                Text("🎉 Start Your Free Trial")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if let selectedPackage = viewModel.selectedPackage {
                                    Text("7 days free, then \(selectedPackage.storeProduct.localizedPriceString)/month")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                }
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
                            viewModel.purchaseSelectedPackage()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: Config.UI.primaryPurple)))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(viewModel.purchaseButtonTitle)
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
                        .disabled(viewModel.isLoading || viewModel.selectedPackage == nil)
                        .padding(.horizontal, 24)
                        
                        // Apple-required disclosure
                        VStack(spacing: 8) {
                            Text("Auto-renewing subscription")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Subscription auto‑renews unless canceled at least 24 hours before the end of the current period. Manage or cancel in Account Settings after purchase.")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.8))
                        }
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
                                Button("Terms of Use") {
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
        }
        .alert("Purchase Successful", isPresented: $viewModel.showSuccessAlert) {
            Button("Continue") {
                // Don't dismiss immediately - let the onChange handler handle it
                // This ensures subscription status is refreshed first
            }
        } message: {
            if let package = viewModel.selectedPackage {
                Text("Welcome to EmotiQ! Enjoy your \(package.storeProduct.localizedTitle).")
            }
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
        .onChange(of: viewModel.purchaseCompleted) { oldValue, newValue in
            if newValue {
                // Refresh subscription status immediately after successful purchase
                Task {
                    await refreshSubscriptionStatus()
                    // Small delay to ensure state is updated before dismissing
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Navigate to purchased features or dismiss
                    if let onPurchaseSuccess = onPurchaseSuccess {
                        onPurchaseSuccess()
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func refreshSubscriptionStatus() async {
        // Force refresh subscription status to immediately unlock features
        if let subscriptionService = viewModel.subscriptionService as? SubscriptionService {
            await subscriptionService.refreshSubscriptionStatus()
            
            // Also refresh the main subscription service if it's different
            await SubscriptionService.shared.refreshSubscriptionStatus()

        }
    }
}

// MARK: - Package Card View
struct PackageCardView: View {
    let package: RevenueCat.Package
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header with title and price
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(package.storeProduct.localizedTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(isSelected ? Color(hex: Config.UI.primaryPurple) : .white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                                 Text(package.storeProduct.localizedPriceString + getSubscriptionPeriod(package))
                                     .font(.headline)
                                     .foregroundColor(isSelected ? Color(hex: Config.UI.primaryPurple) : .white.opacity(0.8))
                                 
                                 Text("Auto-renewing subscription")
                                     .font(.caption)
                                     .foregroundColor(isSelected ? Color(hex: Config.UI.primaryPurple).opacity(0.7) : .white.opacity(0.6))
                             }
                    }
                    
                    Spacer()
                    
                    // Popular badge for Premium
                    if package.storeProduct.productIdentifier.contains("pro") {
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
                
                // Features based on package
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(getFeaturesForPackage(package), id: \.self) { feature in
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
    
    private func getSubscriptionPeriod(_ package: RevenueCat.Package) -> String {
        let productId = package.storeProduct.productIdentifier
        
        if productId.contains("monthly") {
            return "/month"
        } else if productId.contains("yearly") || productId.contains("annual") {
            return "/year"
        } else if productId.contains("weekly") {
            return "/week"
        } else {
            // Default to monthly if unclear
            return "/month"
        }
    }
    
    
    private func getFeaturesForPackage(_ package: RevenueCat.Package) -> [String] {
        let productId = package.storeProduct.productIdentifier
        
        if productId.contains("premium") {
            return [
                "Unlimited voice check-ins",
                "Voice cloning",
                "Goal setting & tracking",
                "Advanced analytics"
            ]
        } else if productId.contains("pro") {
            return [
                "Everything in Premium",
                "Data export capabilities",
                "Priority customer support",
                "Early access to new features"
            ]
        }
        
        return []
    }
}

// MARK: - ViewModel

@MainActor
class SubscriptionPaywallViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showError = false
    @Published var showSuccessAlert = false
    @Published var errorMessage = ""
    @Published var isTrialEligible = false
    @Published var purchaseCompleted = false
    @Published var offerings: RevenueCat.Offerings?
    
    // Testing
    
    @Published var selectedPackage: Package?
    
    // SANBOX testing //
    
    private let revenueCatService: RevenueCatServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(revenueCatService: RevenueCatServiceProtocol = RevenueCatService.shared,
         subscriptionService: SubscriptionServiceProtocol = SubscriptionService()) {
        self.revenueCatService = revenueCatService
        self.subscriptionService = subscriptionService
    }
    
    var purchaseButtonTitle: String {
        if isTrialEligible {
            return "Subscribe Now"
        }
        return "Subscribe Now"
    }

    
    func loadOfferings() {
        isLoading = true
        
        
        // Use Task to handle async operations properly
        Task {
            do {
                let offerings = try await revenueCatService.getOfferings()
                
                await MainActor.run {
                    self.offerings = offerings
                    self.isLoading = false
                    
                    
                    // Auto-select the first package from any offering
                    if let firstPackage = offerings.current?.availablePackages.first {
                        self.selectedPackage = firstPackage

                    } else if let firstOffering = offerings.all.values.first,
                              let firstPackage = firstOffering.availablePackages.first {
                        self.selectedPackage = firstPackage

                    } else {

                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    
                    // If it's a configuration error, try to configure and retry once
                    if error.localizedDescription.contains("Failed to load subscription options") {
                        
                        // Small delay then retry
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                            self.loadOfferings()
                        }
                    } else {
                        self.showError(message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    func checkTrialEligibility() {
        revenueCatService.checkTrialEligibility()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
           
                    }
                },
                receiveValue: { [weak self] isEligible in
                    self?.isTrialEligible = isEligible
                    
                }
            )
            .store(in: &cancellables)
    }
    
    func purchaseSelectedPackage() {
        guard let package = selectedPackage else { return }
        
        isLoading = true
        
        
        revenueCatService.purchaseProduct(package.storeProduct.productIdentifier)
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
                        
                    } else {
                        self?.showError(message: "Purchase failed. Please try again.")
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
                        self?.showSuccessAlert = true
                        self?.purchaseCompleted = true
                        
                    } else {
                        self?.showError(message: "No previous purchases found to restore.")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func openTermsOfService() {
        if let url = URL(string: "https://ytemiloluwa.github.io/Term-of-use.html") {
            UIApplication.shared.open(url)
        }

    }
    
    func openPrivacyPolicy() {
        if let url = URL(string: "https://ytemiloluwa.github.io/privacy-policy.html") {
            UIApplication.shared.open(url)
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true

    }
    
}

#Preview {
    SubscriptionPaywallView()
        .environment(\.colorScheme, .light)
   
}

#Preview {
    SubscriptionPaywallView()
        .environment(\.colorScheme, .dark)

}

#Preview("With Navigation Callback") {
    SubscriptionPaywallView(onPurchaseSuccess: {
    
    })
        .environment(\.colorScheme, .light)
}

