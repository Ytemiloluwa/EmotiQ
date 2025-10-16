//
//  CustomAffirmationCreatorView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 19-08-2025.
//


import Foundation
import SwiftUI


struct CustomAffirmationCreatorView: View {
    
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var affirmationEngine = AffirmationEngine.shared
    @StateObject private var audioPlayer = CachedAudioPlayer()
    @StateObject private var securePurchaseManager = SecurePurchaseManager.shared
    @StateObject private var purchaseManager = AffirmationPurchaseFlowManager.shared
    
    @State private var affirmationText = ""
    @State private var selectedCategory: AffirmationCategory = .confidence
    @State private var selectedEmotion: EmotionType = .joy
    @State private var isGenerating = false
    @State private var generatedAffirmation: PersonalizedAffirmation?
    @State private var showingPreview = false
    @State private var isPlaying = false
    @State private var isSaving = false
    @State private var showSaveToast = false
    @State private var navigateToAffirmations = false
    
    // UI State for async data
    @State private var remainingGenerations: Int = 0
    @State private var canGenerateAffirmation: Bool = true
    @State private var needsPurchase: Bool = false
    
    private let maxCharacters = 200
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        
        ScrollView {
            
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Text Input
                textInputSection
                
                // Category Selection
                categorySelectionSection
                
                // Emotion Selection
                emotionSelectionSection
                
                // Preview Section
                if let affirmation = generatedAffirmation {
                    previewSection(affirmation)
                }
                
                // Generate Button
                generateButton
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
        .navigationTitle("Create Affirmation")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    HapticManager.shared.selection()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ThemeColors.accent)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if generatedAffirmation != nil {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task {
                            await saveAffirmation()
                        }
                    }
                    .foregroundColor(ThemeColors.accent)
                    .fontWeight(.semibold)
                    .hapticFeedback(.primary)
                    .disabled(isSaving)
                }
            }
        }
        .sheet(isPresented: $purchaseManager.showingPurchaseView) {
            AffirmationPurchaseView(shouldDismiss: $purchaseManager.showingPurchaseView)
        }
        .navigationDestination(isPresented: $navigateToAffirmations) {
            AllAffirmationsView()
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
            securePurchaseManager.setPurchaseOrigin(.customAffirmationCreator)
            // Load initial state
            Task {
                await loadUIState()
            }
        }
        .onChange(of: securePurchaseManager.customAffirmationUsage) { _, _ in
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 48))
                .foregroundColor(ThemeColors.accent)
            
            Text("Create Your Personal Affirmation")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Write a positive statement about yourself and we'll generate it in your own voice")
                .font(.subheadline)
                .foregroundColor(ThemeColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Text Input Section
    
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Affirmation")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(alignment: .trailing, spacing: 8) {
                TextEditor(text: $affirmationText)
                    .font(.body)
                    .foregroundColor(ThemeColors.primaryText)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeColors.secondaryBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ThemeColors.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .frame(minHeight: 100)
                    .onChange(of: affirmationText) { _, newValue in
                        if newValue.count > maxCharacters {
                            affirmationText = String(newValue.prefix(maxCharacters))
                            HapticManager.shared.notification(.warning)
                        }
                    }
                
                Text("\(affirmationText.count)/\(maxCharacters)")
                    .font(.caption)
                    .foregroundColor(
                        affirmationText.count > maxCharacters * 9 / 10
                        ? .orange
                        : ThemeColors.secondaryText
                    )
            }
            
            // Suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 Tips for effective affirmations:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Use \"I am\" or \"I\" statements")
                    Text("• Keep it positive and present tense")
                    Text("• Make it personal and believable")
                    Text("• Focus on what you want, not what you don't want")
                }
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ThemeColors.accent.opacity(0.1))
            )
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside the TextEditor
            hideKeyboard()
        }
    }
    
    // MARK: - Category Selection Section
    
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryPurple)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(AffirmationCategory.allCases.prefix(9), id: \.self) { category in
                    CategorySelectionCard(
                        category: category,
                        isSelected: selectedCategory == category,
                        onTap: {
                            selectedCategory = category
                            HapticManager.shared.selection()
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Emotion Selection Section
    
    private var emotionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Tone")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            Text("Choose the emotional tone for your voice")
                .font(.caption)
                .foregroundColor(ThemeColors.secondaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach([EmotionType.joy, .neutral, .surprise], id: \.self) { emotion in
                    EmotionSelectionCard(
                        emotion: emotion,
                        isSelected: selectedEmotion == emotion,
                        onTap: {
                            selectedEmotion = emotion
                            HapticManager.shared.selection()
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Preview Section
    
    private func previewSection(_ affirmation: PersonalizedAffirmation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            VStack(spacing: 16) {
                // Affirmation Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
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
                            
                            Text(affirmation.targetEmotion.displayName + " tone")
                                .font(.caption2)
                                .foregroundColor(ThemeColors.secondaryText.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Play Button
                        Button {
                            Task {
                                await playPreview(affirmation)
                            }
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(ThemeColors.accent)
                        }
                        .hapticFeedback(.primary)
                    }
                    
                    Text(affirmation.text)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ThemeColors.secondaryBackground)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                
                // Audio Player Controls
                if isPlaying || audioPlayer.duration > 0 {
                    AudioPlayerControls(audioPlayer: audioPlayer)
                }
            }
        }
        .onReceive(audioPlayer.$isPlaying) { playing in
            isPlaying = playing
        }
        .overlay(
            Group {
                if showSaveToast {
                    ToastView(message: "Affirmation saved successfully! 🎉")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        )
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    if needsPurchase {
                        purchaseManager.startPurchase()
                    } else {
                        await generateAffirmation()
                    }
                }
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: needsPurchase ? "cart.fill" : "waveform.and.mic")
                    }
                    
                    Text(buttonText)
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            ThemeColors.primaryPurple,
                            ThemeColors.primaryCyan
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(canGenerateAffirmation ? 1.0 : 0.6)
            }
            .disabled((!canGenerateAffirmation && !needsPurchase) || isGenerating)
            .hapticFeedback(.primary)
            
//            // Usage status text
//            if !needsPurchase {
//                Text("\(remainingGenerations) generations remaining")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
            
            if !canGenerate && !needsPurchase {
                Text("Please enter your affirmation text")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUIState() async {
       
        
        remainingGenerations = await securePurchaseManager.getRemainingUses(for: .customAffirmationCreator)
        canGenerateAffirmation = await securePurchaseManager.canGenerateAffirmations(from: .customAffirmationCreator)
        needsPurchase = await securePurchaseManager.needsToPurchase(from: .customAffirmationCreator)
        
    }
    
    // MARK: - Computed Properties
    
    private var canGenerate: Bool {
        !affirmationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var buttonText: String {
        if isGenerating {
            return "Generating..."
        } else if needsPurchase {
            return "Buy More"
        } else {
            return "Generate Voice Affirmation"
        }
    }
    
    // MARK: - Actions
    
    private func generateAffirmation() async {
        guard canGenerate else { return }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let affirmation = try await affirmationEngine.generateCustomAffirmation(
                text: affirmationText.trimmingCharacters(in: .whitespacesAndNewlines),
                category: selectedCategory,
                emotion: selectedEmotion
            )
            
            // Track usage after successful generation
            await securePurchaseManager.incrementUsage(for: .customAffirmationCreator)
            
            generatedAffirmation = affirmation
            HapticManager.shared.notification(.success)
            
        } catch {
            
            HapticManager.shared.notification(.error)
        }
    }
    
    private func playPreview(_ affirmation: PersonalizedAffirmation) async {
        do {
            try await audioPlayer.playAudio(
                text: affirmation.text,
                emotion: affirmation.targetEmotion
            )
        } catch {
           
            HapticManager.shared.notification(.error)
        }
    }
    
    private func saveAffirmation() async {
        guard let affirmation = generatedAffirmation else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            // The affirmation is already saved during generation, but we can add additional processing
            // such as marking as favorite, updating play count, etc.
            
            // Update the affirmation in the daily affirmations list
            if let index = affirmationEngine.dailyAffirmations.firstIndex(where: { $0.id == affirmation.id }) {
                affirmationEngine.dailyAffirmations[index] = affirmation
            } else {
                // Add to daily affirmations if not already present
                affirmationEngine.dailyAffirmations.append(affirmation)
            }
            
            // Provide user feedback
            HapticManager.shared.notification(.success)
            
            // Show success toast
            await MainActor.run {
                showSaveToast = true
            }
            
            // Auto-hide toast after 2.5 seconds and navigate to AffirmationsView
            try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
            await MainActor.run {
                showSaveToast = false
                // Navigate to AffirmationsView to show the newly saved affirmation
                navigateToAffirmations = true
            }
            
        } catch {
            
            HapticManager.shared.notification(.error)
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
// MARK: - Category Selection Card

struct CategorySelectionCard: View {
    let category: AffirmationCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : getCategoryColor(category))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? getCategoryColor(category) : getCategoryColor(category).opacity(0.2))
                    )
                
                Text(category.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? getCategoryColor(category) : ThemeColors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? getCategoryColor(category).opacity(0.1) : ThemeColors.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? getCategoryColor(category) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Emotion Selection Card

struct EmotionSelectionCard: View {
    let emotion: EmotionType
    let isSelected: Bool
    let onTap: () -> Void
    
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(emotion.emoji)
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? ThemeColors.accent.opacity(0.2) : Color.clear)
                    )
                
                Text(emotion.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? ThemeColors.accent : ThemeColors.primaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? ThemeColors.accent.opacity(0.1) : ThemeColors.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? ThemeColors.accent : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Audio Player Controls

struct AudioPlayerControls: View {
    let audioPlayer: CachedAudioPlayer
    
    @StateObject private var themeManager = ThemeManager()
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isPlaying: Bool = false
    @State private var playbackRate: Float = 1.0
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress Bar
            VStack(spacing: 4) {
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption2)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    Spacer()
                    
                    Text(formatTime(duration))
                        .font(.caption2)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                ProgressView(value: currentTime, total: max(duration, 0.1))
                    .tint(ThemeColors.accent)
            }
            
            // Playback Controls
            HStack(spacing: 24) {
                Button {
                    audioPlayer.setPlaybackRate(playbackRate == 1.0 ? 0.8 : 1.0)
                } label: {
                    Text(playbackRate == 1.0 ? "0.8x" : "1.0x")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ThemeColors.accent.opacity(0.1))
                        )
                }
                .hapticFeedback(.standard)
                
                Spacer()
                
                Button {
                    if isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.resume()
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(ThemeColors.accent)
                }
                .hapticFeedback(.primary)
                
                Spacer()
                
                Button {
                    audioPlayer.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                .hapticFeedback(.primary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ThemeColors.secondaryBackground.opacity(0.5))
        )
        .onReceive(audioPlayer.$currentTime) { newTime in
            currentTime = newTime.isFinite ? newTime : 0.0
        }
        .onReceive(audioPlayer.$duration) { newDuration in
            duration = newDuration.isFinite ? newDuration : 0.1
        }
        .onReceive(audioPlayer.$isPlaying) { newPlaying in
            isPlaying = newPlaying
        }
        .onReceive(audioPlayer.$playbackRate) { newRate in
            playbackRate = newRate
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let safeTime = time.isFinite ? time : 0.0
        let minutes = Int(safeTime) / 60
        let seconds = Int(safeTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColors.secondaryBackground)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 100) // Above the keyboard/safe area
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

#Preview {
    CustomAffirmationCreatorView()
}

