//
//  EmotionTrendsChart.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI
import Charts

struct EmotionTrendsChart: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emotion Intensity Trends")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if viewModel.emotionIntensityData.isEmpty {
                EmptyEmotionTrendsView()
            } else {
                EmotionIntensityChartContent(data: viewModel.emotionIntensityData, uniqueEmotions: viewModel.uniqueEmotions)
            }
        }
    }
}

struct EmotionIntensityChartContent: View {
    let data: [EmotionIntensityDataPoint]
    let uniqueEmotions: [EmotionCategory]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("How your emotions change over time")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Enhanced Emotion Intensity Chart (Lines + Areas + Points)
            Chart(data) { dataPoint in
                // Line chart for emotion intensity over time
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Intensity", dataPoint.intensity)
                )
                .foregroundStyle(dataPoint.emotion.color.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .symbol(by: .value("Emotion", dataPoint.emotion.displayName))
                
                // Area chart for better visualization
                AreaMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Intensity", dataPoint.intensity)
                )
                .foregroundStyle(
                    dataPoint.emotion.color.opacity(0.2).gradient
                )
                .symbol(by: .value("Emotion", dataPoint.emotion.displayName))
                
                // Point markers for data points
                PointMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Intensity", dataPoint.intensity)
                )
                .foregroundStyle(dataPoint.emotion.color)
                .symbolSize(60)
                .symbol(by: .value("Emotion", dataPoint.emotion.displayName))
            }
            .frame(height: 220)
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
            .chartYAxisLabel("Intensity", position: .leading)
            .chartXAxisLabel("Date", position: .bottom)
            .animation(.easeInOut(duration: 0.8), value: data)
            
            if !uniqueEmotions.isEmpty {
                EmotionIntensityLegend(emotions: uniqueEmotions)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

struct EmotionIntensityLegend: View {
    let emotions: [EmotionCategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Emotions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(emotions, id: \.self) { emotion in
                    EmotionLegendItem(emotion: emotion)
                }
            }
        }
    }
}

struct EmotionLegendItem: View {
    let emotion: EmotionCategory
    
    var body: some View {
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

struct EmptyEmotionTrendsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Emotion Trends")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Record your emotions with voice analysis to see your emotional intensity trends over time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Call to action
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(.blue)
                    Text("Use Voice Check to analyze emotions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .foregroundColor(.green)
                    Text("Track emotional patterns over time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "brain.head.profile.fill")
                        .foregroundColor(.purple)
                    Text("Gain insights into your emotional wellbeing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

#Preview {
    EmotionTrendsChart(viewModel: InsightsViewModel())
        .padding()
}
