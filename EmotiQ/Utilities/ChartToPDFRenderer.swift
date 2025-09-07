//
//  ChartToPDFRenderer.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI
import Charts

@MainActor
struct ChartToPDFRenderer {
    
    // MARK: - Chart Rendering Functions
    
    static func renderEmotionTrendsChart(
        data: [EmotionIntensityDataPoint],
        uniqueEmotions: [EmotionCategory],
        size: CGSize
    ) -> UIImage? {
        let chartView = EmotionTrendsChartForPDF(data: data, uniqueEmotions: uniqueEmotions)
        return renderSwiftUIView(chartView, size: size)
    }
    
    static func renderEmotionDistributionChart(
        data: [EmotionDistributionData],
        size: CGSize
    ) -> UIImage? {
        let chartView = EmotionDistributionChartForPDF(data: data)
        return renderSwiftUIView(chartView, size: size)
    }
    
    static func renderWeeklyPatternsChart(
        data: [WeeklyPatternData],
        size: CGSize
    ) -> UIImage? {
        let chartView = WeeklyPatternsChartForPDF(data: data)
        return renderSwiftUIView(chartView, size: size)
    }
    
    static func renderVoiceStabilityChart(
        data: [VoiceCharacteristicsDataPoint],
        size: CGSize
    ) -> UIImage? {
        let chartView = VoiceStabilityChartForPDF(data: data)
        return renderSwiftUIView(chartView, size: size)
    }
    
    static func renderVoiceInsightsCards(
        insights: [VoiceInsight],
        size: CGSize
    ) -> UIImage? {
        let chartView = VoiceInsightsCardsForPDF(insights: insights)
        return renderSwiftUIView(chartView, size: size)
    }
    
    // MARK: - SwiftUI to UIImage Conversion
    
    private static func renderSwiftUIView<Content: View>(
        _ content: Content,
        size: CGSize
    ) -> UIImage? {
        let controller = UIHostingController(rootView: content)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = UIColor.systemBackground
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

// MARK: - PDF-Specific Chart Views

struct EmotionTrendsChartForPDF: View {
    let data: [EmotionIntensityDataPoint]
    let uniqueEmotions: [EmotionCategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emotion Intensity Trends")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if data.isEmpty {
                Text("No emotion trends data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Text("How your emotions change over time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Chart(data) { dataPoint in
                        LineMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Intensity", dataPoint.intensity)
                        )
                        .foregroundStyle(dataPoint.emotion.color.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .symbol(by: .value("Emotion", dataPoint.emotion.displayName))
                        
                        AreaMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Intensity", dataPoint.intensity)
                        )
                        .foregroundStyle(
                            dataPoint.emotion.color.opacity(0.2).gradient
                        )
                        .symbol(by: .value("Emotion", dataPoint.emotion.displayName))
                        
                        PointMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Intensity", dataPoint.intensity)
                        )
                        .foregroundStyle(dataPoint.emotion.color)
                        .symbolSize(60)
                        .symbol(by: .value("Emotion", dataPoint.emotion.displayName))
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks { value in
                            if let date = value.as(Date.self) {
                                AxisGridLine()
                                    .foregroundStyle(.secondary.opacity(0.3))
                                AxisValueLabel {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(0.3))
                            AxisValueLabel {
                                if let intensity = value.as(Double.self) {
                                    Text(String(format: "%.1f", intensity))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...1.0)
                    
                    if !uniqueEmotions.isEmpty {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(uniqueEmotions, id: \.self) { emotion in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(emotion.color)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(emotion.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct EmotionDistributionChartForPDF: View {
    let data: [EmotionDistributionData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emotion Distribution")
                .font(.headline)
                .fontWeight(.semibold)
            
            if data.isEmpty {
                Text("No distribution data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Text("Your Emotional Balance")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
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
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct WeeklyPatternsChartForPDF: View {
    let data: [WeeklyPatternData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Patterns")
                .font(.headline)
                .fontWeight(.semibold)
            
            if data.isEmpty {
                Text("No weekly pattern data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Text("Average Mood by Day")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
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
                    .frame(height: 200)
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
                    
                    VStack(spacing: 8) {
                        Text("Higher bars = Better mood")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let daysWithData = data.filter { $0.hasData }
                        if !daysWithData.isEmpty {
                            Text("Data available for: \(daysWithData.map { $0.dayOfWeek }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No weekly data available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Voice Characteristics PDF Chart Views

struct VoiceStabilityChartForPDF: View {
    let data: [VoiceCharacteristicsDataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice Stability Analysis")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if data.isEmpty {
                Text("No voice stability data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Text("Jitter and Shimmer Over Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Chart {
                        ForEach(data) { point in
                            if let jitter = point.jitter {
                                BarMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Jitter", jitter)
                                )
                                .foregroundStyle(.red.opacity(0.7))
                                .cornerRadius(2)
                            }
                            
                            if let shimmer = point.shimmer {
                                BarMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Shimmer", shimmer)
                                )
                                .foregroundStyle(.orange.opacity(0.7))
                                .cornerRadius(2)
                                .position(by: .value("Type", "Shimmer"))
                            }
                        }
                    }
                    .frame(height: 180)
                    .chartYScale(domain: 0...0.1)
                    .chartXAxis {
                        AxisMarks { value in
                            if let date = value.as(Date.self) {
                                AxisGridLine()
                                    .foregroundStyle(.secondary.opacity(0.3))
                                AxisValueLabel {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(0.3))
                            AxisValueLabel()
                                .font(.caption)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lower values indicate more stable voice")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(.red.opacity(0.7))
                                    .frame(width: 8, height: 8)
                                Text("Jitter (pitch variation)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(.orange.opacity(0.7))
                                    .frame(width: 8, height: 8)
                                Text("Shimmer (amplitude variation)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct VoiceInsightsCardsForPDF: View {
    let insights: [VoiceInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice Analysis Insights")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if insights.isEmpty {
                Text("No voice insights available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Text("Key Voice Characteristics")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(insights) { insight in
                            VoiceInsightCardForPDF(insight: insight)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct VoiceInsightCardForPDF: View {
    let insight: VoiceInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: insight.icon)
                    .foregroundColor(insight.color)
                    .font(.title3)
                
                Spacer()
                
                Text(insight.category)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(.secondary.opacity(0.1))
                    )
            }
            
            Text(insight.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Text(insight.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        )
    }
}
