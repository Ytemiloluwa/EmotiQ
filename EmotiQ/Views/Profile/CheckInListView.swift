//
//  CheckInListView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 25-09-2025.
//

import Foundation
import SwiftUI
import CoreData

struct CheckInsListView: View {
    @State private var checkIns: [EmotionalDataEntity] = []
    private let persistenceController = PersistenceController.shared
    
    var body: some View {
        ZStack {
            ThemeColors.primaryBackground.ignoresSafeArea()
            if checkIns.isEmpty {
                EmptyCheckInsView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedDays, id: \.self) { day in
                            // Day header with count
                            HStack {
                                Text(day)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(groupedByDay[day]?.count ?? 0) check-ins")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                            
                            // Rows for this day
                            ForEach(groupedByDay[day] ?? [], id: \.objectID) { entity in
                                HStack(spacing: 12) {
                                if let category = emotionCategory(entity) {
                                    HStack(spacing: 8) {
                                        Text(category.emoji)
                                        Text(category.displayName)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                }
                                    Spacer()
                                    Text(timeString(entity.timestamp))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 900 : .infinity)
        .navigationTitle("All Check-ins")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            
            loadCheckIns()
        }

    }
    
    private var groupedByDay: [String: [EmotionalDataEntity]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return Dictionary(grouping: checkIns) { entity in
            let date = entity.timestamp ?? Date()
            return formatter.string(from: date)
        }
    }
    
    private var sortedDays: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        
        // Get unique dates from checkIns
        let uniqueDates = Set(checkIns.compactMap { $0.timestamp })
        
        // Sort dates in descending order (most recent first)
        let sortedDates = uniqueDates.sorted(by: >)
        
        // Convert back to formatted strings and ensure uniqueness
        let dayStrings = sortedDates.map { formatter.string(from: $0) }
        return Array(Set(dayStrings)).sorted { first, second in
            // Sort by the original date order
            guard let firstDate = sortedDates.first(where: { formatter.string(from: $0) == first }),
                  let secondDate = sortedDates.first(where: { formatter.string(from: $0) == second }) else {
                return false
            }
            return firstDate > secondDate
        }
    }
    
    private func timeString(_ date: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date ?? Date())
    }
    
    private func loadCheckIns() {
        guard let user = persistenceController.getCurrentUser() else {
            checkIns = []
            return
        }
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: false)]
        do {
            checkIns = try persistenceController.container.viewContext.fetch(request)
        } catch {
            checkIns = []
        }
    }

    private func emotionCategory(_ entity: EmotionalDataEntity) -> EmotionCategory? {
        guard let emotion = entity.primaryEmotion else { return nil }
        return EmotionCategory(rawValue: emotion)
    }
    
}

struct EmptyCheckInsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Check-ins Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Start recording your emotions to see your check-in history here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 900 : .infinity, maxHeight: .infinity)
    }
}


#Preview("Sample Data") {
    CheckInsListView()
}


