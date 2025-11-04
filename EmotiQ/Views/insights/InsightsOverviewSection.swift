//
//  InsightsOverviewSection.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI

struct InsightsOverviewSection: View {
    let weeklyCheckIns: Int
    let averageMood: EmotionCategory
    let currentStreak: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 15) {
                OverviewCard(
                    title: "This Week",
                    value: "\(weeklyCheckIns)",
                    subtitle: "Check-ins",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                OverviewCard(
                    title: "Avg Mood",
                    value: averageMood.emoji,
                    subtitle: averageMood.displayName,
                    icon: "person.fill",
                    color: .gray
                )
                
                OverviewCard(
                    title: "Streak",
                    value: "\(currentStreak)",
                    subtitle: "Days",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
    }
}

struct OverviewCard: View {
    let title: String
    let value: String
    let subtitle: String
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
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

#Preview {
    InsightsOverviewSection(weeklyCheckIns: 3, averageMood: .neutral, currentStreak: 2)
}
