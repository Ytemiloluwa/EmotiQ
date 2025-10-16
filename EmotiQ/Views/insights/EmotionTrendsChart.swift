//
//  EmotionTrendsChart.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

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
                EmotionIntensityHeatmapContent(data: viewModel.emotionIntensityData, uniqueEmotions: viewModel.uniqueEmotions)
            }
        }
    }
}

struct EmotionIntensityChartContent: View {
    let data: [EmotionIntensityDataPoint]
    let uniqueEmotions: [EmotionCategory]
    
    // UI state: filter by one emotion to reduce clutter
    @State private var selectedEmotion: EmotionCategory? = nil
    
    private var filteredData: [EmotionIntensityDataPoint] {
        guard let selected = selectedEmotion else { return data }
        return data.filter { $0.emotion == selected }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("How your emotions change over time")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Simple chips to filter by emotion (or show All)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    EmotionFilterChip(
                        title: "All",
                        color: .secondary,
                        isSelected: selectedEmotion == nil
                    ) {
                        selectedEmotion = nil
                    }
                    ForEach(uniqueEmotions, id: \.self) { emotion in
                        EmotionFilterChip(
                            title: emotion.displayName,
                            color: emotion.color,
                            isSelected: selectedEmotion == emotion
                        ) {
                            selectedEmotion = (selectedEmotion == emotion) ? nil : emotion
                        }
                    }
                }
            }
            
            // Enhanced Emotion Intensity Chart (Lines + Areas + Points)
            Chart(filteredData) { dataPoint in
                // Line chart for emotion intensity over time
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Intensity", dataPoint.intensity)
                )
                .foregroundStyle(dataPoint.emotion.color)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .symbol(by: .value("Emotion", dataPoint.emotion.displayName))
                
                // Area chart for better visualization
                AreaMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Intensity", dataPoint.intensity)
                )
                .foregroundStyle(dataPoint.emotion.color.opacity(0.2))
                .symbol(by: .value("Emotion", dataPoint.emotion.displayName))
                
                // Point markers for data points
                PointMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Intensity", dataPoint.intensity)
                )
                .foregroundStyle(dataPoint.emotion.color)
                .symbolSize(60)
                .symbol(by: .value("Emotion", dataPoint.emotion.displayName))
                
                // Make points focusable when a single emotion is selected
                .opacity(selectedEmotion == nil ? 0.8 : 1.0)
            }
            .frame(height: 220)
            // Intensity bands and labels to aid comprehension
            .chartOverlay { proxy in
                // No interactive overlay added here to keep lightweight
                Color.clear
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
            .chartYScale(domain: 0...1.0)
            // Threshold guide lines with labels
            .chartForegroundStyleScale(range: [Color.primary])
            .chartPlotStyle { plot in
                plot.background(.secondary.opacity(0.05))
            }
            .overlay(alignment: .topLeading) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Rectangle().fill(Color.clear).frame(width: 0, height: 0)
                        Text("High")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 6)
            }
            .overlay {
                // Horizontal threshold lines at 0.33 and 0.66
                GeometryReader { geo in
                    ZStack {
                        let h = geo.size.height
                        let yLow = h * (1 - 0.33)
                        let yMed = h * (1 - 0.66)
                        Group {
                            Rectangle()
                                .fill(Color.clear)
                                .overlay(Rectangle().fill(Color.yellow.opacity(0.08)))
                                .frame(height: h * (0.34))
                                .position(x: geo.size.width/2, y: h - (h*0.17))
                            Rectangle()
                                .fill(Color.clear)
                                .overlay(Rectangle().fill(Color.orange.opacity(0.06)))
                                .frame(height: h * (0.33))
                                .position(x: geo.size.width/2, y: yLow - (h*0.165))
                        }
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: yLow))
                            p.addLine(to: CGPoint(x: geo.size.width, y: yLow))
                        }
                        .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4,4]))
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: yMed))
                            p.addLine(to: CGPoint(x: geo.size.width, y: yMed))
                        }
                        .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4,4]))
                    }
                }
                .allowsHitTesting(false)
            }
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

// MARK: - Heatmap (simpler, less cluttered)
struct EmotionIntensityHeatmapContent: View {
    let data: [EmotionIntensityDataPoint]
    let uniqueEmotions: [EmotionCategory]
    
    private struct HeatCell: Identifiable {
        let id = UUID()
        let date: Date
        let emotion: EmotionCategory
        let intensity: Double
    }
    
    private var heatCells: [HeatCell] {
        guard !data.isEmpty else { return [] }
        let calendar = Calendar.current
        let firstDate = data.map { $0.timestamp }.min() ?? Date()
        let start = calendar.startOfDay(for: firstDate)
        var cells: [HeatCell] = []
        
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let dayPoints = data.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            let grouped = Dictionary(grouping: dayPoints, by: { $0.emotion })
            for emotion in uniqueEmotions {
                let points = grouped[emotion] ?? []
                let avg = points.isEmpty ? 0.0 : (points.map { $0.intensity }.reduce(0, +) / Double(points.count))
                cells.append(HeatCell(date: day, emotion: emotion, intensity: avg))
            }
        }
        return cells.sorted { lhs, rhs in
            if lhs.date == rhs.date { return lhs.emotion.displayName < rhs.emotion.displayName }
            return lhs.date < rhs.date
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Color shows intensity (low to high)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Chart(heatCells) { cell in
                RectangleMark(
                    x: .value("Date", cell.date),
                    y: .value("Emotion", cell.emotion.displayName)
                )
                .foregroundStyle(by: .value("Intensity", cell.intensity))
                .cornerRadius(2)
            }
            .frame(height: max(180, CGFloat(uniqueEmotions.count) * 24 + 60))
            .chartYScale()
            .chartXAxis {
                AxisMarks { value in
                    if let date = value.as(Date.self) {
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
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
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel().font(.caption)
                }
            }
            .chartForegroundStyleScale(range: [
                Color.blue.opacity(0.15),
                Color.yellow.opacity(0.55),
                Color.red.opacity(0.8)
            ])
            .chartLegend(.hidden)
            
            // Simple color legend
            HStack(spacing: 8) {
                Text("Low").font(.caption).foregroundColor(.secondary)
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.yellow.opacity(0.6), Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 120, height: 8)
                .clipShape(Capsule())
                Text("High").font(.caption).foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}
// MARK: - Filter Chip
struct EmotionFilterChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
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
