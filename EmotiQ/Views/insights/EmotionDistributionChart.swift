//
//  EmotionDistributionChart.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI
import Charts

struct EmotionDistributionChart: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emotion Distribution")
                .font(.headline)
                .fontWeight(.semibold)
            
            if viewModel.emotionDistribution.isEmpty {
                EmptyDistributionView()
            } else {
                DistributionChartContent(data: viewModel.emotionDistribution)
            }
        }
    }
}

struct DistributionChartContent: View {
    let data: [EmotionDistributionData]
    
    var body: some View {
        VStack(spacing: 12) {
            // Chart title
            HStack {
                Text("Your Emotional Balance")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Chart
            DistributionPieChart(data: data)
            
            // Legend
            DistributionLegend(data: data)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

struct DistributionPieChart: View {
    let data: [EmotionDistributionData]
    
    var body: some View {
        Chart {
            ForEach(data) { item in
                SectorMark(
                    angle: .value("Percentage", item.percentage),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(item.color)
                .cornerRadius(4)
            }
        }
        .frame(height: 200)
    }
}

struct DistributionLegend: View {
    let data: [EmotionDistributionData]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(data) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)
                    
                    Text(item.emotion.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(item.percentage))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct EmptyDistributionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Distribution Data")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Record emotions to see your emotional balance")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

#Preview {
    EmotionDistributionChart(viewModel: InsightsViewModel())
}
