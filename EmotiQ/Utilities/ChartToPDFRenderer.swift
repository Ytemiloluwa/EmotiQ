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
    
    // MARK: - Full View Screenshot Approach
    
    static func captureEntireInsightsView(
        viewModel: InsightsViewModel,
        size: CGSize = CGSize(width: 612, height: 3000)
    ) -> UIImage? {

        
        let pdfWidth: CGFloat = 612
        let spacing: CGFloat = 20
        let padding: CGFloat = 20
        let contentWidth = pdfWidth - (padding * 2)
        
        // Render each section at the PDF content width and use actual heights
        var sectionImages: [UIImage] = []
        
        if let overview = renderViewToImage(InsightsOverviewSection(
            weeklyCheckIns: viewModel.weeklyCheckIns,
            averageMood: viewModel.averageMood,
            currentStreak: viewModel.currentStreak
        ), targetWidth: contentWidth) {
            sectionImages.append(overview)
        }
        // Voice quality metrics only (avoid duplicating sub-sections)
        if let voiceQuality = renderViewToImage(VoiceQualityMetricsView(data: viewModel.voiceCharacteristicsData), targetWidth: contentWidth) {
            sectionImages.append(voiceQuality)
        }
        if let pitchEnergy = renderViewToImage(PitchEnergyTrendsChart(data: viewModel.voiceCharacteristicsData), targetWidth: contentWidth) {
            sectionImages.append(pitchEnergy)
        }
        if let emotionTrends = renderViewToImage(EmotionTrendsChart(data: viewModel.emotionIntensityData, uniqueEmotions: viewModel.uniqueEmotions), targetWidth: contentWidth) {
            sectionImages.append(emotionTrends)
        }
        if let emotionDist = renderViewToImage(EmotionDistributionChart(data: viewModel.emotionDistribution), targetWidth: contentWidth) {
            sectionImages.append(emotionDist)
        }
        if let weekly = renderViewToImage(WeeklyPatternsChart(data: viewModel.weeklyPatternData), targetWidth: contentWidth) {
            sectionImages.append(weekly)
        }
        if let insights = renderViewToImage(VoiceInsightsCards(insights: viewModel.voiceInsights), targetWidth: contentWidth) {
            sectionImages.append(insights)
        }
        if let today = renderViewToImage(TodaySummarySection(
            emotionalValence: viewModel.emotionalValence,
            mostCommonEmotion: viewModel.mostCommonEmotion,
            averageIntensity: viewModel.averageIntensity
        ), targetWidth: contentWidth) {
            sectionImages.append(today)
        }
        
        // Compute final canvas height
        let totalHeight = padding + sectionImages.reduce(0) { $0 + $1.size.height } + spacing * CGFloat(max(sectionImages.count - 1, 0)) + padding
        let canvasSize = CGSize(width: pdfWidth, height: max(totalHeight, 1))
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let combined = renderer.image { context in
            context.cgContext.setFillColor(UIColor.systemBackground.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: canvasSize))
            
            var currentY: CGFloat = padding
            for image in sectionImages {
                let rect = CGRect(x: padding, y: currentY, width: contentWidth, height: image.size.height)
                image.draw(in: rect)
                currentY += image.size.height + spacing
            }
        }
        
        return combined
    }

    // MARK: - Section Images (for page-aware PDF pagination)
    static func captureSectionImages(
        viewModel: InsightsViewModel,
        contentWidth: CGFloat
    ) -> [UIImage] {
        var images: [UIImage] = []
        if let overview = renderViewToImage(InsightsOverviewSection(
            weeklyCheckIns: viewModel.weeklyCheckIns,
            averageMood: viewModel.averageMood,
            currentStreak: viewModel.currentStreak
        ), targetWidth: contentWidth) { images.append(overview) }
        if let voiceQuality = renderViewToImage(VoiceQualityMetricsView(data: viewModel.voiceCharacteristicsData), targetWidth: contentWidth) {
            images.append(voiceQuality)
        }
        if let pitchEnergy = renderViewToImage(PitchEnergyTrendsChart(data: viewModel.voiceCharacteristicsData), targetWidth: contentWidth) { images.append(pitchEnergy) }
        if let emotionTrends = renderViewToImage(EmotionTrendsChart(data: viewModel.emotionIntensityData, uniqueEmotions: viewModel.uniqueEmotions), targetWidth: contentWidth) { images.append(emotionTrends) }
        if let emotionDist = renderViewToImage(EmotionDistributionChart(data: viewModel.emotionDistribution), targetWidth: contentWidth) { images.append(emotionDist) }
        if let weekly = renderViewToImage(WeeklyPatternsChart(data: viewModel.weeklyPatternData), targetWidth: contentWidth) { images.append(weekly) }
        if let insights = renderViewToImage(VoiceInsightsCards(insights: viewModel.voiceInsights), targetWidth: contentWidth) { images.append(insights) }
        if let today = renderViewToImage(TodaySummarySection(
            emotionalValence: viewModel.emotionalValence,
            mostCommonEmotion: viewModel.mostCommonEmotion,
            averageIntensity: viewModel.averageIntensity
        ), targetWidth: contentWidth) { images.append(today) }
        return images
    }
    
    // MARK: - Individual Chart Rendering Functions
    
    static func renderEmotionTrendsChart(
        viewModel: InsightsViewModel,
        size: CGSize
    ) -> UIImage? {
        
        let chartView = EmotionTrendsChart(
            data: viewModel.emotionIntensityData,
            uniqueEmotions: viewModel.uniqueEmotions
        )
        let result = renderSwiftUIView(chartView, size: size)
        
        return result
    }
    
    static func renderEmotionDistributionChart(
        viewModel: InsightsViewModel,
        size: CGSize
    ) -> UIImage? {
        
        let chartView = EmotionDistributionChart(data: viewModel.emotionDistribution)
        let result = renderSwiftUIView(chartView, size: size)
        
        return result
    }
    
    static func renderWeeklyPatternsChart(
        viewModel: InsightsViewModel,
        size: CGSize
    ) -> UIImage? {
        
        let chartView = WeeklyPatternsChart(data: viewModel.weeklyPatternData)
        let result = renderSwiftUIView(chartView, size: size)
        
        return result
    }
    
    static func renderVoiceCharacteristicsSection(
        viewModel: InsightsViewModel,
        size: CGSize
    ) -> UIImage? {
        
        let chartView = VoiceCharacteristicsSection(
            data: viewModel.voiceCharacteristicsData,
            insights: viewModel.voiceInsights
        )
        let result = renderSwiftUIView(chartView, size: size)
        
        return result
    }
    
    static func renderVoiceQualityMetrics(
        data: [VoiceCharacteristicsDataPoint],
        size: CGSize
    ) -> UIImage? {
        
        let chartView = VoiceQualityMetricsView(data: data)
        let result = renderSwiftUIView(chartView, size: size)
        
        return result
    }
    
    static func renderPitchEnergyTrendsChart(
        data: [VoiceCharacteristicsDataPoint],
        size: CGSize
    ) -> UIImage? {
        
        let chartView = PitchEnergyTrendsChart(data: data)
            .frame(height: 300)
        let result = renderSwiftUIView(chartView, size: size)
        
        return result
    }
    
    static func renderVoiceInsightsCards(
        insights: [VoiceInsight],
        size: CGSize
    ) -> UIImage? {
        
        let chartView = VoiceInsightsCards(insights: insights)
        let result = renderSwiftUIView(chartView, size: size)
        
        return result
    }
    
    static func renderInsightsOverviewSection(
        viewModel: InsightsViewModel,
        size: CGSize
    ) -> UIImage? {
        
        let chartView = InsightsOverviewSection(
            weeklyCheckIns: viewModel.weeklyCheckIns,
            averageMood: viewModel.averageMood,
            currentStreak: viewModel.currentStreak
        )
        let result = renderSwiftUIView(chartView, size: size)
        
        return result
    }
    
    static func renderTodaySummarySection(
        viewModel: InsightsViewModel,
        size: CGSize
    ) -> UIImage? {
        
        let chartView = TodaySummarySection(
            emotionalValence: viewModel.emotionalValence,
            mostCommonEmotion: viewModel.mostCommonEmotion,
            averageIntensity: viewModel.averageIntensity
        )
        let result = renderSwiftUIView(chartView, size: size)
        
        return result
    }
    
    // MARK: - SwiftUI to UIImage Conversion
    
    private static func renderSwiftUIView<Content: View>(
        _ content: Content,
        size: CGSize
    ) -> UIImage? {
        // Legacy method retained for compatibility where explicit height is desired
        let controller = UIHostingController(rootView: content)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = UIColor.systemBackground
        let renderer = UIGraphicsImageRenderer(size: size)
        let result = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        return result
    }

    // New: Render using ImageRenderer with measured height
    private static func renderViewToImage<V: View>(
        _ view: V,
        targetWidth: CGFloat
    ) -> UIImage? {
        let content = view
            .environment(\.colorScheme, .light)
            .frame(width: targetWidth)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.white)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        #if os(iOS)
        renderer.isOpaque = true
        #endif
        return renderer.uiImage
    }
}

