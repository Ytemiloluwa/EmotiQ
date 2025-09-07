//
//  VoiceStabilityDataProcessor.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation

// MARK: - Chart Period Selection
// Note: Voice data persists on device for 30 days only (privacy policy compliance)
enum ChartPeriod: String, CaseIterable {
    case week = "7D"      // Last 7 days
    case month = "30D"    // Last 30 days (maximum data retention)
    case all = "ALL"      // All available data (up to 30 days)
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .all: return "All Time"
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .all: return Int.max
        }
    }
}

// MARK: - Aggregation Strategy
enum AggregationStrategy {
    case individual    // Show raw data points
    case daily        // Daily averages
    case weekly       // Weekly averages
    case monthly      // Monthly averages
    
    var description: String {
        switch self {
        case .individual: return "Individual recordings"
        case .daily: return "Daily averages"
        case .weekly: return "Weekly averages"
        case .monthly: return "Monthly averages"
        }
    }
}

// MARK: - Data Processing Result
struct ProcessedChartData {
    let dataPoints: [VoiceCharacteristicsDataPoint]
    let aggregationStrategy: AggregationStrategy
    let period: ChartPeriod
    let totalRecordings: Int
    let dateRange: ClosedRange<Date>
    let samplingInfo: String
}

// MARK: - Voice Stability Data Processor
@MainActor
class VoiceStabilityDataProcessor: ObservableObject {
    @Published var selectedPeriod: ChartPeriod = .month
    @Published var isProcessing = false
    
    // MARK: - Smart Data Processing
    func processData(_ rawData: [VoiceCharacteristicsDataPoint], for period: ChartPeriod) -> ProcessedChartData {
        isProcessing = true
        defer { isProcessing = false }
        
        // Safety check for empty data
        guard !rawData.isEmpty else {
            return ProcessedChartData(
                dataPoints: [],
                aggregationStrategy: .individual,
                period: period,
                totalRecordings: 0,
                dateRange: Date()...Date(),
                samplingInfo: "No data available"
            )
        }
        
        // Filter data by selected period
        let filteredData = filterDataByPeriod(rawData, period: period)
        
        // Safety check for filtered data
        guard !filteredData.isEmpty else {
            return ProcessedChartData(
                dataPoints: [],
                aggregationStrategy: .individual,
                period: period,
                totalRecordings: rawData.count,
                dateRange: Date()...Date(),
                samplingInfo: "No data in selected period"
            )
        }
        
        // Determine optimal aggregation strategy based on data density
        let strategy = determineAggregationStrategy(for: filteredData.count, period: period)
        
        // Apply aggregation strategy
        let aggregatedData = applyAggregationStrategy(filteredData, strategy: strategy)
        
        // Calculate date range
        let dateRange = calculateDateRange(from: filteredData)
        
        // Generate sampling info
        let samplingInfo = generateSamplingInfo(
            totalRecordings: rawData.count,
            filteredRecordings: filteredData.count,
            aggregatedPoints: aggregatedData.count,
            strategy: strategy
        )
        
        return ProcessedChartData(
            dataPoints: aggregatedData,
            aggregationStrategy: strategy,
            period: period,
            totalRecordings: rawData.count,
            dateRange: dateRange,
            samplingInfo: samplingInfo
        )
    }
    
    // MARK: - Period Filtering
    private func filterDataByPeriod(_ data: [VoiceCharacteristicsDataPoint], period: ChartPeriod) -> [VoiceCharacteristicsDataPoint] {
        guard period != .all else { return data }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -period.days, to: endDate) ?? endDate
        
        return data.filter { dataPoint in
            dataPoint.timestamp >= startDate && dataPoint.timestamp <= endDate
        }
    }
    
    // MARK: - Aggregation Strategy Determination
    private func determineAggregationStrategy(for dataCount: Int, period: ChartPeriod) -> AggregationStrategy {
        switch period {
        case .week:
            return dataCount <= 20 ? .individual : .daily
        case .month:
            return dataCount <= 50 ? .daily : .weekly
        case .all:
            if dataCount <= 100 { return .monthly }
            else { return .monthly } // For extreme cases, stick to monthly
        }
    }
    
    // MARK: - Aggregation Application
    private func applyAggregationStrategy(_ data: [VoiceCharacteristicsDataPoint], strategy: AggregationStrategy) -> [VoiceCharacteristicsDataPoint] {
        switch strategy {
        case .individual:
            return data.sorted { $0.timestamp < $1.timestamp }
            
        case .daily:
            return aggregateByDay(data)
            
        case .weekly:
            return aggregateByWeek(data)
            
        case .monthly:
            return aggregateByMonth(data)
        }
    }
    
    // MARK: - Daily Aggregation
    private func aggregateByDay(_ data: [VoiceCharacteristicsDataPoint]) -> [VoiceCharacteristicsDataPoint] {
        // Safety check
        guard !data.isEmpty else { return [] }
        
        let groupedData = Dictionary(grouping: data) { dataPoint in
            Calendar.current.startOfDay(for: dataPoint.timestamp)
        }
        
        let aggregatedPoints = groupedData.map { (date, points) -> VoiceCharacteristicsDataPoint in
            let jitterValues = points.compactMap { $0.jitter }
            let shimmerValues = points.compactMap { $0.shimmer }
            
            let avgJitter = jitterValues.isEmpty ? 0 : jitterValues.reduce(0, +) / Double(jitterValues.count)
            let avgShimmer = shimmerValues.isEmpty ? 0 : shimmerValues.reduce(0, +) / Double(shimmerValues.count)
            
            return VoiceCharacteristicsDataPoint(
                timestamp: date,
                pitch: 0.0,
                energy: 0.0,
                spectralCentroid: 0.0,
                jitter: avgJitter,
                shimmer: avgShimmer,
                formantFrequencies: nil,
                harmonicToNoiseRatio: nil,
                zeroCrossingRate: nil,
                spectralRolloff: nil,
                voiceOnsetTime: nil,
                emotion: .neutral,
                confidence: 1.0
            )
        }
        
        return aggregatedPoints.sorted { $0.timestamp < $1.timestamp }
    }
    
         // MARK: - Weekly Aggregation
     private func aggregateByWeek(_ data: [VoiceCharacteristicsDataPoint]) -> [VoiceCharacteristicsDataPoint] {
         // Safety check
         guard !data.isEmpty else { return [] }
         
         let groupedData = Dictionary(grouping: data) { dataPoint in
             let calendar = Calendar.current
             let weekOfYear = calendar.component(.weekOfYear, from: dataPoint.timestamp)
             let year = calendar.component(.year, from: dataPoint.timestamp)
             let components = DateComponents(weekOfYear: weekOfYear, yearForWeekOfYear: year)
             return calendar.date(from: components) ?? dataPoint.timestamp
         }
         
         let aggregatedPoints = groupedData.map { (weekStart, points) -> VoiceCharacteristicsDataPoint in
             let jitterValues = points.compactMap { $0.jitter }
             let shimmerValues = points.compactMap { $0.shimmer }
             
             let avgJitter = jitterValues.isEmpty ? 0 : jitterValues.reduce(0, +) / Double(jitterValues.count)
             let avgShimmer = shimmerValues.isEmpty ? 0 : shimmerValues.reduce(0, +) / Double(shimmerValues.count)
             
             return VoiceCharacteristicsDataPoint(
                 timestamp: weekStart,
                 pitch: 0.0,
                 energy: 0.0,
                 spectralCentroid: 0.0,
                 jitter: avgJitter,
                 shimmer: avgShimmer,
                 formantFrequencies: nil,
                 harmonicToNoiseRatio: nil,
                 zeroCrossingRate: nil,
                 spectralRolloff: nil,
                 voiceOnsetTime: nil,
                 emotion: .neutral,
                 confidence: 1.0
             )
         }
         
         return aggregatedPoints.sorted { $0.timestamp < $1.timestamp }
     }
    
         // MARK: - Monthly Aggregation
     private func aggregateByMonth(_ data: [VoiceCharacteristicsDataPoint]) -> [VoiceCharacteristicsDataPoint] {
         // Safety check
         guard !data.isEmpty else { return [] }
         
         let groupedData = Dictionary(grouping: data) { dataPoint in
             let calendar = Calendar.current
             let month = calendar.component(.month, from: dataPoint.timestamp)
             let year = calendar.component(.year, from: dataPoint.timestamp)
             let components = DateComponents(year: year, month: month)
             return calendar.date(from: components) ?? dataPoint.timestamp
         }
         
         let aggregatedPoints = groupedData.map { (monthStart, points) -> VoiceCharacteristicsDataPoint in
             let jitterValues = points.compactMap { $0.jitter }
             let shimmerValues = points.compactMap { $0.shimmer }
             
             let avgJitter = jitterValues.isEmpty ? 0 : jitterValues.reduce(0, +) / Double(jitterValues.count)
             let avgShimmer = shimmerValues.isEmpty ? 0 : shimmerValues.reduce(0, +) / Double(shimmerValues.count)
             
             return VoiceCharacteristicsDataPoint(
                 timestamp: monthStart,
                 pitch: 0.0,
                 energy: 0.0,
                 spectralCentroid: 0.0,
                 jitter: avgJitter,
                 shimmer: avgShimmer,
                 formantFrequencies: nil,
                 harmonicToNoiseRatio: nil,
                 zeroCrossingRate: nil,
                 spectralRolloff: nil,
                 voiceOnsetTime: nil,
                 emotion: .neutral,
                 confidence: 1.0
             )
         }
         
         return aggregatedPoints.sorted { $0.timestamp < $1.timestamp }
     }
    

    
    // MARK: - Helper Functions
    private func calculateDateRange(from data: [VoiceCharacteristicsDataPoint]) -> ClosedRange<Date> {
        guard !data.isEmpty,
              let firstDate = data.first?.timestamp,
              let lastDate = data.last?.timestamp else {
            return Date()...Date()
        }
        return firstDate...lastDate
    }
    
    private func generateSamplingInfo(totalRecordings: Int, filteredRecordings: Int, aggregatedPoints: Int, strategy: AggregationStrategy) -> String {
        if totalRecordings == filteredRecordings {
            return "Showing \(aggregatedPoints) \(strategy.description.lowercased()) from \(totalRecordings) recordings"
        } else {
            let periodInfo = filteredRecordings == totalRecordings ? "all available" : "last \(filteredRecordings) days"
            return "Showing \(aggregatedPoints) \(strategy.description.lowercased()) from \(periodInfo) (\(totalRecordings) total recordings)"
        }
    }
}
