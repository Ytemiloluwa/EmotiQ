//
//  AffirmationDetailView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 19-08-2025.
//

import Foundation
import SwiftUI

struct AffirmationDetailView: View {
    let affirmation: PersonalizedAffirmation
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var audioPlayer = CachedAudioPlayer()
    @StateObject private var affirmationEngine = AffirmationEngine.shared
    
    @State private var isPlaying = false
    @State private var showingEffectivenessRating = false
    @State private var effectivenessRating = 0
    @State private var isCompleting = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Affirmation Content
                affirmationContentSection
                
                // Audio Player
                audioPlayerSection
                
//                // Category and Emotion Info
//                metadataSection
//
//                // Effectiveness Section
//                if affirmation.isCompleted {
//                    completedSection
//                } else {
//                    actionSection
//                }
//
//                // Related Affirmations
//                relatedAffirmationsSection
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
        .navigationTitle("Affirmation")
        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Menu {
//                    Button {
//                        shareAffirmation()
//                    } label: {
//                        Label("Share", systemImage: "square.and.arrow.up")
//                    }
//
//                    Button {
//                        favoriteAffirmation()
//                    } label: {
//                        Label("Add to Favorites", systemImage: "heart")
//                    }
//
//                    Button {
//                        reportAffirmation()
//                    } label: {
//                        Label("Report Issue", systemImage: "exclamationmark.triangle")
//                    }
//                } label: {
//                    Image(systemName: "ellipsis.circle")
//                        .foregroundColor(ThemeColors.accent)
//                }
//                .hapticFeedback(.standard)
//            }
//        }
        .sheet(isPresented: $showingEffectivenessRating) {
            EffectivenessRatingView(
                affirmation: affirmation,
                rating: $effectivenessRating,
                onComplete: completeAffirmation
            )
        }
        .onReceive(audioPlayer.$isPlaying) { playing in
            isPlaying = playing
        }
        .task {
            await loadAffirmationAudio()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Category Icon
            Image(systemName: affirmation.category.icon)
                .font(.system(size: 64))
                .foregroundColor(getCategoryColor(affirmation.category))
                .frame(width: 100, height: 100)
                .background(
                    Circle()
                        .fill(getCategoryColor(affirmation.category).opacity(0.2))
                        .shadow(color: getCategoryColor(affirmation.category).opacity(0.3), radius: 20, x: 0, y: 10)
                )
            
            VStack(spacing: 4) {
                Text(affirmation.category.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Text("Created \(formatDate(affirmation.createdAt))")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Affirmation Content Section
    
    private var affirmationContentSection: some View {
        VStack(spacing: 16) {
            Text(affirmation.text)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 16)
            
            // Visual emphasis
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            getCategoryColor(affirmation.category).opacity(0.6),
                            getCategoryColor(affirmation.category).opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .frame(maxWidth: 100)
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ThemeColors.secondaryBackground)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Audio Player Section
    
    private var audioPlayerSection: some View {
        VStack(spacing: 20) {
            // Waveform Visualization
            HStack(spacing: 2) {
                ForEach(0..<50, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            isPlaying
                            ? getCategoryColor(affirmation.category).opacity(Double.random(in: 0.3...1.0))
                            : ThemeColors.secondaryText.opacity(0.3)
                        )
                        .frame(width: 3, height: CGFloat.random(in: 8...32))
                        .animation(
                            isPlaying
                            ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(index) * 0.02)
                            : .easeInOut(duration: 0.3),
                            value: isPlaying
                        )
                }
            }
            .frame(height: 40)
            
            // Progress Bar
            VStack(spacing: 8) {
                HStack {
                    Text(formatTime(audioPlayer.currentTime))
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                    
                    Spacer()
                    
                    Text(formatTime(audioPlayer.duration))
                        .font(.caption)
                        .foregroundColor(ThemeColors.secondaryText)
                }
                
                ProgressView(value: audioPlayer.currentTime, total: audioPlayer.duration)
                    .tint(getCategoryColor(affirmation.category))
                    .scaleEffect(y: 2)

            }
            
            // Playback Controls
            HStack(spacing: 32) {
                // Speed Control
                Button {
                    let newRate: Float = audioPlayer.playbackRate == 1.0 ? 0.8 : (audioPlayer.playbackRate == 0.8 ? 1.2 : 1.0)
                    audioPlayer.setPlaybackRate(newRate)
                } label: {
                    Text(String(format: "%.1fx", audioPlayer.playbackRate))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeColors.accent)
                        .frame(width: 40, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ThemeColors.accent.opacity(0.1))
                        )
                }
                .hapticFeedback(.standard)
                
                // Rewind
                Button {
                    let newTime = max(0, audioPlayer.currentTime - 10)
                    audioPlayer.seek(to: newTime)
                } label: {
                    Image(systemName: "gobackward")
                        .font(.title2)
                        .foregroundColor(ThemeColors.primaryText)
                }
                .hapticFeedback(.standard)
                
                // Play/Pause
                Button {
                    if isPlaying {
                        audioPlayer.pause()
                    } else {
                        Task {
                            await playAffirmation()
                        }
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(getCategoryColor(affirmation.category))
                        .shadow(color: getCategoryColor(affirmation.category).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .hapticFeedback(.primary)
                .scaleEffect(isPlaying ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
                
                // Forward
                Button {
                    let newTime = min(audioPlayer.duration, audioPlayer.currentTime + 10)
                    audioPlayer.seek(to: newTime)
                } label: {
                    Image(systemName: "goforward")
                        .font(.title2)
                        .foregroundColor(ThemeColors.primaryText)
                }
                .hapticFeedback(.standard)
                
                // Loop
                Button {
                    audioPlayer.toggleLoop()
                } label: {
                    Image(systemName: audioPlayer.isLooping ? "repeat.1" : "repeat")
                        .font(.title3)
                        .foregroundColor(audioPlayer.isLooping ? getCategoryColor(affirmation.category) : ThemeColors.secondaryText)
                }
                .hapticFeedback(.standard)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ThemeColors.secondaryBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        HStack(spacing: 16) {
            // Category Info
            VStack(spacing: 8) {
                Image(systemName: affirmation.category.icon)
                    .font(.title2)
                    .foregroundColor(getCategoryColor(affirmation.category))
                
                Text("Category")
                    .font(.caption2)
                    .foregroundColor(ThemeColors.secondaryText)
                
                Text(affirmation.category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(getCategoryColor(affirmation.category).opacity(0.1))
            )
            
            // Emotion Info
            VStack(spacing: 8) {
                Text(affirmation.targetEmotion.emoji)
                    .font(.title2)
                
                Text("Voice Tone")
                    .font(.caption2)
                    .foregroundColor(ThemeColors.secondaryText)
                
                Text(affirmation.targetEmotion.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
                            .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ThemeColors.secondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ThemeColors.accent.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Completed Section
    
    private var completedSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Completed")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Spacer()
            }
            
            if let effectiveness = affirmation.effectiveness {
                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Rating")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                    
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= effectiveness ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        Text(getEffectivenessDescription(effectiveness))
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Action Section
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            Button {
                showingEffectivenessRating = true
                HapticManager.shared.buttonPress(.primary)
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Mark as Completed")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            getCategoryColor(affirmation.category),
                            getCategoryColor(affirmation.category).opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isCompleting)
            
                            Text("Rate how effective this affirmation was for you")
                    .font(.caption)
                    .foregroundColor(ThemeColors.secondaryText)
                    .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Related Affirmations Section
    
    private var relatedAffirmationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("More \(affirmation.category.displayName) Affirmations")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeColors.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        RelatedAffirmationCard(
                            title: "I am confident in my abilities",
                            category: affirmation.category,
                            onTap: {
                                // Navigate to related affirmation
                                HapticManager.shared.navigationTransition()
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
    
    // MARK: - Actions
    
    private func loadAffirmationAudio() async {
        // Audio would be loaded automatically when playing
    }
    
    private func playAffirmation() async {
        do {
            try await audioPlayer.playAudio(
                text: affirmation.text,
                emotion: affirmation.targetEmotion
            )
        } catch {
        
            HapticManager.shared.notification(.error)
        }
    }
    
    private func completeAffirmation() {
        isCompleting = true
        
        Task {
            await affirmationEngine.completeAffirmation(affirmation, effectiveness: effectivenessRating)
            isCompleting = false
            showingEffectivenessRating = false
            
            // Celebration haptic
            HapticManager.shared.celebration(.goalCompleted)
        }
    }
    
    private func shareAffirmation() {
        // Share functionality
        HapticManager.shared.buttonPress(.standard)
    }
    
    private func favoriteAffirmation() {
        // Add to favorites
        HapticManager.shared.buttonPress(.standard)
    }
    
    private func reportAffirmation() {
        // Report issue
        HapticManager.shared.buttonPress(.standard)
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy, HH:mm"
        return formatter.string(from: date)
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
    
    private func getEffectivenessDescription(_ rating: Int) -> String {
        switch rating {
        case 1: return "Not helpful"
        case 2: return "Slightly helpful"
        case 3: return "Moderately helpful"
        case 4: return "Very helpful"
        case 5: return "Extremely helpful"
        default: return ""
        }
    }
}

// MARK: - Related Affirmation Card

struct RelatedAffirmationCard: View {
    let title: String
    let category: AffirmationCategory
    let onTap: () -> Void
    
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(getCategoryColor(category))
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeColors.primaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(width: 140, height: 80, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeColors.primaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(getCategoryColor(category).opacity(0.3), lineWidth: 1)
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

// MARK: - Effectiveness Rating View

struct EffectivenessRatingView: View {
    let affirmation: PersonalizedAffirmation
    @Binding var rating: Int
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(ThemeColors.accent)
                    
                    Text("How effective was this affirmation?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ThemeColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("Your feedback helps us personalize future affirmations")
                        .font(.subheadline)
                        .foregroundColor(ThemeColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 24) {
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                                HapticManager.shared.selection()
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 40))
                                    .foregroundColor(star <= rating ? .yellow : ThemeColors.secondaryText.opacity(0.3))
                            }
                            .scaleEffect(star <= rating ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rating)
                        }
                    }
                    
                    if rating > 0 {
                        Text(getEffectivenessDescription(rating))
                            .font(.headline)
                            .foregroundColor(ThemeColors.primaryText)
                            .animation(.easeInOut, value: rating)
                    }
                }
                
                Spacer()
                
                Button {
                    onComplete()
                    HapticManager.shared.celebration(.goalCompleted)
                } label: {
                    Text("Complete")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [
                                    ThemeColors.accent,
                                    ThemeColors.accent.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .opacity(rating > 0 ? 1.0 : 0.6)
                }
                .disabled(rating == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .navigationTitle("Rate Effectiveness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ThemeColors.secondaryText)
                }
            }
        }
    }
    
    private func getEffectivenessDescription(_ rating: Int) -> String {
        switch rating {
        case 1: return "Not helpful"
        case 2: return "Slightly helpful"
        case 3: return "Moderately helpful"
        case 4: return "Very helpful"
        case 5: return "Extremely helpful"
        default: return ""
        }
    }
}

#Preview {
    AffirmationDetailView(
        affirmation: PersonalizedAffirmation(
            id: UUID(),
            text: "I am worthy of love and happiness in all areas of my life.",
            category: .confidence,
            targetEmotion: .joy,
            audioURL: nil,
            createdAt: Date(),
            isCompleted: false,
            effectiveness: nil
        )
    )
}

