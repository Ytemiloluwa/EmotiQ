//
//  AllAffirmationsView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 10-09-2025.
//

import Foundation
import SwiftUI
import CoreData
import AVFoundation

struct AllAffirmationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    // Core Data
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AffirmationEntity.createdAt, ascending: false)],
        animation: .default
    ) private var affirmations: FetchedResults<AffirmationEntity>
    
    // State
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var selectedCategory: AffirmationCategory?
    
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { mainContent }
            } else {
                NavigationView { mainContent }
                    .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if affirmations.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(groupedAffirmations.keys.sorted(by: { getDateFromGroupingString($0) > getDateFromGroupingString($1) }), id: \.self) { dateGroup in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(dateGroup)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(ThemeColors.primaryText)
                                    Spacer()
                                    Text("\(groupedAffirmations[dateGroup]?.count ?? 0) affirmations")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(ThemeColors.primaryText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, dateGroup == groupedAffirmations.keys.sorted(by: { getDateFromGroupingString($0) > getDateFromGroupingString($1) }).first ? 0 : 20)
                                
                                ForEach(groupedAffirmations[dateGroup] ?? [], id: \.objectID) { affirmation in
                                    AffirmationCard(affirmation: affirmation)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("All Affirmations")
        .padding(.bottom, 30)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            
            Task {
                
                await cleanupAudioSessionForPlayback()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredAffirmations: [AffirmationEntity] {
        var filtered = Array(affirmations)
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { affirmation in
                affirmation.text?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Filter by category
        if let selectedCategory = selectedCategory {
            filtered = filtered.filter { $0.category == selectedCategory.rawValue }
        }
        
        return filtered
    }
    
    private var groupedAffirmations: [String: [AffirmationEntity]] {
        let calendar = Calendar.current
        let now = Date()
        
        return Dictionary(grouping: filteredAffirmations) { affirmation in
            guard let createdAt = affirmation.createdAt else { return "Unknown" }
            
            if calendar.isDateInToday(createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(createdAt) {
                return "Yesterday"
            } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(createdAt) == true {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return formatter.string(from: createdAt)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                return formatter.string(from: createdAt)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDateFromGroupingString(_ dateString: String) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch dateString {
        case "Today":
            return now
        case "Yesterday":
            return calendar.date(byAdding: .day, value: -1, to: now) ?? now
        default:
            if let weekday = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].firstIndex(of: dateString) {
                let daysFromNow = weekday - calendar.component(.weekday, from: now) + 1
                return calendar.date(byAdding: .day, value: daysFromNow, to: now) ?? now
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                return formatter.date(from: dateString) ?? now
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 80))
                .foregroundColor(ThemeColors.accent.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Affirmations Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeColors.primaryText)
                
                Text("Start your journey by generating your first affirmation in the coaching section.")
                    .font(.body)
                    .foregroundColor(ThemeColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                dismiss()
            }) {
                Text("Go to Coaching")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ThemeColors.accent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.primaryBackground)
    }
}

// MARK: - Affirmation Card
struct AffirmationCard: View {
    let affirmation: AffirmationEntity
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var audioPlayer = CachedAudioPlayer()
    @State private var isPlaying = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let categoryString = affirmation.category,
               let category = AffirmationCategory(rawValue: categoryString) {
                HStack {
                    // Category Icon
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundColor(getCategoryColor(category))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(getCategoryColor(category).opacity(0.2))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ThemeColors.secondaryText)
                        
                        if let targetEmotionString = affirmation.targetEmotion,
                           let targetEmotion = EmotionType(rawValue: targetEmotionString) {
                            Text(targetEmotion.displayName)
                                .font(.caption2)
                                .foregroundColor(ThemeColors.secondaryText.opacity(0.7))
                        }
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
                    .disabled(!ElevenLabsService.shared.isVoiceCloned)
                    
                    if let createdAt = affirmation.createdAt {
                        Text(createdAt, style: .time)
                            .font(.caption)
                            .foregroundColor(ThemeColors.secondaryText)
                    }
                }
            }
            
            if let text = affirmation.text {
                Text(text)
                    .font(.body)
                    .foregroundColor(ThemeColors.primaryText)
                    .lineLimit(nil)
            }
        }
        .padding()
        .background(ThemeColors.secondaryBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onReceive(audioPlayer.$isPlaying) { playing in
            isPlaying = playing
        }
    }
    
    private func playAffirmation() async {
        guard let text = affirmation.text,
              let targetEmotionString = affirmation.targetEmotion,
              let targetEmotion = EmotionType(rawValue: targetEmotionString) else {
            return
        }
        
        do {
            try await audioPlayer.playAudio(
                text: text,
                emotion: targetEmotion
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

// MARK: - Audio Session Cleanup
private func cleanupAudioSessionForPlayback() async {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
        try audioSession.setActive(true)
        
    } catch {
       
    }
}


#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Add sample data
    let sampleAffirmation = AffirmationEntity(context: context)
    sampleAffirmation.text = "I am confident and capable of achieving my goals."
    sampleAffirmation.category = "confidence"
    sampleAffirmation.createdAt = Date()
    sampleAffirmation.isCustom = false
    
    return AllAffirmationsView()
        .environment(\.managedObjectContext, context)
        .environmentObject(ThemeManager())
}
