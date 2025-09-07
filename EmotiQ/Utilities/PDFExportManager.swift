//
//  PDFExportManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import SwiftUI
import PDFKit
import Charts

@MainActor
class PDFExportManager: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: String?
    
    // MARK: - Main Export Function
    func exportInsightsToPDF(viewModel: InsightsViewModel) async -> URL? {
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        do {
            let pdfURL = try await generateInsightsPDF(viewModel: viewModel)
            isExporting = false
            exportProgress = 1.0
            return pdfURL
        } catch {
            isExporting = false
            exportError = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - PDF Generation
    private func generateInsightsPDF(viewModel: InsightsViewModel) async throws -> URL {
        // Debug: Log the data we're working with
        print("🔍 PDF Export Debug:")
        print("   Total Check-ins: \(viewModel.totalCheckIns)")
        print("   Weekly Check-ins: \(viewModel.weeklyCheckIns)")
        print("   Voice Characteristics Data count: \(viewModel.voiceCharacteristicsData.count)")
        print("   Voice Insights count: \(viewModel.voiceInsights.count)")
        print("   Emotion Intensity Data count: \(viewModel.emotionIntensityData.count)")
        print("   Emotion Distribution count: \(viewModel.emotionDistribution.count)")
        print("   Weekly Pattern Data count: \(viewModel.weeklyPatternData.count)")
        
        for (index, insight) in viewModel.voiceInsights.enumerated() {
            print("   Voice Insight \(index + 1): \(insight.title) - \(insight.description)")
        }
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // US Letter size
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "EmotiQ_Insights_\(DateFormatter.pdfFileName.string(from: Date())).pdf"
        let pdfURL = documentsPath.appendingPathComponent(fileName)
        
        try pdfRenderer.writePDF(to: pdfURL) { context in
            // Page 1: Overview and Summary
            context.beginPage()
            exportProgress = 0.2
            drawTitlePage(context: context, viewModel: viewModel)
            
            // Page 2: Emotion Trends Chart
            context.beginPage()
            exportProgress = 0.4
            drawEmotionTrendsPage(context: context, viewModel: viewModel)
            
            // Page 3: Distribution and Weekly Patterns
            context.beginPage()
            exportProgress = 0.6
            drawDistributionAndPatternsPage(context: context, viewModel: viewModel)
            
            // Page 4: Voice Characteristics and Data Tables
            context.beginPage()
            exportProgress = 0.8
            drawVoiceCharacteristicsAndDataPage(context: context, viewModel: viewModel)
            
            exportProgress = 1.0
        }
        
        return pdfURL
    }
    
    // MARK: - Page Drawing Functions
    
    private func drawTitlePage(context: UIGraphicsPDFRendererContext, viewModel: InsightsViewModel) {
        let bounds = context.pdfContextBounds
        
        // Title
        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.systemPurple
        ]
        
        let title = "EmotiQ Emotional Insights Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (bounds.width - titleSize.width) / 2,
            y: 50,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Date range
        let dateFont = UIFont.systemFont(ofSize: 16, weight: .medium)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: UIColor.systemGray
        ]
        
        let dateRange = "Report Period: \(viewModel.selectedPeriod.displayName)"
        let dateSize = dateRange.size(withAttributes: dateAttributes)
        let dateRect = CGRect(
            x: (bounds.width - dateSize.width) / 2,
            y: titleRect.maxY + 10,
            width: dateSize.width,
            height: dateSize.height
        )
        dateRange.draw(in: dateRect, withAttributes: dateAttributes)
        
        // Overview Statistics
        let statsY = dateRect.maxY + 40
        drawOverviewStats(context: context, viewModel: viewModel, startY: statsY)
        
        // Summary Section
        let summaryY = statsY + 200
        drawSummarySection(context: context, viewModel: viewModel, startY: summaryY)
    }
    
    private func drawOverviewStats(context: UIGraphicsPDFRendererContext, viewModel: InsightsViewModel, startY: CGFloat) {
        let bounds = context.pdfContextBounds
        let cardWidth: CGFloat = 150
        let cardHeight: CGFloat = 120
        let spacing: CGFloat = 30
        let totalWidth = (cardWidth * 3) + (spacing * 2)
        let startX = (bounds.width - totalWidth) / 2
        
        let stats = [
            ("Weekly Check-ins", "\(viewModel.weeklyCheckIns)", "checkmark.circle.fill"),
            ("Average Mood", viewModel.averageMood.displayName, "heart.fill"),
            ("Current Streak", "\(viewModel.currentStreak) days", "flame.fill")
        ]
        
        for (index, stat) in stats.enumerated() {
            let cardRect = CGRect(
                x: startX + (CGFloat(index) * (cardWidth + spacing)),
                y: startY,
                width: cardWidth,
                height: cardHeight
            )
            
            drawStatCard(context: context, rect: cardRect, title: stat.0, value: stat.1, icon: stat.2)
        }
    }
    
    private func drawStatCard(context: UIGraphicsPDFRendererContext, rect: CGRect, title: String, value: String, icon: String) {
        // Card background
        context.cgContext.setFillColor(UIColor.systemGray6.cgColor)
        context.cgContext.fill(rect)
        
        // Card border
        context.cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
        context.cgContext.setLineWidth(1)
        context.cgContext.stroke(rect)
        
        // Icon (simplified as text for PDF)
        let iconFont = UIFont.systemFont(ofSize: 24, weight: .medium)
        let iconAttributes: [NSAttributedString.Key: Any] = [
            .font: iconFont,
            .foregroundColor: UIColor.systemBlue
        ]
        
        let iconText = "●" // Simple bullet as icon placeholder
        let iconSize = iconText.size(withAttributes: iconAttributes)
        let iconRect = CGRect(
            x: rect.midX - iconSize.width / 2,
            y: rect.minY + 15,
            width: iconSize.width,
            height: iconSize.height
        )
        iconText.draw(in: iconRect, withAttributes: iconAttributes)
        
        // Value
        let valueFont = UIFont.systemFont(ofSize: 18, weight: .bold)
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.label
        ]
        
        let valueSize = value.size(withAttributes: valueAttributes)
        let valueRect = CGRect(
            x: rect.midX - valueSize.width / 2,
            y: iconRect.maxY + 10,
            width: valueSize.width,
            height: valueSize.height
        )
        value.draw(in: valueRect, withAttributes: valueAttributes)
        
        // Title
        let titleFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: rect.midX - titleSize.width / 2,
            y: valueRect.maxY + 5,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
    }
    
    private func drawSummarySection(context: UIGraphicsPDFRendererContext, viewModel: InsightsViewModel, startY: CGFloat) {
        let bounds = context.pdfContextBounds
        
        // Section title
        let sectionFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: sectionFont,
            .foregroundColor: UIColor.label
        ]
        
        let sectionTitle = "Summary"
        let sectionRect = CGRect(x: 50, y: startY, width: bounds.width - 100, height: 30)
        sectionTitle.draw(in: sectionRect, withAttributes: sectionAttributes)
        
        // Summary content
        let contentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: contentFont,
            .foregroundColor: UIColor.label
        ]
        
        let summaryText = generateSummaryText(viewModel: viewModel)
        let contentRect = CGRect(x: 50, y: startY + 40, width: bounds.width - 100, height: 200)
        summaryText.draw(in: contentRect, withAttributes: contentAttributes)
    }
    
    private func drawEmotionTrendsPage(context: UIGraphicsPDFRendererContext, viewModel: InsightsViewModel) {
        let bounds = context.pdfContextBounds
        
        // Page title
        drawPageTitle(context: context, title: "Emotion Intensity Trends", y: 50)
        
        // Render actual chart
        let chartRect = CGRect(x: 50, y: 100, width: bounds.width - 100, height: 300)
        if let chartImage = ChartToPDFRenderer.renderEmotionTrendsChart(
            data: viewModel.emotionIntensityData,
            uniqueEmotions: viewModel.uniqueEmotions,
            size: chartRect.size
        ) {
            chartImage.draw(in: chartRect)
        } else {
            drawChartPlaceholder(context: context, rect: chartRect, title: "Emotion Trends Over Time")
        }
        
        // Data table
        let tableY = chartRect.maxY + 30
        drawEmotionTrendsTable(context: context, viewModel: viewModel, startY: tableY)
    }
    
    private func drawDistributionAndPatternsPage(context: UIGraphicsPDFRendererContext, viewModel: InsightsViewModel) {
        let bounds = context.pdfContextBounds
        
        // Page title
        drawPageTitle(context: context, title: "Emotion Distribution & Weekly Patterns", y: 50)
        
        // Distribution chart
        let distributionRect = CGRect(x: 50, y: 100, width: (bounds.width - 150) / 2, height: 250)
        if let distributionImage = ChartToPDFRenderer.renderEmotionDistributionChart(
            data: viewModel.emotionDistribution,
            size: distributionRect.size
        ) {
            distributionImage.draw(in: distributionRect)
        } else {
            drawChartPlaceholder(context: context, rect: distributionRect, title: "Emotion Distribution")
        }
        
        // Weekly patterns chart
        let patternsRect = CGRect(x: distributionRect.maxX + 50, y: 100, width: (bounds.width - 150) / 2, height: 250)
        if let patternsImage = ChartToPDFRenderer.renderWeeklyPatternsChart(
            data: viewModel.weeklyPatternData,
            size: patternsRect.size
        ) {
            patternsImage.draw(in: patternsRect)
        } else {
            drawChartPlaceholder(context: context, rect: patternsRect, title: "Weekly Patterns")
        }
        
        // Distribution data
        let distributionTableY = distributionRect.maxY + 30
        drawDistributionTable(context: context, viewModel: viewModel, startY: distributionTableY)
    }
    
    private func drawVoiceCharacteristicsAndDataPage(context: UIGraphicsPDFRendererContext, viewModel: InsightsViewModel) {
        let bounds = context.pdfContextBounds
        
        // Page title
        drawPageTitle(context: context, title: "Voice Characteristics & Analysis", y: 50)
        
        // Voice Stability Chart
        let chartRect = CGRect(x: 50, y: 100, width: bounds.width - 100, height: 250)
        if let chartImage = ChartToPDFRenderer.renderVoiceStabilityChart(
            data: viewModel.voiceCharacteristicsData,
            size: chartRect.size
        ) {
            chartImage.draw(in: chartRect)
        } else {
            drawChartPlaceholder(context: context, rect: chartRect, title: "Voice Stability Analysis")
        }
        
        // Voice Insights Cards
        let insightsRect = CGRect(x: 50, y: chartRect.maxY + 30, width: bounds.width - 100, height: 200)
        if let insightsImage = ChartToPDFRenderer.renderVoiceInsightsCards(
            insights: viewModel.voiceInsights,
            size: insightsRect.size
        ) {
            insightsImage.draw(in: insightsRect)
        } else {
            drawChartPlaceholder(context: context, rect: insightsRect, title: "Voice Analysis Insights")
        }
        
        // Additional metrics
        let metricsY = insightsRect.maxY + 30
        drawAdditionalMetrics(context: context, viewModel: viewModel, startY: metricsY)
    }
    
    // MARK: - Helper Drawing Functions
    
    private func drawPageTitle(context: UIGraphicsPDFRendererContext, title: String, y: CGFloat) {
        let bounds = context.pdfContextBounds
        let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.systemPurple
        ]
        
        let titleRect = CGRect(x: 50, y: y, width: bounds.width - 100, height: 30)
        title.draw(in: titleRect, withAttributes: titleAttributes)
    }
    
    private func drawChartPlaceholder(context: UIGraphicsPDFRendererContext, rect: CGRect, title: String) {
        // Chart background
        context.cgContext.setFillColor(UIColor.systemGray6.cgColor)
        context.cgContext.fill(rect)
        
        // Chart border
        context.cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
        context.cgContext.setLineWidth(1)
        context.cgContext.stroke(rect)
        
        // Chart title
        let titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.label
        ]
        
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: rect.midX - titleSize.width / 2,
            y: rect.minY + 10,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Placeholder text
        let placeholderFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let placeholderAttributes: [NSAttributedString.Key: Any] = [
            .font: placeholderFont,
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        let placeholder = "[Chart visualization would appear here]"
        let placeholderSize = placeholder.size(withAttributes: placeholderAttributes)
        let placeholderRect = CGRect(
            x: rect.midX - placeholderSize.width / 2,
            y: rect.midY - placeholderSize.height / 2,
            width: placeholderSize.width,
            height: placeholderSize.height
        )
        placeholder.draw(in: placeholderRect, withAttributes: placeholderAttributes)
    }
    
    private func drawEmotionTrendsTable(context: UIGraphicsPDFRendererContext, viewModel: InsightsViewModel, startY: CGFloat) {
        let bounds = context.pdfContextBounds
        
        // Table title
        let tableFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let tableAttributes: [NSAttributedString.Key: Any] = [
            .font: tableFont,
            .foregroundColor: UIColor.label
        ]
        
        let tableTitle = "Recent Emotion Data"
        let tableTitleRect = CGRect(x: 50, y: startY, width: bounds.width - 100, height: 25)
        tableTitle.draw(in: tableTitleRect, withAttributes: tableAttributes)
        
        // Table headers
        let headerFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.label
        ]
        
        let headers = ["Date", "Emotion", "Intensity", "Confidence"]
        let columnWidth = (bounds.width - 100) / 4
        let headerY = startY + 35
        
        for (index, header) in headers.enumerated() {
            let headerRect = CGRect(
                x: 50 + (CGFloat(index) * columnWidth),
                y: headerY,
                width: columnWidth,
                height: 20
            )
            header.draw(in: headerRect, withAttributes: headerAttributes)
        }
        
        // Table data
        let dataFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let dataAttributes: [NSAttributedString.Key: Any] = [
            .font: dataFont,
            .foregroundColor: UIColor.label
        ]
        
        let recentData = Array(viewModel.emotionIntensityData.suffix(10))
        for (rowIndex, dataPoint) in recentData.enumerated() {
            let rowY = headerY + 25 + (CGFloat(rowIndex) * 20)
            
            let rowData = [
                DateFormatter.shortDate.string(from: dataPoint.timestamp),
                dataPoint.emotion.displayName,
                String(format: "%.1f", dataPoint.intensity),
                String(format: "%.0f%%", dataPoint.confidence * 100)
            ]
            
            for (colIndex, data) in rowData.enumerated() {
                let cellRect = CGRect(
                    x: 50 + (CGFloat(colIndex) * columnWidth),
                    y: rowY,
                    width: columnWidth,
                    height: 20
                )
                data.draw(in: cellRect, withAttributes: dataAttributes)
            }
        }
    }
    
    private func drawDistributionTable(context: UIGraphicsPDFRendererContext, viewModel: InsightsViewModel, startY: CGFloat) {
        let bounds = context.pdfContextBounds
        
        // Table title
        let tableFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let tableAttributes: [NSAttributedString.Key: Any] = [
            .font: tableFont,
            .foregroundColor: UIColor.label
        ]
        
        let tableTitle = "Emotion Distribution"
        let tableTitleRect = CGRect(x: 50, y: startY, width: bounds.width - 100, height: 25)
        tableTitle.draw(in: tableTitleRect, withAttributes: tableAttributes)
        
        // Distribution data
        let dataFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let dataAttributes: [NSAttributedString.Key: Any] = [
            .font: dataFont,
            .foregroundColor: UIColor.label
        ]
        
        for (index, distribution) in viewModel.emotionDistribution.enumerated() {
            let rowY = startY + 35 + (CGFloat(index) * 25)
            let text = "\(distribution.emotion.displayName): \(Int(distribution.percentage))%"
            let textRect = CGRect(x: 50, y: rowY, width: bounds.width - 100, height: 20)
            text.draw(in: textRect, withAttributes: dataAttributes)
        }
    }
    

    

    

    
    private func drawAdditionalMetrics(context: UIGraphicsPDFRendererContext, viewModel: InsightsViewModel, startY: CGFloat) {
        let bounds = context.pdfContextBounds
        
        // Section title
        let sectionFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: sectionFont,
            .foregroundColor: UIColor.label
        ]
        
        let sectionTitle = "Additional Metrics"
        let sectionRect = CGRect(x: 50, y: startY, width: bounds.width - 100, height: 25)
        sectionTitle.draw(in: sectionRect, withAttributes: sectionAttributes)
        
        // Metrics
        let metricFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let metricAttributes: [NSAttributedString.Key: Any] = [
            .font: metricFont,
            .foregroundColor: UIColor.label
        ]
        
        var metrics: [String] = []
        
        // Always include basic metrics
        metrics.append("Total Check-ins: \(viewModel.totalCheckIns)")
        metrics.append("Weekly Check-ins: \(viewModel.weeklyCheckIns)")
        metrics.append("Current Streak: \(viewModel.currentStreak) days")
        
        // Add emotion-based metrics if available
        if viewModel.totalCheckIns > 0 {
            metrics.append("Most Common Emotion: \(viewModel.mostCommonEmotion.displayName)")
            metrics.append("Average Mood: \(viewModel.averageMood.displayName)")
            metrics.append("Emotional Stability: \(viewModel.emotionalStability)")
            metrics.append("Best Day: \(viewModel.bestDay)")
            metrics.append("Growth Area: \(viewModel.growthArea)")
            metrics.append("Emotional Valence: \(viewModel.emotionalValence.displayName)")
            metrics.append("Average Intensity: \(viewModel.averageIntensity.IntensitydisplayName)")
        } else {
            metrics.append("No emotional data available yet")
            metrics.append("Start recording your emotions to see detailed metrics")
        }
        
        for (index, metric) in metrics.enumerated() {
            let metricY = startY + 35 + (CGFloat(index) * 25)
            let metricRect = CGRect(x: 50, y: metricY, width: bounds.width - 100, height: 20)
            metric.draw(in: metricRect, withAttributes: metricAttributes)
        }
    }
    
    // MARK: - Helper Functions
    
    private func generateSummaryText(viewModel: InsightsViewModel) -> String {
        return """
        This report provides a comprehensive overview of your emotional patterns and trends over the selected period.
        
        Key Highlights:
        • You've completed \(viewModel.weeklyCheckIns) emotional check-ins this week
        • Your average emotional state has been \(viewModel.averageMood.displayName.lowercased())
        • You're currently on a \(viewModel.currentStreak)-day streak of consistent tracking
        • Your emotional stability is rated as \(viewModel.emotionalStability.lowercased())
        
        The following pages contain detailed visualizations and insights to help you understand your emotional wellbeing journey.
        """
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let pdfFileName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}
