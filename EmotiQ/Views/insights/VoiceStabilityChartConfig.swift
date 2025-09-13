//
//  VoiceStabilityChartConfig.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import SwiftUI

// MARK: - Chart Configuration Constants
struct VoiceStabilityChartConfig {
    
    // MARK: - Chart Dimensions
    struct Dimensions {
        static let baseHeight: CGFloat = 200
        static let expandedHeight: CGFloat = 300
        static let compactHeight: CGFloat = 150
        static let maxHeight: CGFloat = 400
        
        // Dynamic height based on data density
        static func chartHeight(for dataCount: Int, period: ChartPeriod) -> CGFloat {
            switch period {
            case .week:
                return dataCount <= 10 ? compactHeight : baseHeight
            case .month:
                return dataCount <= 20 ? baseHeight : expandedHeight
            case .all:
                return maxHeight
            }
        }
    }
    
    // MARK: - Y-Axis Scaling
    struct YAxisScaling {
        static let minScale: Double = 0.01      // 1% minimum
        static let maxScale: Double = 0.20      // 20% maximum
        static let defaultScale: Double = 0.05  // 5% default
        
        // Dynamic scaling based on data range
        static func calculateScale(for maxValue: Double, dataCount: Int) -> Double {
            let baseScale = max(maxValue * 1.5, minScale)
            
            // Adjust scale based on data density
            let densityFactor: Double
            if dataCount <= 10 { densityFactor = 1.2 }
            else if dataCount <= 50 { densityFactor = 1.5 }
            else if dataCount <= 100 { densityFactor = 1.8 }
            else { densityFactor = 2.0 }
            
            let adjustedScale = baseScale * densityFactor
            return min(max(adjustedScale, minScale), maxScale)
        }
    }
    
    // MARK: - Threshold Configuration
    struct Thresholds {
        static let calmMultiplier: Double = 1.5
        static let normalMultiplier: Double = 2.5
        static let expressiveMultiplier: Double = 4.0
        
        // Dynamic threshold calculation
        static func calculateThresholds(for maxValue: Double) -> (calm: Double, normal: Double, expressive: Double) {
            let calm = maxValue * calmMultiplier
            let normal = maxValue * normalMultiplier
            let expressive = maxValue * expressiveMultiplier
            
            return (calm: calm, normal: normal, expressive: expressive)
        }
    }
    
    // MARK: - X-Axis Configuration
    struct XAxisConfig {
        static let maxVisibleLabels = 12
        
        // Smart label spacing based on data density
        static func labelStride(for dataCount: Int, period: ChartPeriod) -> Calendar.Component {
            switch period {
            case .week:
                return dataCount <= 7 ? .day : .day
            case .month:
                return dataCount <= 15 ? .day : .weekOfMonth
            case .all:
                return .month
            }
        }
        
        // Date formatting based on period
        static func dateFormat(for period: ChartPeriod) -> String {
            switch period {
            case .week: return "E"           // Mon, Tue, Wed
            case .month: return "d"          // 1, 2, 3
            case .all: return "MMM yyyy"     // Jan 2025, Feb 2025
            }
        }
        
        // Chart stride values for proper X-axis labeling
        static func chartStride(for period: ChartPeriod, dataCount: Int) -> Double {
            switch period {
            case .week:
                return dataCount <= 7 ? 1.0 : 1.0  // Daily marks for week
            case .month:
                return dataCount <= 15 ? 1.0 : 7.0  // Daily for low data, weekly for high data
            case .all:
                return 30.0  // Monthly marks for all time
            }
        }
    }
    
    // MARK: - Performance Configuration
    struct Performance {
        static let maxDataPointsForRealTime = 100
        static let backgroundProcessingThreshold = 500
        static let cacheExpirationHours: TimeInterval = 24 * 60 * 60 // 24 hours
        
        // Determine if background processing is needed
        static func needsBackgroundProcessing(dataCount: Int) -> Bool {
            return dataCount > backgroundProcessingThreshold
        }
    }
    
    // MARK: - Visual Configuration
    struct Visual {
        static let lineWidth: CGFloat = 2.0
        static let areaOpacity: Double = 0.1
        static let thresholdOpacity: Double = 0.6
        static let gridOpacity: Double = 0.2
        
        // Colors
        static let jitterColor = Color.blue
        static let shimmerColor = Color.green
        static let calmThresholdColor = Color.blue
        static let normalThresholdColor = Color.green
        static let expressiveThresholdColor = Color.purple
        
        // Threshold line styles
        static let thresholdLineStyle = StrokeStyle(lineWidth: 1.5, dash: [8, 4])
    }
    
    // MARK: - Padding and Spacing
    struct Spacing {
        static let chartPadding: CGFloat = 20
        static let axisLabelPadding: CGFloat = 40
        static let legendSpacing: CGFloat = 12
        static let thresholdSpacing: CGFloat = 20
    }
}
