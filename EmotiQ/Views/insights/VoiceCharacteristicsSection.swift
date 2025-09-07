//
//  VoiceCharacteristicsSection.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI
import Charts

struct VoiceCharacteristicsSection: View {
    @ObservedObject var viewModel: InsightsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Voice Characteristics Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            if viewModel.voiceCharacteristicsData.isEmpty {
                EmptyVoiceCharacteristicsView()
            } else {
                VStack(spacing: 24) {
                    // Voice Quality Metrics
                    VoiceQualityMetricsView(data: viewModel.voiceCharacteristicsData)
                    
                    // Pitch and Energy Trends
                    PitchEnergyTrendsChart(data: viewModel.voiceCharacteristicsData)
                    
                    // Voice Stability Analysis
                    VoiceStabilityChart(data: viewModel.voiceCharacteristicsData)
                    
                    // Formant Analysis
                    //FormantAnalysisChart(data: viewModel.voiceCharacteristicsData)
                    
                    // Voice Insights
                    VoiceInsightsCards(insights: viewModel.voiceInsights)
                }
            }
        }
    }
}

// MARK: - Voice Quality Metrics Overview
struct VoiceQualityMetricsView: View {
    let data: [VoiceCharacteristicsDataPoint]
    
    private var averageMetrics: (pitch: Double, energy: Double, hnr: Double, stability: Double) {
        guard !data.isEmpty else { return (0, 0, 0, 0) }
        
        let avgPitch = data.map { $0.pitch }.reduce(0, +) / Double(data.count)
        let avgEnergy = data.map { $0.energy }.reduce(0, +) / Double(data.count)
        let avgHNR = data.compactMap { $0.harmonicToNoiseRatio }.reduce(0, +) / Double(data.compactMap { $0.harmonicToNoiseRatio }.count)
        
        // Calculate stability as inverse of jitter/shimmer variation
        let jitterValues = data.compactMap { $0.jitter }
        let shimmerValues = data.compactMap { $0.shimmer }
        let avgJitter = jitterValues.isEmpty ? 0 : jitterValues.reduce(0, +) / Double(jitterValues.count)
        let avgShimmer = shimmerValues.isEmpty ? 0 : shimmerValues.reduce(0, +) / Double(shimmerValues.count)
        let stability = max(0, 1.0 - (avgJitter + avgShimmer) / 2.0)
        
        return (avgPitch, avgEnergy, avgHNR, stability)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice Quality Overview")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            let metrics = averageMetrics
            
            HStack(spacing: 15) {
                VoiceMetricCard(
                    title: "Avg Pitch",
                    value: String(format: "%.0f Hz", metrics.pitch),
                    icon: "waveform",
                    color: .blue,
                    description: "Fundamental frequency"
                )
                
                VoiceMetricCard(
                    title: "Voice Energy",
                    value: String(format: "%.2f", metrics.energy),
                    icon: "speaker.wave.2",
                    color: .green,
                    description: "Audio intensity level"
                )
                
                VoiceMetricCard(
                    title: "Voice Quality",
                    value: String(format: "%.1f dB", metrics.hnr),
                    icon: "waveform.path.ecg",
                    color: .orange,
                    description: "Harmonic-to-noise ratio"
                )
                
                VoiceMetricCard(
                    title: "Stability",
                    value: String(format: "%.0f%%", metrics.stability * 100),
                    icon: "chart.line.flattrend.xyaxis",
                    color: .purple,
                    description: "Voice consistency"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

struct VoiceMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Pitch and Energy Trends Chart
struct PitchEnergyTrendsChart: View {
    let data: [VoiceCharacteristicsDataPoint]
    
    // Aggregate data by date for better visualization
    private var aggregatedData: [DateAggregatedData] {
        let calendar = Calendar.current
        let groupedData = Dictionary(grouping: data) { point in
            calendar.startOfDay(for: point.timestamp)
        }
        
        let realData = groupedData.map { date, points in
            let avgPitch = points.map { $0.pitch }.reduce(0, +) / Double(points.count)
            let avgEnergy = points.map { $0.energy }.reduce(0, +) / Double(points.count)
            
            // Debug energy calculation details
            print("🔍 DEBUG: Aggregating data for \(date): \(points.count) points, avgPitch=\(avgPitch), avgEnergy=\(avgEnergy)")
            print("🔍 DEBUG: Raw energy values for \(date): \(points.map { $0.energy })")
            print("🔍 DEBUG: Energy calculation: sum=\(points.map { $0.energy }.reduce(0, +)), count=\(points.count), avg=\(avgEnergy)")
            
            return DateAggregatedData(
                date: date,
                pitch: avgPitch,
                energy: avgEnergy,
                recordingCount: points.count
            )
        }.sorted { $0.date < $1.date }
        
        // If we have data, show from first recording date + next 6 days
        if !realData.isEmpty {
            let firstDate = realData.first!.date
            let startDate = calendar.startOfDay(for: firstDate)
            
            var allDates: [DateAggregatedData] = []
            for dayOffset in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                    if let existingData = realData.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                        allDates.append(existingData)
                        print("🔍 DEBUG: Using existing data for \(date): pitch=\(existingData.pitch), energy=\(existingData.energy)")
                    } else {
                        // Add empty data point for missing days
                        allDates.append(DateAggregatedData(
                            date: date,
                            pitch: 0,
                            energy: 0,
                            recordingCount: 0
                        ))
                        print("🔍 DEBUG: Added empty data for \(date)")
                    }
                }
            }
            return allDates
        }
        
        return realData
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pitch & Energy Trends")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            

            
            if aggregatedData.isEmpty {
                Text("No voice data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                VStack(spacing: 8) {

                    
                    HStack(alignment: .top, spacing: 8) {
                        // Y-axis labels
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach((0...5).reversed(), id: \.self) { i in
                                Text(String(format: "%.1f", Double(i) * 0.2))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(height: 30)
                            }
                        }
                        .frame(width: 25)
                        
                        VStack(spacing: 8) {
                            // Chart area
                            GeometryReader { geometry in
                                ZStack {
                                    // Grid lines
                                    VStack(spacing: 0) {
                                        ForEach(0..<6) { i in
                                            Divider()
                                                .opacity(0.8)
                                            if i < 5 {
                                                Spacer()
                                            }
                                        }
                                    }
                                    .offset(y: -2)
                                    
                                    // Chart lines
                                    Path { path in
                                        guard !aggregatedData.isEmpty else { return }
                                        
                                        let width = geometry.size.width
                                        let height = geometry.size.height
                                        let stepX = width / CGFloat(max(aggregatedData.count - 1, 1))
                                        
                                        // Pitch line (blue) - normalized to 0-0.9 scale (leaving 10% padding at top)
                                        let pitchPoints = aggregatedData.enumerated().map { index, item in
                                            let normalizedPitch = min(max(item.pitch / 500.0, 0.0), 0.9) // Clamp to 0-0.9 for padding
                                            let yPosition = height - CGFloat(normalizedPitch) * height
                                            return CGPoint(
                                                x: CGFloat(index) * stepX,
                                                y: yPosition
                                            )
                                        }
                                        
                                        path.move(to: pitchPoints[0])
                                        for point in pitchPoints.dropFirst() {
                                            path.addLine(to: point)
                                        }
                                    }
                                    .stroke(Color.blue, lineWidth: 2)
                                    
                                    // Energy line (green)
                                    Path { path in
                                        guard !aggregatedData.isEmpty else { return }
                                        
                                        let width = geometry.size.width
                                        let height = geometry.size.height
                                        let stepX = width / CGFloat(max(aggregatedData.count - 1, 1))
                                        
                                        let energyPoints = aggregatedData.enumerated().map { index, item in
                                            // Normalize energy to 0-0.9 scale (energy values are typically 0.001-0.1)
                                            let normalizedEnergy = min(item.energy * 50.0, 0.9) // Scale up small energy values, max 0.9 for padding
                                            let yPosition = height - CGFloat(normalizedEnergy) * height
                                            
                                            // Debug energy normalization
                                            print("🔍 DEBUG: Energy normalization for day \(index + 1): raw=\(item.energy), scaled=\(item.energy * 50.0), normalized=\(normalizedEnergy), yPosition=\(yPosition)")
                                            
                                            return CGPoint(
                                                x: CGFloat(index) * stepX,
                                                y: yPosition
                                            )
                                        }
                                        
                                        path.move(to: energyPoints[0])
                                        for point in energyPoints.dropFirst() {
                                            path.addLine(to: point)
                                        }
                                    }
                                    .stroke(Color.green, lineWidth: 2)
                                    
                                    // Data points
                                    ForEach(Array(aggregatedData.enumerated()), id: \.offset) { index, item in
                                        let width = geometry.size.width
                                        let height = geometry.size.height
                                        let stepX = width / CGFloat(max(aggregatedData.count - 1, 1))
                                        
                                        // Pitch points (blue circles)
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 6, height: 6)
                                            .position(
                                                x: CGFloat(index) * stepX,
                                                y: height - (CGFloat(min(max(item.pitch / 500.0, 0.0), 0.9))) * height
                                            )
                                        
                                        // Energy points (green squares)
                                        Rectangle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                            .position(
                                                x: CGFloat(index) * stepX,
                                                y: height - (CGFloat(min(max(item.energy * 50.0, 0.0), 0.9))) * height
                                            )
                                    }
                                }
                            }
                            .frame(height: 150)
                            .padding(.top, 8) // Add top padding for breathing room
                            .padding(.bottom, 8) // Add bottom padding for breathing room
                            .clipped() // Ensure chart content stays within bounds
                            
                            // X-axis labels (dates) - positioned at bottom
                            HStack {
                                ForEach(Array(aggregatedData.enumerated()), id: \.offset) { index, item in
                                    Text(formatDate(item.date))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    if index < aggregatedData.count - 1 {
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.top, 8) // Add space between chart and labels
                        }
                    }
                    
                    // Legend
                    HStack(spacing: 20) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                            Text("Pitch (normalized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Energy Level")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// Helper struct for aggregated data
struct DateAggregatedData {
    let date: Date
    let pitch: Double
    let energy: Double
    let recordingCount: Int
}

// MARK: - Formant Analysis Chart
struct FormantAnalysisChart: View {
    let data: [VoiceCharacteristicsDataPoint]
    
    private var formantData: [(timestamp: Date, f1: Double, f2: Double)] {
        data.compactMap { point in
            guard let formants = point.formantFrequencies,
                  formants.count >= 2 else { return nil }
            return (point.timestamp, formants[0], formants[1])
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Formant Frequencies (Vocal Tract Shape)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if formantData.isEmpty {
                Text("No formant data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(Array(formantData.enumerated()), id: \.offset) { index, point in
                        // F1 (First Formant)
                        PointMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Frequency", point.f1)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(40)
                        
                        // F2 (Second Formant)
                        PointMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Frequency", point.f2)
                        )
                        .foregroundStyle(.purple)
                        .symbolSize(40)
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: 200...3000) // Typical formant range
                .chartXAxis {
                    AxisMarks { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(0.3))
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
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
                    Text("Formants reveal vocal tract configuration and emotion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                            Text("F1 (tongue height)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.purple)
                                .frame(width: 8, height: 8)
                            Text("F2 (tongue position)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Voice Insights Cards
struct VoiceInsightsCards: View {
    let insights: [VoiceInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Analysis Insights")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(insights) { insight in
                    VoiceInsightCard(insight: insight)
                        .frame(minHeight: 120)
                }
            }
        }
    }
}

struct VoiceInsightCard: View {
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

// MARK: - Empty State
struct EmptyVoiceCharacteristicsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Voice Data")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Record your voice with emotion analysis to see detailed voice characteristics and patterns")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "waveform.path")
                        .foregroundColor(.blue)
                    Text("Analyze pitch, energy, and voice quality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .foregroundColor(.green)
                    Text("Track voice patterns over time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "brain.head.profile.fill")
                        .foregroundColor(.purple)
                    Text("Understand voice-emotion connections")
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
    VoiceCharacteristicsSection(viewModel: InsightsViewModel())
        .padding()
}
