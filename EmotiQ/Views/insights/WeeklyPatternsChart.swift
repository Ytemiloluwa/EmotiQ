//
//  WeeklyPatternsChart.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import SwiftUI
import Charts

struct WeeklyPatternsChart: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Patterns")
                .font(.headline)
                .fontWeight(.semibold)
            
            if viewModel.weeklyPatternData.isEmpty {
                EmptyWeeklyPatternView()
            } else {
                WeeklyChartContent(viewModel: viewModel)
            }
        }
    }
}

struct WeeklyChartContent: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Chart title
            HStack {
                Text("Average Mood by Day")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Chart
            WeeklyBarChart(data: viewModel.weeklyPatternData)
            
            // Legend and summary
            WeeklyChartLegend(data: viewModel.weeklyPatternData)
        }
        .frame(height: 250)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

struct WeeklyBarChart: View {
    let data: [WeeklyPatternData]
    
    var body: some View {
        Chart {
            ForEach(data, id: \.dayOfWeek) { item in
                BarMark(
                    x: .value("Day", item.dayOfWeek),
                    y: .value("Average Mood", item.averageMood)
                )
                .foregroundStyle(item.hasData ? item.color : Color.gray.opacity(0.3))
                .cornerRadius(4)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxisLabel("Average Mood Score", position: .leading)
        .chartXAxisLabel("Days of the Week", position: .bottom)
    }
}

struct WeeklyChartLegend: View {
    let data: [WeeklyPatternData]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Higher bars = Better mood")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Show days with data
            let daysWithData = data.filter { $0.hasData }
            if !daysWithData.isEmpty {
                HStack {
                    Text("Data available for: \(daysWithData.map { $0.dayOfWeek }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                HStack {
                    Text("No weekly data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}

struct EmptyWeeklyPatternView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Weekly Data")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Record emotions for a week to see patterns")
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
    WeeklyPatternsChart(viewModel: InsightsViewModel())
}
