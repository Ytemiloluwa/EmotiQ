//
//  VoiceStabilityPeriodSelector.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import SwiftUI

// MARK: - Period Selector View
struct VoiceStabilityPeriodSelector: View {
    @Binding var selectedPeriod: ChartPeriod
    let onPeriodChanged: (ChartPeriod) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Period Selection Buttons
            HStack(spacing: 12) {
                ForEach(ChartPeriod.allCases, id: \.self) { period in
                    PeriodButton(
                        period: period,
                        isSelected: selectedPeriod == period,
                        action: {
                            selectedPeriod = period
                            onPeriodChanged(period)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            
            // Current Selection Info
            HStack {
                Text("Showing: \(selectedPeriod.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(selectedPeriod.days == Int.max ? "All recordings" : "Last \(selectedPeriod.days) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

// MARK: - Individual Period Button
private struct PeriodButton: View {
    let period: ChartPeriod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.rawValue)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color(.systemGray6))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    VoiceStabilityPeriodSelector(
        selectedPeriod: .constant(.month),
        onPeriodChanged: { _ in }
    )
    .padding()
}


