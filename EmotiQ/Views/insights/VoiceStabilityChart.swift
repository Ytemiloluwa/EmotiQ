//
//  VoiceStabilityChart.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI
import Charts

// MARK: - Production-Ready Voice Stability Chart (Fixed & Enhanced)
struct VoiceStabilityChart: View {
    let data: [VoiceCharacteristicsDataPoint]
    
    // MARK: - State Management
    @StateObject private var dataProcessor = VoiceStabilityDataProcessor()
    @State private var processedData: ProcessedChartData?
    @State private var isLoading = false
    @State private var selectedDataPoint: VoiceCharacteristicsDataPoint?
    @State private var showingDataDetails = false
    
    // MARK: - Computed Properties
    private var chartHeight: CGFloat {
        guard let processed = processedData else { return VoiceStabilityChartConfig.Dimensions.baseHeight }
        return VoiceStabilityChartConfig.Dimensions.chartHeight(
            for: processed.dataPoints.count,
            period: processed.period
        )
    }
    
    private var yAxisScale: Double {
        guard let processed = processedData else { return VoiceStabilityChartConfig.YAxisScaling.defaultScale }
        
        let maxJitter = processed.dataPoints.compactMap { $0.jitter }.max() ?? 0
        let maxShimmer = processed.dataPoints.compactMap { $0.shimmer }.max() ?? 0
        let maxValue = max(maxJitter, maxShimmer)
        
        // Ensure Y-axis includes threshold values for better visibility
        let thresholds = self.thresholds
        let maxThreshold = max(thresholds.calm, thresholds.normal, thresholds.expressive)
        let adjustedMaxValue = max(maxValue, maxThreshold * 1.2) // Add 20% padding above thresholds
        
        return VoiceStabilityChartConfig.YAxisScaling.calculateScale(
            for: adjustedMaxValue,
            dataCount: processed.dataPoints.count
        )
    }
    
    private var thresholds: (calm: Double, normal: Double, expressive: Double) {
        guard let processed = processedData else { return (0.03, 0.06, 0.10) }
        
        let maxJitter = processed.dataPoints.compactMap { $0.jitter }.max() ?? 0
        let maxShimmer = processed.dataPoints.compactMap { $0.shimmer }.max() ?? 0
        let maxValue = max(maxJitter, maxShimmer)
        
        return VoiceStabilityChartConfig.Thresholds.calculateThresholds(for: maxValue)
    }
    
    // MARK: - Lifecycle
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            chartHeader
            
            // Period Selector
            VoiceStabilityPeriodSelector(
                selectedPeriod: $dataProcessor.selectedPeriod,
                onPeriodChanged: { period in
                    processDataForPeriod(period)
                }
            )
            
            // Chart Container
            chartContainer
            
            // Legend and Info
            if let processed = processedData, !processed.dataPoints.isEmpty {
                chartLegend
                
                // Enhanced insights section
                enhancedInsightsSection(for: processed)
            }
        }
        .onAppear {
            processDataForPeriod(dataProcessor.selectedPeriod)
        }
        .onChange(of: data) { _ in
            processDataForPeriod(dataProcessor.selectedPeriod)
        }
        .sheet(isPresented: $showingDataDetails) {
            dataDetailsSheet
        }
    }
    
    // MARK: - Chart Header
    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice & Emotion Patterns")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Voice variation reflects emotional expression")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Fixed Emotional Expression Indicator
                emotionalExpressionIndicator
            }
        }
    }
    
    // MARK: - Chart Container
    private var chartContainer: some View {
        VStack(spacing: 8) {
            if isLoading {
                loadingView
            } else if let processed = processedData, !processed.dataPoints.isEmpty {
                chartView(for: processed)
            } else {
                emptyStateView
            }
        }
        .frame(height: chartHeight)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    // MARK: - Enhanced Chart View (FIXED)
    private func chartView(for processed: ProcessedChartData) -> some View {
        Chart {
            // ✅ FIXED: Data marks in ForEach instead of Chart iteration
            ForEach(processed.dataPoints, id: \.timestamp) { point in
                // Jitter line with enhanced styling
                if let jitter = point.jitter {
                    LineMark(
                        x: .value("Date", point.timestamp),
                        y: .value("Jitter", jitter)
                    )
                    .foregroundStyle(VoiceStabilityChartConfig.Visual.jitterColor)
                    .lineStyle(StrokeStyle(lineWidth: VoiceStabilityChartConfig.Visual.lineWidth, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    
                    // Enhanced area with gradient
                    AreaMark(
                        x: .value("Date", point.timestamp),
                        y: .value("Jitter", jitter)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                VoiceStabilityChartConfig.Visual.jitterColor.opacity(VoiceStabilityChartConfig.Visual.areaOpacity),
                                VoiceStabilityChartConfig.Visual.jitterColor.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    // Interactive point markers
                    PointMark(
                        x: .value("Date", point.timestamp),
                        y: .value("Jitter", jitter)
                    )
                    .foregroundStyle(VoiceStabilityChartConfig.Visual.jitterColor)
                    .symbolSize(selectedDataPoint?.timestamp == point.timestamp ? 60 : 30)
                    .opacity(selectedDataPoint?.timestamp == point.timestamp ? 1.0 : 0.7)
                }
                
                // Shimmer line with enhanced styling
                if let shimmer = point.shimmer {
                    LineMark(
                        x: .value("Date", point.timestamp),
                        y: .value("Shimmer", shimmer)
                    )
                    .foregroundStyle(VoiceStabilityChartConfig.Visual.shimmerColor)
                    .lineStyle(StrokeStyle(lineWidth: VoiceStabilityChartConfig.Visual.lineWidth, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    
                    // Enhanced area with gradient
                    AreaMark(
                        x: .value("Date", point.timestamp),
                        y: .value("Shimmer", shimmer)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                VoiceStabilityChartConfig.Visual.shimmerColor.opacity(VoiceStabilityChartConfig.Visual.areaOpacity),
                                VoiceStabilityChartConfig.Visual.shimmerColor.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    // Interactive point markers
                    PointMark(
                        x: .value("Date", point.timestamp),
                        y: .value("Shimmer", shimmer)
                    )
                    .foregroundStyle(VoiceStabilityChartConfig.Visual.shimmerColor)
                    .symbolSize(selectedDataPoint?.timestamp == point.timestamp ? 60 : 30)
                    .opacity(selectedDataPoint?.timestamp == point.timestamp ? 1.0 : 0.7)
                }
            }
            
            // ✅ FIXED: Threshold lines drawn ONCE outside the data iteration
            let thresholds = self.thresholds
            
            RuleMark(y: .value("Calm", thresholds.calm))
                .foregroundStyle(VoiceStabilityChartConfig.Visual.calmThresholdColor.opacity(VoiceStabilityChartConfig.Visual.thresholdOpacity))
                .lineStyle(VoiceStabilityChartConfig.Visual.thresholdLineStyle)
                .annotation(position: .topTrailing, alignment: .leading) {
                    Text("Calm")
                        .font(.caption2)
                        .foregroundColor(VoiceStabilityChartConfig.Visual.calmThresholdColor)
                        .padding(.horizontal, 4)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            
            RuleMark(y: .value("Natural", thresholds.normal))
                .foregroundStyle(VoiceStabilityChartConfig.Visual.normalThresholdColor.opacity(VoiceStabilityChartConfig.Visual.thresholdOpacity))
                .lineStyle(VoiceStabilityChartConfig.Visual.thresholdLineStyle)
                .annotation(position: .topTrailing, alignment: .leading) {
                    Text("Natural")
                        .font(.caption2)
                        .foregroundColor(VoiceStabilityChartConfig.Visual.normalThresholdColor)
                        .padding(.horizontal, 4)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            
            RuleMark(y: .value("Expressive", thresholds.expressive))
                .foregroundStyle(VoiceStabilityChartConfig.Visual.expressiveThresholdColor.opacity(VoiceStabilityChartConfig.Visual.thresholdOpacity))
                .lineStyle(VoiceStabilityChartConfig.Visual.thresholdLineStyle)
                .annotation(position: .topTrailing, alignment: .leading) {
                    Text("Expressive")
                        .font(.caption2)
                        .foregroundColor(VoiceStabilityChartConfig.Visual.expressiveThresholdColor)
                        .padding(.horizontal, 4)
                        .background(Color(.systemBackground).opacity(0.8))
                }
        }
        //.chartXSelection(value: .constant(nil))
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleChartTap(at: location, geometry: geometry, chartProxy: chartProxy, processed: processed)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStrideValue)) { value in
                AxisGridLine()
                    .foregroundStyle(.secondary.opacity(VoiceStabilityChartConfig.Visual.gridOpacity))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatDate(date, for: dataProcessor.selectedPeriod))
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: yAxisStride)) { value in
                AxisGridLine()
                    .foregroundStyle(.secondary.opacity(VoiceStabilityChartConfig.Visual.gridOpacity))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f%%", doubleValue * 100))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...yAxisScale)
        .padding(.leading, VoiceStabilityChartConfig.Spacing.axisLabelPadding)
        .padding(.bottom, VoiceStabilityChartConfig.Spacing.chartPadding)
    }
    
    // MARK: - Enhanced Chart Legend
    private var chartLegend: some View {
        VStack(alignment: .leading, spacing: VoiceStabilityChartConfig.Spacing.legendSpacing) {
            // Data series legend with enhanced styling
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(VoiceStabilityChartConfig.Visual.jitterColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(VoiceStabilityChartConfig.Visual.jitterColor.opacity(0.3), lineWidth: 2)
                                .scaleEffect(1.5)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Jitter")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Voice frequency variation")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(VoiceStabilityChartConfig.Visual.shimmerColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(VoiceStabilityChartConfig.Visual.shimmerColor.opacity(0.3), lineWidth: 2)
                                .scaleEffect(1.5)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shimmer")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Voice amplitude variation")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Enhanced threshold legend
            let thresholds = self.thresholds
            HStack(spacing: VoiceStabilityChartConfig.Spacing.thresholdSpacing) {
                thresholdLegendItem(
                    color: VoiceStabilityChartConfig.Visual.calmThresholdColor,
                    label: "Calm",
                    value: thresholds.calm,
                    description: "Relaxed state"
                )
                
                thresholdLegendItem(
                    color: VoiceStabilityChartConfig.Visual.normalThresholdColor,
                    label: "Natural",
                    value: thresholds.normal,
                    description: "Balanced expression"
                )
                
                thresholdLegendItem(
                    color: VoiceStabilityChartConfig.Visual.expressiveThresholdColor,
                    label: "Expressive",
                    value: thresholds.expressive,
                    description: "Animated speech"
                )
            }
        }
        .padding(.horizontal, VoiceStabilityChartConfig.Spacing.chartPadding)
        .padding(.vertical, VoiceStabilityChartConfig.Spacing.chartPadding)
    }
    
    // MARK: - Enhanced Insights Section
    private func enhancedInsightsSection(for processed: ProcessedChartData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Insights")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View Details") {
                    showingDataDetails = true
                }
                .font(.caption2)
                .foregroundColor(.blue)
            }
            
            // Quick stats
            HStack(spacing: 16) {
                insightCard(
                    title: "Average Jitter",
                    value: String(format: "%.1f%%", (processed.dataPoints.compactMap { $0.jitter }.reduce(0, +) / Double(processed.dataPoints.count)) * 100),
                    color: VoiceStabilityChartConfig.Visual.jitterColor
                )
                
                insightCard(
                    title: "Average Shimmer",
                    value: String(format: "%.1f%%", (processed.dataPoints.compactMap { $0.shimmer }.reduce(0, +) / Double(processed.dataPoints.count)) * 100),
                    color: VoiceStabilityChartConfig.Visual.shimmerColor
                )
                
                insightCard(
                    title: "Data Points",
                    value: "\(processed.dataPoints.count)",
                    color: .secondary
                )
            }
        }
        .padding(.horizontal, VoiceStabilityChartConfig.Spacing.chartPadding)
    }
    
    // MARK: - Helper Views
    private func thresholdLegendItem(color: Color, label: String, value: Double, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(color.opacity(VoiceStabilityChartConfig.Visual.thresholdOpacity))
                    .frame(width: 16, height: 2)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            Text(String(format: "%.1f%%", value * 100))
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    private func insightCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(VoiceStabilityChartConfig.Visual.jitterColor)
            Text("Processing data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Enhanced Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 40))
                .foregroundColor(VoiceStabilityChartConfig.Visual.jitterColor)
                .symbolEffect(.pulse)
            
            VStack(spacing: 8) {
                Text("No voice data available")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Record some voice samples to see your emotional patterns")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Voice data is automatically deleted after 30 days")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
            }
            
            Button("Learn More") {
                showingDataDetails = true
            }
            .font(.caption)
            .foregroundColor(.blue)
            .padding(.top, 8)
        }
        .padding()
    }
    
    // MARK: - Fixed Emotional Expression Indicator
    private var emotionalExpressionIndicator: some View {
        // ✅ FIXED: Now uses processedData instead of raw data for consistency
        let dataPoints = processedData?.dataPoints ?? []
        let jitterValues = dataPoints.compactMap { $0.jitter }.filter { $0 >= 0 }
        let shimmerValues = dataPoints.compactMap { $0.shimmer }.filter { $0 >= 0 }
        
        let avgJitter = jitterValues.isEmpty ? 0 : jitterValues.reduce(0, +) / Double(jitterValues.count)
        let avgShimmer = shimmerValues.isEmpty ? 0 : shimmerValues.reduce(0, +) / Double(shimmerValues.count)
        let overallExpression = max(avgJitter, avgShimmer)
        
        let (color, text, description) = {
            if overallExpression < 0.03 { return (Color.blue, "Calm", "Relaxed voice") }
            else if overallExpression < 0.06 { return (Color.green, "Natural", "Balanced expression") }
            else if overallExpression < 0.10 { return (Color.purple, "Expressive", "Animated speech") }
            else { return (Color.red, "Intense", "High variation") }
        }()
        
        return VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 2)
                            .scaleEffect(1.5)
                    )
                Text(text)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Data Details Sheet
    private var dataDetailsSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Understanding Voice Patterns")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Your voice characteristics reveal emotional patterns through subtle variations in frequency and amplitude.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    explanationCard(
                        title: "Jitter",
                        description: "Measures frequency variation in your voice. Higher jitter often indicates emotional intensity or stress.",
                        color: VoiceStabilityChartConfig.Visual.jitterColor
                    )
                    
                    explanationCard(
                        title: "Shimmer",
                        description: "Measures amplitude variation in your voice. Changes in shimmer reflect emotional expression and vocal control.",
                        color: VoiceStabilityChartConfig.Visual.shimmerColor
                    )
                }
                
                Spacer()
                
                Text("Privacy: All voice data is processed locally and automatically deleted after 30 days.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Voice Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                showingDataDetails = false
            })
        }
    }
    
    private func explanationCard(title: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
    
    // MARK: - Chart Interaction
    private func handleChartTap(at location: CGPoint, geometry: GeometryProxy, chartProxy: ChartProxy, processed: ProcessedChartData) {
        let frame = geometry[chartProxy.plotAreaFrame]
        let relativeXPosition = location.x - frame.origin.x
        let relativeYPosition = location.y - frame.origin.y
        
        if let date = chartProxy.value(atX: relativeXPosition) as Date? {
            // Find closest data point
            let closestPoint = processed.dataPoints.min { point1, point2 in
                abs(point1.timestamp.timeIntervalSince(date)) < abs(point2.timestamp.timeIntervalSince(date))
            }
            
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDataPoint = closestPoint
            }
            
            // Auto-deselect after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDataPoint = nil
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private var xAxisStride: Calendar.Component {
        guard let processed = processedData else { return .day }
        return VoiceStabilityChartConfig.XAxisConfig.labelStride(
            for: processed.dataPoints.count,
            period: processed.period
        )
    }
    
    private var xAxisStrideValue: Double {
        guard let processed = processedData else { return 1.0 }
        return VoiceStabilityChartConfig.XAxisConfig.chartStride(
            for: processed.period,
            dataCount: processed.dataPoints.count
        )
    }
    
    private var yAxisStride: Double {
        guard let processed = processedData else { return 0.005 }
        let maxValue = yAxisScale
        if maxValue <= 0.01 { return 0.002 }      // 0.2% steps for very low values
        else if maxValue <= 0.05 { return 0.005 } // 0.5% steps for low values
        else if maxValue <= 0.10 { return 0.01 }  // 1% steps for medium values
        else { return 0.02 }                      // 2% steps for high values
    }
    
    private func formatDate(_ date: Date, for period: ChartPeriod) -> String {
        let format = VoiceStabilityChartConfig.XAxisConfig.dateFormat(for: period)
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    private func processDataForPeriod(_ period: ChartPeriod) {
        isLoading = true
        selectedDataPoint = nil // Clear selection when changing periods
        
        Task {
            let processed = dataProcessor.processData(data, for: period)
            
            await MainActor.run {
                processedData = processed
                isLoading = false
            }
        }
    }
}

