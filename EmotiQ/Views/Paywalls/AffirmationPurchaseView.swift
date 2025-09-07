//
//  AffirmationPurchaseView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import SwiftUI
import Combine
import RevenueCat

struct AffirmationPurchaseView: View {
    @StateObject private var viewModel = AffirmationPurchaseViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var shouldDismiss: Bool
    
    // Animation states
    @State private var animateHeader = false
    @State private var animateFeatures = false
    @State private var animatePlans = false
    @State private var showSparkles = false
    
    init(shouldDismiss: Binding<Bool> = .constant(false)) {
        self._shouldDismiss = shouldDismiss
    }
    
    var body: some View {
        //NavigationView {
        ZStack {
            // Premium background using ThemeColors
            ThemeColors.backgroundGradient
                .ignoresSafeArea()
            
            // Additional premium overlay
            premiumBackgroundOverlay
            
            // Floating sparkles animation
            if showSparkles {
                FloatingSparklesView()
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header Section (more compact)
                    heroHeaderSection
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    
                    // Pricing Plans
                    pricingPlansSection
                        .padding(.bottom, 20)
                    
                    // Call to Action
                    callToActionSection
                        .padding(.bottom, 20)
                    
                    // Footer Links
                    footerSection
                        .padding(.bottom, 20)
                    
                    // Add some bottom padding for better scrolling
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(ThemeColors.secondaryText)
                        .background(ThemeColors.secondaryBackground.opacity(0.8))
                        .clipShape(Circle())
                }
            }
        }
        .onAppear {
            startAnimationSequence()
        }
        .alert("Welcome to Premium!", isPresented: $viewModel.showSuccessAlert) {
            Button("Start Exploring") {
                shouldDismiss = true
                dismiss()
            }
        } message: {
            Text("You now have unlimited access to all premium features!")
        }
        .alert("Purchase Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.shouldReturnToAffirmations) { shouldReturn in
            if shouldReturn {
                shouldDismiss = true
                dismiss()
            }
        }

    }
    
    // MARK: - Premium Background Overlay
    private var premiumBackgroundOverlay: some View {
        ZStack {
            // Animated overlay gradients using ThemeColors
            RadialGradient(
                colors: [
                    ThemeColors.accent.opacity(0.3),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 400
            )
            .scaleEffect(animateHeader ? 1.2 : 0.8)
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: animateHeader)
            
            RadialGradient(
                colors: [
                    ThemeColors.primaryPurple.opacity(0.2),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 150,
                endRadius: 500
            )
            .scaleEffect(animateHeader ? 0.8 : 1.2)
            .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: animateHeader)
        }
    }
    
    // MARK: - Hero Header Section
    private var heroHeaderSection: some View {
        VStack(spacing: 24) {
            // Premium icon with glow effect using ThemeColors
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ThemeColors.accent.opacity(0.6),
                                ThemeColors.primaryPurple.opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(animateHeader ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateHeader)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 35, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ThemeColors.accent, ThemeColors.primaryPurple, ThemeColors.primaryCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateHeader ? 1.0 : 0.8)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3), value: animateHeader)
            }
            
            // Premium title using ThemeColors
            VStack(spacing: 8) {
                Text("Voice Affirmations")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ThemeColors.primaryText)
                    .opacity(animateHeader ? 1.0 : 0.0)
                    .offset(y: animateHeader ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.5), value: animateHeader)
                
                Text("Hear affirmations in your own voice for maximum emotional impact")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ThemeColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .opacity(animateHeader ? 1.0 : 0.0)
                    .offset(y: animateHeader ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.7), value: animateHeader)
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Premium Features Section
    private var premiumFeaturesSection: some View {
        VStack(spacing: 24) {
            Text("What You'll Get")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(ThemeColors.primaryText)
                .opacity(animateFeatures ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(1.0), value: animateFeatures)
            
            VStack(spacing: 20) {
                PremiumFeatureCard(
                    icon: "brain.head.profile",
                    iconColor: ThemeColors.primaryPurple,
                    title: "AI-Powered Personalization",
                    description: "Affirmations tailored specifically to your emotional state",
                    animationDelay: 1.2
                )
                .opacity(animateFeatures ? 1.0 : 0.0)
                .offset(x: animateFeatures ? 0 : -50)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2), value: animateFeatures)
                .lineLimit(nil)
                
                PremiumFeatureCard(
                    icon: "waveform",
                    iconColor: ThemeColors.primaryCyan,
                    title: "Your Voice Speaking",
                    description: "Write an affirmation, hear it your own voice for emotional impact",
                    animationDelay: 1.4
                )
                .opacity(animateFeatures ? 1.0 : 0.0)
                .offset(x: animateFeatures ? 0 : 50)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.4), value: animateFeatures)
                
                PremiumFeatureCard(
                    icon: "sparkles",
                    iconColor: ThemeColors.accent,
                    title: "Emotion-Aware Content",
                    description: "Dynamic content that adapts to your current emotional state",
                    animationDelay: 1.6
                )
                .opacity(animateFeatures ? 1.0 : 0.0)
                .offset(x: animateFeatures ? 0 : -50)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.6), value: animateFeatures)
                
                PremiumFeatureCard(
                    icon: "heart.text.square",
                    iconColor: ThemeColors.success,
                    title: "15+ Categories",
                    description: "Confidence, gratitude, courage, stress relief",
                    animationDelay: 1.8
                )
                .opacity(animateFeatures ? 1.0 : 0.0)
                .offset(x: animateFeatures ? 0 : 50)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.8), value: animateFeatures)
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Pricing Plans Section
    private var pricingPlansSection: some View {
        VStack(spacing: 24) {
            Text("Choose Your Plan")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(ThemeColors.primaryText)
                .opacity(animatePlans ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(2.0), value: animatePlans)
            
            if viewModel.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 20)
                            .fill(ThemeColors.secondaryBackground)
                            .frame(height: 120)
                    }
                }
                .padding(.horizontal, 24)
            } else if viewModel.availablePackages.isEmpty {
                // No packages available
                VStack(spacing: 16) {
                    Text("No packages available")
                        .font(.system(size: 16))
                        .foregroundColor(ThemeColors.secondaryText)
                        .padding()
                }
                .padding(.horizontal, 24)
            } else {
                // Available packages
                VStack(spacing: 16) {
                    ForEach(viewModel.availablePackages, id: \.identifier) { package in
                        RevenueCatPackageCard(
                            package: package,
                            isSelected: viewModel.selectedPackage?.identifier == package.identifier,
                            onTap: { viewModel.selectedPackage = package }
                        )
                        .opacity(animatePlans ? 1.0 : 0.0)
                        .offset(y: animatePlans ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(2.2), value: animatePlans)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Call to Action Section
    private var callToActionSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                viewModel.purchaseSelectedPackage()
            }) {
                HStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.title3)
                        
                        Text("Purchase")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        ThemeColors.primaryPurple,
                                        ThemeColors.accent,
                                        ThemeColors.primaryCyan
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear,
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .shadow(
                    color: ThemeColors.accent.opacity(0.4),
                    radius: 20,
                    x: 0,
                    y: 10
                )
            }
            .disabled(viewModel.isLoading || viewModel.selectedPackage == nil)
            .scaleEffect(viewModel.isLoading ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: viewModel.isLoading)
            .padding(.horizontal, 24)
            
//            // Trust indicators using ThemeColors
//            HStack(spacing: 20) {
//                //TrustIndicator(icon: "lock.shield.fill", text: "Secure Payment")
//                TrustIndicator(icon: "arrow.clockwise", text: "Easy Cancellation")
//                TrustIndicator(icon: "checkmark.seal.fill", text: "Instant Access")
//            }
            
            // Removed consumable purchase text to save space for footer buttons
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
//            Button("Restore Purchases") {
//                viewModel.restorePurchases()
//            }
//            .font(.system(size: 16, weight: .medium))
//            .foregroundColor(ThemeColors.secondaryText)
//            .disabled(viewModel.isLoading)
            
            HStack(spacing: 32) {
                Button("Terms of Use") {
                    viewModel.openTermsOfService()
                }
                
                Button("Privacy Policy") {
                    viewModel.openPrivacyPolicy()
                }
            }
            .font(.system(size: 14))
            .foregroundColor(ThemeColors.tertiaryText)
        }
    }
    
    // MARK: - Animation Control
    private func startAnimationSequence() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateHeader = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.6)) {
                animateFeatures = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.6)) {
                animatePlans = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showSparkles = true
        }
    }
}

// MARK: - Premium Feature Card
struct PremiumFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let animationDelay: Double
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with glow using ThemeColors
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ThemeColors.primaryText)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(ThemeColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ThemeColors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [iconColor.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.clear)
                .shadow(color: iconColor.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - RevenueCat Package Card
struct RevenueCatPackageCard: View {
    let package: RevenueCat.Package
    let isSelected: Bool
    let onTap: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header with recommendation badge
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(package.storeProduct.localizedTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ThemeColors.primaryText)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(package.storeProduct.localizedDescription)
                            .font(.system(size: 15))
                            .foregroundColor(ThemeColors.secondaryText)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer(minLength: 16)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(package.storeProduct.localizedPriceString)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isSelected ? ThemeColors.accent : ThemeColors.primaryText)
                        
                        // Show "BEST VALUE" for lifetime package
                        if package.storeProduct.productIdentifier == "affirmation_lifetime" {
                            Text("BEST VALUE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(ThemeColors.success)
                                )
                        }
                    }
                }
                
                // Features list based on product type
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(getFeaturesForPackage(package), id: \.self) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(ThemeColors.success)
                            
                            Text(feature)
                                .font(.system(size: 15))
                                .foregroundColor(ThemeColors.secondaryText)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [
                                    ThemeColors.accent.opacity(0.3),
                                    ThemeColors.primaryPurple.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                                LinearGradient(
                                    colors: [
                                        ThemeColors.secondaryBackground,
                                        ThemeColors.secondaryBackground.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                    
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ?
                            LinearGradient(
                                colors: [ThemeColors.accent, ThemeColors.primaryPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                                LinearGradient(
                                    colors: [ThemeColors.secondaryText.opacity(0.2), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
            )
            .shadow(
                color: isSelected ? ThemeColors.accent.opacity(0.3) : ThemeColors.tertiaryBackground.opacity(0.1),
                radius: isSelected ? 15 : 5,
                x: 0,
                y: isSelected ? 8 : 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getFeaturesForPackage(_ package: RevenueCat.Package) -> [String] {
        let productId = package.storeProduct.productIdentifier
        
        if productId == "affirmation_pack_10" {
            return [
                "10 category generations",
                "10 Customized affirmations",
                "Priority voice generation"
            ]
        } else if productId == "affirmation_lifetime" {
            return [
                "Lifetime access",
                "Unlimited category generations",
                "Unlimited Customized affirmations",
                "Priority voice generation"
            ]
        }
        
        return []
    }
}

// MARK: - Premium Plan Card (Legacy - keeping for compatibility)
struct PremiumPlanCard: View {
    let plan: AffirmationPlan
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header with recommendation badge
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ThemeColors.primaryText)
                        
                        Text(plan.description)
                            .font(.system(size: 15))
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(plan.price)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isSelected ? ThemeColors.accent : ThemeColors.primaryText)
                        
                        if isRecommended {
                            Text("BEST VALUE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(ThemeColors.success)
                                )
                        }
                    }
                }
                
                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(ThemeColors.success)
                            
                            Text(feature)
                                .font(.system(size: 15))
                                .foregroundColor(ThemeColors.secondaryText)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [
                                    ThemeColors.accent.opacity(0.3),
                                    ThemeColors.primaryPurple.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                                LinearGradient(
                                    colors: [
                                        ThemeColors.secondaryBackground,
                                        ThemeColors.secondaryBackground.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                    
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ?
                            LinearGradient(
                                colors: [ThemeColors.accent, ThemeColors.primaryPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                                LinearGradient(
                                    colors: [ThemeColors.secondaryText.opacity(0.2), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
            )
            .shadow(
                color: isSelected ? ThemeColors.accent.opacity(0.3) : ThemeColors.tertiaryBackground.opacity(0.1),
                radius: isSelected ? 15 : 5,
                x: 0,
                y: isSelected ? 8 : 2
            )
            .scaleEffect(isSelected ? 1.0 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Trust Indicator
struct TrustIndicator: View {
    let icon: String
    let text: String
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ThemeColors.success)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ThemeColors.secondaryText)
        }
    }
}

// MARK: - Floating Sparkles Animation
struct FloatingSparklesView: View {
    @State private var sparkles: [SparkleData] = []
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            ForEach(sparkles, id: \.id) { sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: sparkle.size))
                    .foregroundColor(sparkle.color)
                    .position(sparkle.position)
                    .opacity(sparkle.opacity)
                    .animation(.linear(duration: sparkle.duration), value: sparkle.position)
                    .animation(.easeInOut(duration: sparkle.duration * 0.5), value: sparkle.opacity)
            }
        }
        .onAppear {
            startSparkleAnimation()
        }
    }
    
    private func startSparkleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            addSparkle()
        }
    }
    
    private func addSparkle() {
        let sparkleColors = [ThemeColors.accent, ThemeColors.primaryPurple, ThemeColors.primaryCyan, ThemeColors.success]
        
        let newSparkle = SparkleData(
            id: UUID(),
            position: CGPoint(
                x: CGFloat.random(in: 50...350),
                y: CGFloat.random(in: 100...800)
            ),
            size: CGFloat.random(in: 12...20),
            color: sparkleColors.randomElement()!,
            opacity: 0.0,
            duration: Double.random(in: 2.0...4.0)
        )
        
        sparkles.append(newSparkle)
        
        // Animate in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let index = sparkles.firstIndex(where: { $0.id == newSparkle.id }) {
                sparkles[index].opacity = 0.8
                sparkles[index].position.y -= 100
            }
        }
        
        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + newSparkle.duration) {
            sparkles.removeAll { $0.id == newSparkle.id }
        }
        
        // Limit number of sparkles
        if sparkles.count > 8 {
            sparkles.removeFirst()
        }
    }
}

struct SparkleData {
    let id: UUID
    var position: CGPoint
    let size: CGFloat
    let color: Color
    var opacity: Double
    let duration: Double
}

// MARK: - Preview
struct AffirmationPurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        AffirmationPurchaseView(shouldDismiss: .constant(false))
            .environmentObject(ThemeManager())
    }
}



// MARK: - Affirmation Plan Model

enum AffirmationPlan: CaseIterable {
    case pack
    case lifetime
    
    var title: String {
        switch self {
        case .pack: return "Category Pack"
        case .lifetime: return "Lifetime Access"
        }
    }
    
    var description: String {
        switch self {
        case .pack: return "10 category generations"
        case .lifetime: return "Unlimited category generations"
        }
    }
    
    var price: String {
        switch self {
        case .pack: return "$9.99"
        case .lifetime: return "$15.99"
        }
    }
    
    var features: [String] {
        switch self {
        case .pack:
            return [
                "10 category generations",
                "10 Customized affirmations",
                "Priority voice generation"
            ]
        case .lifetime:
            return [
                "Lifetime access",
                "Unlimited category generations",
                "Unlimited Customized affirmation",
                "Priority voice generation",
                
            ]
        }
    }
    
    var productIdentifier: String {
        switch self {
        case .pack: return "affirmation_pack_10"
        case .lifetime: return "affirmation_lifetime"
        }
    }
}



// MARK: - View Model
@MainActor
class AffirmationPurchaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showSuccessAlert = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var shouldReturnToAffirmations = false
    let retryManager = PurchaseRetryManager()
    @Published var availablePackages: [RevenueCat.Package] = []
    @Published var selectedPackage: RevenueCat.Package?
    
    private let revenueCatService: RevenueCatServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(revenueCatService: RevenueCatServiceProtocol = RevenueCatService.shared,
         subscriptionService: SubscriptionServiceProtocol = SubscriptionService.shared) {
        self.revenueCatService = revenueCatService
        self.subscriptionService = subscriptionService
        
        #if DEBUG
        // Add mock data for preview/testing
        if Config.isDebugMode {
            print("🔍 DEBUG: Adding mock packages for testing")
            // This will be replaced when real packages load
        }
        #endif
        
        loadOfferings()
    }
    
    func loadOfferings() {
        isLoading = true
        
        // Load RevenueCat offerings
        revenueCatService.getOfferings()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        if Config.isDebugMode {
                            print("❌ Failed to load offerings: \(error)")
                        }
                        self?.showError = true
                        self?.errorMessage = "Failed to load products. Please try again."
                    }
                },
                receiveValue: { [weak self] offerings in
                    self?.isLoading = false
                    
                    // Filter for affirmation products
                    let affirmationPackages = self?.filterAffirmationPackages(from: offerings) ?? []
                    self?.availablePackages = affirmationPackages
                    
                    // Auto-select first package if available
                    if let firstPackage = affirmationPackages.first {
                        self?.selectedPackage = firstPackage
                    }
                    
                    if Config.isDebugMode {
                        print("✅ Loaded \(offerings.all.count) offerings")
                        print("🎯 Found \(affirmationPackages.count) affirmation packages")
                        
                        for package in affirmationPackages {
                            print("   - \(package.identifier): \(package.storeProduct.productIdentifier) (\(package.storeProduct.localizedPriceString))")
                        }
                    }
                    
                    // Validate products
                    if affirmationPackages.isEmpty {
                        self?.showError = true
                        self?.errorMessage = "No affirmation products available at the moment."
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func filterAffirmationPackages(from offerings: RevenueCat.Offerings) -> [RevenueCat.Package] {
        var affirmationPackages: [RevenueCat.Package] = []
        
        // Check all offerings for affirmation products
        for (_, offering) in offerings.all {
            for package in offering.availablePackages {
                let productId = package.storeProduct.productIdentifier
                if productId == "affirmation_pack_10" || productId == "affirmation_lifetime" {
                    affirmationPackages.append(package)
                }
            }
        }
        
        return affirmationPackages
    }
    
    func purchaseSelectedPackage() {
        guard let package = selectedPackage else {
            showError = true
            errorMessage = "Please select a package first"
            return
        }
        
        isLoading = true
        retryManager.reset()
        
        if Config.isDebugMode {
            print("🛒 Attempting to purchase: \(package.storeProduct.localizedTitle) (\(package.storeProduct.localizedPriceString))")
        }
        
        revenueCatService.purchaseProduct(package.storeProduct.productIdentifier)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        let purchaseError = AffirmationPurchaseErrorHandler.handleRevenueCatError(error)
                        self?.retryManager.handleError(purchaseError)
                        self?.showError = true
                        self?.errorMessage = purchaseError.errorDescription ?? "Purchase failed"
                        AffirmationPurchaseErrorHandler.logError(error, context: "AffirmationPurchase")
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.showSuccessAlert = true
                        self?.shouldReturnToAffirmations = true
                        
                        // Refresh subscription status immediately after successful purchase
                        Task {
                            await self?.refreshSubscriptionStatus()
                        }
                        
                        if Config.isDebugMode {
                            print("✅ Purchase successful for \(package.storeProduct.localizedTitle)")
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func purchasePlan(_ plan: AffirmationPlan) {
        // Legacy method - now uses purchaseSelectedPackage
        purchaseSelectedPackage()
    }
    
    func restorePurchases() {
        isLoading = true
        
        revenueCatService.restorePurchases()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.showError = true
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] customerInfo in
                    if !customerInfo.activeSubscriptions.isEmpty {
                        self?.showSuccessAlert = true
                        
                        // Refresh subscription status immediately after successful restore
                        Task {
                            await self?.refreshSubscriptionStatus()
                        }
                        
                        if Config.isDebugMode {
                            print("✅ Purchases restored successfully")
                        }
                    } else {
                        self?.showError = true
                        self?.errorMessage = "No active purchases found"
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func openTermsOfService() {
        
        if let url = URL(string: "https://ytemiloluwa.github.io/Term-of-use.html") {
            
            UIApplication.shared.open(url)
        }
        
        if Config.isDebugMode {
            print("📄 Opening terms of service")
        }
    }
    
    func openPrivacyPolicy() {
        
        if let url = URL(string: "https://ytemiloluwa.github.io/privacy-policy.html") {
            UIApplication.shared.open(url)
        }
        if Config.isDebugMode {
            print("🔒 Opening privacy policy")
        }
    }
    
    // MARK: - Helper Functions
    private func refreshSubscriptionStatus() async {
        // Force refresh subscription status to immediately unlock features
        if let subscriptionService = subscriptionService as? SubscriptionService {
            await subscriptionService.refreshSubscriptionStatus()
        }
    }
}

//// MARK: - Previews
//#Preview("Affirmation Purchase View - Default") {
//    AffirmationPurchaseView()
//        .environmentObject(ThemeManager())
//}
//
//#Preview("Affirmation Purchase View - Loading") {
//    let viewModel = AffirmationPurchaseViewModel()
//    viewModel.isLoading = true
//
//    return AffirmationPurchaseView()
//        .environmentObject(ThemeManager())
//        .onAppear {
//            // Simulate loading state
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                viewModel.isLoading = false
//            }
//        }
//}
//
//#Preview("Affirmation Purchase View - Error") {
//    let viewModel = AffirmationPurchaseViewModel()
//    viewModel.showError = true
//    viewModel.errorMessage = "Payment was declined. Please check your payment method."
//    viewModel.retryManager.canRetry = true
//    viewModel.retryManager.retryMessage = "Retry 1/3: Check your internet connection and try again."
//
//    return AffirmationPurchaseView()
//        .environmentObject(ThemeManager())
//}
//
//#Preview("Affirmation Purchase View - Success") {
//    let viewModel = AffirmationPurchaseViewModel()
//    viewModel.showSuccessAlert = true
//
//    return AffirmationPurchaseView()
//        .environmentObject(ThemeManager())
//}
//
//#Preview("Affirmation Plan View - Pack Selected") {
//    AffirmationPlanView(
//        plan: .pack,
//        isSelected: true,
//        isPopular: false
//    ) {
//        print("Pack selected")
//    }
//    .padding()
//}
//
//#Preview("Affirmation Plan View - Lifetime Popular") {
//    AffirmationPlanView(
//        plan: .lifetime,
//        isSelected: false,
//        isPopular: true
//    ) {
//        print("Lifetime selected")
//    }
//    .padding()
//}
//
//#Preview("Feature Row View") {
//    VStack(spacing: 16) {
//        FeatureRowView(
//            icon: "brain.head.profile",
//            title: "AI-Powered Personalization",
//            description: "Affirmations tailored to your emotional profile"
//        )
//
//        FeatureRowView(
//            icon: "waveform",
//            title: "Your Voice Speaking",
//            description: "Hear affirmations in your cloned voice"
//        )
//
//        FeatureRowView(
//            icon: "heart.text.square",
//            title: "15+ Categories",
//            description: "Confidence, gratitude, courage, and more"
//        )
//    }
//    .padding()
//}
//
//#Preview("All Plans Comparison") {
//    VStack(spacing: 16) {
//        Text("Affirmation Plans")
//            .font(.title2)
//            .fontWeight(.bold)
//
//        AffirmationPlanView(
//            plan: .pack,
//            isSelected: false,
//            isPopular: false
//        ) {
//            print("Pack selected")
//        }
//
//        AffirmationPlanView(
//            plan: .lifetime,
//            isSelected: true,
//            isPopular: true
//        ) {
//            print("Lifetime selected")
//        }
//    }
//    .padding()
//}
