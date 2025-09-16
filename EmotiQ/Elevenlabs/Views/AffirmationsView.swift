//
//  AffirmationsView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 19-08-2025.
//

import Foundation
import SwiftUI
import CoreHaptics
import AVFoundation

struct AffirmationsView: View {
    @StateObject private var affirmationEngine = AffirmationEngine.shared
    @StateObject private var themeManager = ThemeManager()
    
    @State private var selectedCategory: AffirmationCategory? = nil
    @State private var showingCustomAffirmationCreator = false
    @State private var showingAffirmationDetail = false
    @State private var selectedAffirmation: PersonalizedAffirmation?
    @State private var isGeneratingDaily = false
    @State private var showingEffectivenessRating = false
    @State private var affirmationToComplete: PersonalizedAffirmation?
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @StateObject private var purchaseManager = AffirmationPurchaseFlowManager.shared
    @StateObject private var securePurchaseManager = SecurePurchaseManager.shared
    @StateObject private var audioPlayer = CachedAudioPlayer()
    
    // UI State for async data
    @State private var remainingGenerations: Int = 0
    @State private var canGenerate: Bool = true
    @State private var needsPurchase: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Daily Affirmations
                    dailyAffirmationsSection
                    
                    // Categories
                    categoriesSection
                    
                    // Recent Activity
                    recentActivitySection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(
                LinearGradient(
                    colors: [
                        ThemeColors.primaryBackground,
                        ThemeColors.primaryBackground.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Affirmations")
            .navigationBarTitleDisplayMode(.large)
            //            .toolbar {
            //                ToolbarItem(placement: .navigationBarTrailing) {
            //                    Button {
            //                        showingCustomAffirmationCreator = true
            //                        HapticManager.shared.buttonPress(.primary)
            //                    } label: {
            //                        Image(systemName: "plus.circle.fill")
            //                            .font(.title2)
            //                            .foregroundColor(ThemeColors.primaryText)
            //                    }
            //                }
            //            }
            .navigationDestination(isPresented: $showingCustomAffirmationCreator) {
                CustomAffirmationCreatorView()
            }
            .sheet(isPresented: $purchaseManager.showingPurchaseView) {
                AffirmationPurchaseView(shouldDismiss: $purchaseManager.showingPurchaseView)
            }
            .navigationDestination(isPresented: $showingAffirmationDetail) {
                if let affirmation = selectedAffirmation {
                    AffirmationDetailView(affirmation: affirmation)
                }
            }
        }
        
        .onChange(of: purchaseManager.purchaseCompleted) { oldValue, newValue in
            if newValue {
                // Reset usage after successful purchase
                Task {
                    await securePurchaseManager.resetUsage()
                }
                HapticManager.shared.notification(.success)
            }
        }
        .onChange(of: purchaseManager.showingPurchaseView) { oldValue, newValue in
            if !newValue && purchaseManager.purchaseCompleted {
                // User returned from successful purchase
                Task {
                    await securePurchaseManager.resetUsage()
                }
                purchaseManager.resetPurchaseStatus()
            }
        }
        .onAppear {
            // Set purchase origin for navigation tracking
            securePurchaseManager.setPurchaseOrigin(.affirmationsView)
            // Load initial state
            Task {
                await loadUIState()
                
                await cleanupAudioSessionForPlayback()
            }
        }
        .onChange(of: securePurchaseManager.affirmationsViewUsage) { _, _ in
            Task {
                await loadUIState()
            }
        }
        .onChange(of: securePurchaseManager.sharedPackUsage) { _, _ in
            Task {
                await loadUIState()
            }
        }
        .onChange(of: securePurchaseManager.hasLifetimeAccess) { _, _ in
            Task {
                await loadUIState()
            }
        }
        .onChange(of: securePurchaseManager.hasPackAccess) { _, _ in
            Task {
                await loadUIState()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUIState() async {
    
        
        remainingGenerations = await securePurchaseManager.getRemainingUses(for: .affirmationsView)
        canGenerate = await securePurchaseManager.canGenerateAffirmations(from: .affirmationsView)
        needsPurchase = await securePurchaseManager.needsToPurchase(from: .affirmationsView)
        
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Voice, Your Power")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Personalized affirmations in your own voice")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                Spacer()
                
                Button {
                    Task {
                        let needsPurchase = await securePurchaseManager.needsToPurchase(from: .affirmationsView)
                        if needsPurchase {
                            purchaseManager.startPurchase()
                        } else {
                            await generateDailyAffirmations()
                        }
                    }
                } label: {
                    if shouldShowBuyButton {
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("Buy")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [ThemeColors.primaryPurple, ThemeColors.primaryCyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: ThemeColors.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(ThemeColors.accent)
                            .rotationEffect(.degrees(isGeneratingDaily ? 360 : 0))
                            .animation(Animation.repeatWhile(isGeneratingDaily), value: isGeneratingDaily)
                    }
                }
                .disabled(isGeneratingDaily || (!needsPurchase && !canGenerate))
                .hapticFeedback(.primary)
            }
            
            // Generation Status
            if isGeneratingDaily {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Generating personalized affirmations...")
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ThemeColors.secondaryBackground.opacity(0.5))
                )
            } else if !needsPurchase && remainingGenerations > 0 {
                // Show remaining generations (but not for lifetime users)
                if remainingGenerations != -1 {  // -1 means lifetime access
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(ThemeColors.accent)
                        
                        Text("\(remainingGenerations) generations remaining")
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeColors.accent.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - Daily Affirmations Section
    
    private var dailyAffirmationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Affirmations")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                if let lastGeneration = affirmationEngine.lastGenerationDate {
                    Text(lastGeneration, style: .relative)
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
            }
            
            if affirmationEngine.dailyAffirmations.isEmpty {
                emptyDailyAffirmationsView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(affirmationEngine.dailyAffirmations) { affirmation in
                        DailyAffirmationCard(
                            affirmation: affirmation,
                            onTap: {
                                selectedAffirmation = affirmation
                                showingAffirmationDetail = true
                                HapticManager.shared.navigationTransition()
                                
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var emptyDailyAffirmationsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(ThemeColors.accent.opacity(0.6))
            
            Text("No affirmations yet today")
                .font(.headline)
                .foregroundColor(ThemeColors.primaryText)
            
            Text("Tap the refresh button to generate personalized affirmations based on your recent emotional patterns.")
                .font(.subheadline)
                .foregroundColor(ThemeColors.secondaryText)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await generateDailyAffirmations()
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Affirmations")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [ThemeColors.accent, ThemeColors.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isGeneratingDaily)
            .hapticFeedback(.primary)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ThemeColors.secondaryBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Affirmation Categories")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Spacer()
                
                // Generate button for selected category
                if let selectedCategory = selectedCategory {
                    Button {
                        Task {
                            let needsPurchase = await securePurchaseManager.needsToPurchase(from: .affirmationsView)
                            if needsPurchase {
                                purchaseManager.startPurchase()
                            } else {
                                await generateAffirmationsForCategory(selectedCategory)
                            }
                        }
                    } label: {
                        HStack {
                            if isGeneratingDaily {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: needsPurchase ? purchaseManager.currentPurchaseStatus.icon : "sparkles")
                            }
                            Text(isGeneratingDaily ? "Generating..." : (needsPurchase ? purchaseManager.currentPurchaseStatus.displayText : "Generate"))
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: needsPurchase
                                ? [purchaseManager.currentPurchaseStatus.backgroundColor, purchaseManager.currentPurchaseStatus.backgroundColor.opacity(0.8)]
                                : [ThemeColors.accent, ThemeColors.accent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isGeneratingDaily || (needsPurchase && !purchaseManager.currentPurchaseStatus.isEnabled))
                    .hapticFeedback(.primary)
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(affirmationEngine.affirmationCategories, id: \.self) { category in
                    CategoryCard(
                        category: category,
                        isSelected: selectedCategory == category,
                        onTap: {
                            selectedCategory = category
                            HapticManager.shared.selection()
                        }
                    )
                }
            }
            
            // Show selected category info
            if let selectedCategory = selectedCategory {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected: \(selectedCategory.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.accent)
                    
                    if needsPurchase {
                        Text("Free generations used. Purchase more to continue.")
                            .font(.caption)
                            .foregroundColor(.purple)
                    } else if remainingGenerations == -1 {
                        Text("Unlimited generations (Lifetime access)")
                            .font(.caption)
                            .foregroundColor(ThemeColors.accent)
                    } else {
                        Text("\(remainingGenerations) free generations remaining")
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeColors.accent.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            // Show recently completed affirmations
            let completedAffirmations = affirmationEngine.dailyAffirmations.filter { $0.isCompleted }
            if !completedAffirmations.isEmpty {
                VStack(spacing: 12) {
                    ForEach(completedAffirmations.prefix(3), id: \.id) { affirmation in
                        AffirmationRecentActivityRow(
                            title: affirmation.text,
                            subtitle: "Completed \(affirmation.createdAt)",
                            effectiveness: affirmation.effectiveness ?? 3,
                            category: affirmation.category
                        )
                    }
                }
                
            } else {
                // Show empty state when no completed affirmations
                VStack(spacing: 16) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 48))
                        .foregroundColor(ThemeColors.secondaryText.opacity(0.6))
                    
                    Text("No completed affirmations yet")
                        .font(.headline)
                        .foregroundColor(ThemeColors.primaryText)
                    
                    Text("Complete your first affirmation to see your progress here")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ThemeColors.secondaryBackground.opacity(0.5))
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateDailyAffirmations() async {
        isGeneratingDaily = true
        defer { isGeneratingDaily = false }
        
        do {
            try await affirmationEngine.generateDailyAffirmations()
            
            // Increment usage securely
            await securePurchaseManager.incrementUsage(for: .affirmationsView)
            HapticManager.shared.notification(.success)
        } catch {
         
            HapticManager.shared.notification(.error)
        }
    }
    
    private func generateAffirmationsForCategory(_ category: AffirmationCategory) async {
        isGeneratingDaily = true
        defer { isGeneratingDaily = false }
        
        do {
            try await affirmationEngine.generateAffirmations(for: category)
            HapticManager.shared.notification(.success)
            
            // Increment usage securely
            await securePurchaseManager.incrementUsage(for: .affirmationsView)
        } catch {

            HapticManager.shared.notification(.error)
        }
    }
    
    // MARK: - Computed Properties
    
    private var shouldShowBuyButton: Bool {
        // Use the async state that's already loaded
        return needsPurchase
    }
    
    private var canGenerateDaily: Bool {
        // Use the async state that's already loaded
        return canGenerate
    }
    
    
    // MARK: - Daily Affirmation Card
    
    struct DailyAffirmationCard: View {
        let affirmation: PersonalizedAffirmation
        let onTap: () -> Void
        // let onComplete: (PersonalizedAffirmation) -> Void
        // let audioPlayer: CachedAudioPlayer
        
        @StateObject private var themeManager = ThemeManager()
        @StateObject private var audioPlayer = CachedAudioPlayer()
        @State private var isPlaying = false
        
        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Category Icon
                        Image(systemName: affirmation.category.icon)
                            .font(.title2)
                            .foregroundColor(getCategoryColor(affirmation.category))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(getCategoryColor(affirmation.category).opacity(0.2))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(affirmation.category.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(ThemeColors.secondaryText)
                            
                            Text(affirmation.targetEmotion.displayName)
                                .font(.caption2)
                                .foregroundColor(ThemeColors.secondaryText.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Play Button
                        Button {
                            Task {
                                await playAffirmation()
                            }
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title)
                                .foregroundColor(ThemeColors.accent)
                        }
                        .hapticFeedback(.primary)
                        .disabled(!ElevenLabsService.shared.isVoiceCloned)
                    }
                    
                    // Affirmation Text
                    Text(affirmation.text)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ThemeColors.secondaryBackground)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onReceive(audioPlayer.$isPlaying) { playing in
                isPlaying = playing
            }
        }
        
        private func playAffirmation() async {
            do {
                try await audioPlayer.playAudio(
                    text: affirmation.text,
                    emotion: affirmation.targetEmotion
                )
            } catch {
             
            }
        }
        
        private func getCategoryColor(_ category: AffirmationCategory) -> Color {
            switch category {
            case .confidence: return .yellow
            case .selfCompassion: return .pink
            case .gratitude: return .green
            case .courage: return .red
            case .calmness: return .blue
            case .hope: return .orange
            case .motivation: return .purple
            case .abundance: return .mint
            case .forgiveness: return .teal
            case .acceptance: return .indigo
            case .growth: return .green
            case .curiosity: return .cyan
            case .relaxation: return .purple
            case .stability: return .brown
            case .grounding: return .brown
            case .balance: return .gray
            case .safety: return .blue
            }
                 }
     }
 }

 // MARK: - Category Card

 struct CategoryCard: View {
            let category: AffirmationCategory
            let isSelected: Bool
            let onTap: () -> Void
            
            @StateObject private var themeManager = ThemeManager()
            
            var body: some View {
                Button(action: onTap) {
                    VStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .font(.title2)
                            .foregroundColor(isSelected ? .white : getCategoryColor(category))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(isSelected ? getCategoryColor(category) : getCategoryColor(category).opacity(0.2))
                            )
                        
                        Text(category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? getCategoryColor(category) : ThemeColors.primaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? getCategoryColor(category).opacity(0.1) : ThemeColors.secondaryBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? getCategoryColor(category) : Color.clear, lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .hapticFeedback(.standard)
            }
            
            private func getCategoryColor(_ category: AffirmationCategory) -> Color {
                switch category {
                case .confidence: return .yellow
                case .selfCompassion: return .pink
                case .gratitude: return .green
                case .courage: return .red
                case .calmness: return .blue
                case .hope: return .orange
                case .motivation: return .purple
                case .abundance: return .mint
                case .forgiveness: return .teal
                case .acceptance: return .indigo
                case .growth: return .green
                case .curiosity: return .cyan
                case .relaxation: return .purple
                case .stability: return .brown
                case .grounding: return .brown
                case .balance: return .gray
                case .safety: return .blue
                }
            }
     }

 // MARK: - Recent Activity Row

 struct AffirmationRecentActivityRow: View {
            let title: String
            let subtitle: String
            let effectiveness: Int
            let category: AffirmationCategory
            
            @StateObject private var themeManager = ThemeManager()
            
            init(title: String, subtitle: String, effectiveness: Int, category: AffirmationCategory) {
                self.title = title
                self.subtitle = subtitle
                self.effectiveness = effectiveness
                self.category = category
            }
            
            var body: some View {
                HStack {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(getCategoryColor(category))
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeColors.primaryText)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= effectiveness ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeColors.secondaryBackground.opacity(0.5))
                )
            }
            
            func getCategoryColor(_ category: AffirmationCategory) -> Color {
                switch category {
                case .confidence: return .yellow
                case .selfCompassion: return .pink
                case .gratitude: return .green
                case .courage: return .red
                case .calmness: return .blue
                case .hope: return .orange
                case .motivation: return .purple
                case .abundance: return .mint
                case .forgiveness: return .teal
                case .acceptance: return .indigo
                case .growth: return .green
                case .curiosity: return .cyan
                case .relaxation: return .purple
                case .stability: return .brown
                case .grounding: return .brown
                case .balance: return .gray
                case .safety: return .blue
                }
            }
     }

// MARK: - Animation Extension

extension Animation {
    static func repeatWhile<T: Equatable>(_ condition: T) -> Animation {
        return condition as? Bool == true ? .linear(duration: 1).repeatForever(autoreverses: false) : .default
    }
}
// MARK: - Previews
#Preview("Affirmations View - Default") {
    NavigationStack {
        AffirmationsView()
            .environmentObject(SubscriptionService.shared)
            .environmentObject(ThemeManager())
    }
}

#Preview("Affirmations View - Premium User") {
    let subscriptionService = SubscriptionService.shared
    
    return NavigationStack {
        AffirmationsView()
            .environmentObject(subscriptionService)
            .environmentObject(ThemeManager())
            .onAppear {
                // Simulate premium user
                // Note: This is for preview only - actual subscription status would come from RevenueCat
            }
    }
}

#Preview("Affirmations View - Purchase Flow") {
    let purchaseManager = AffirmationPurchaseFlowManager()
    purchaseManager.currentPurchaseStatus = .idle
    
    return NavigationStack {
        VStack(spacing: 20) {
            Text("Purchase Flow Test")
                .font(.headline)
            
            // Test different purchase button states
            Group {
                Text("Idle State:")
                AffirmationPurchaseButton(purchaseManager: purchaseManager) {
                 
                }
                .environmentObject(SubscriptionService.shared)
                
                Text("Purchasing State:")
                AffirmationPurchaseButton(
                    purchaseManager: {
                        let manager = AffirmationPurchaseFlowManager()
                        manager.currentPurchaseStatus = .purchasing
                        return manager
                    }()
                ) {
                
                }
                .environmentObject(SubscriptionService.shared)
                
                Text("Completed State:")
                AffirmationPurchaseButton(
                    purchaseManager: {
                        let manager = AffirmationPurchaseFlowManager()
                        manager.currentPurchaseStatus = .completed
                        return manager
                    }()
                ) {
                  
                }
                .environmentObject(SubscriptionService.shared)
                
                Text("Failed State:")
                AffirmationPurchaseButton(
                    purchaseManager: {
                        let manager = AffirmationPurchaseFlowManager()
                        manager.currentPurchaseStatus = .failed("Network error")
                        return manager
                    }()
                ) {
                    
                }
                .environmentObject(SubscriptionService.shared)
            }
        }
        .padding()
        .environmentObject(SubscriptionService.shared)
    }
}

// MARK: - Audio Session Cleanup
private func cleanupAudioSessionForPlayback() async {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
        try audioSession.setActive(true)
        
    } catch {

    }
}

