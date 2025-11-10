//
//  ScreenShotPDFExportManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 11-09-2025.
//

import Foundation
import SwiftUI

@MainActor
class ScreenshotPDFExportManager: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: String?
    
    // MARK: - Main Export Function
    func exportInsightsToPDF(viewModel: InsightsViewModel) async -> URL? {
        
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        do {
            exportProgress = 0.3
            
            // Capture sections individually for page-aware pagination
            let pageWidth: CGFloat = 612
            let margin: CGFloat = 36
            let contentWidth = pageWidth - (margin * 2)
            let sectionImages = ChartToPDFRenderer.captureSectionImages(viewModel: viewModel, contentWidth: contentWidth)
            guard !sectionImages.isEmpty else { throw PDFExportError.captureFailure }
            exportProgress = 0.6
            
            // Convert section images to PDF with section-aware pagination
            let pdfURL = try await createPDFFromSections(sectionImages, viewModel: viewModel)
        
            
            isExporting = false
            exportProgress = 1.0
            return pdfURL
            
        } catch {
            isExporting = false
            exportError = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - PDF Creation from Image
    private func createPDFFromSections(_ sections: [UIImage], viewModel: InsightsViewModel) async throws -> URL {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 36
        let headerHeight: CGFloat = 50
        let contentWidth = pageWidth - (margin * 2)
        let contentHeightPerPage = pageHeight - (margin * 2) - headerHeight
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "EmotiQ_Insights_\(DateFormatter.pdfFileName.string(from: Date())).pdf"
        let pdfURL = documentsPath.appendingPathComponent(fileName)
        
        // Pre-compute total pages by simulating placement
        var pages: [[UIImage]] = [[]]
        var remaining = contentHeightPerPage
        for image in sections {
            let scaledHeight = image.size.height * (contentWidth / image.size.width)
            if scaledHeight <= remaining {
                pages[pages.count - 1].append(image)
                remaining -= scaledHeight
            } else {
                pages.append([image])
                remaining = contentHeightPerPage - scaledHeight
            }
        }
        let totalPages = pages.count
        
        try pdfRenderer.writePDF(to: pdfURL) { context in
            for (index, imagesOnPage) in pages.enumerated() {
                context.beginPage()
                drawPageHeader(context: context, pageNumber: index + 1, totalPages: totalPages, viewModel: viewModel)
                var y: CGFloat = margin + headerHeight
                for img in imagesOnPage {
                    let scaledHeight = img.size.height * (contentWidth / img.size.width)
                    let rect = CGRect(x: margin, y: y, width: contentWidth, height: scaledHeight)
                    img.draw(in: rect)
                    y += scaledHeight
                }
            
            }
        }
        
        return pdfURL
    }
    
    // MARK: - Helper Functions
    private func drawPageHeader(context: UIGraphicsPDFRendererContext, pageNumber: Int, totalPages: Int, viewModel: InsightsViewModel) {
        let bounds = context.pdfContextBounds
        
        // Title
        let titleFont = UIFont.systemFont(ofSize: 18, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.systemPurple
        ]
        
        let title = "EmotiQ Insights Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (bounds.width - titleSize.width) / 2,
            y: 20,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Page number
        let pageFont = UIFont.systemFont(ofSize: 10, weight: .regular)
        let pageAttributes: [NSAttributedString.Key: Any] = [
            .font: pageFont,
            .foregroundColor: UIColor.systemGray
        ]
        
        let pageText = "Page \(pageNumber) of \(totalPages)"
        let pageSize = pageText.size(withAttributes: pageAttributes)
        let pageRect = CGRect(
            x: bounds.width - pageSize.width - 36,
            y: 20,
            width: pageSize.width,
            height: pageSize.height
        )
        pageText.draw(in: pageRect, withAttributes: pageAttributes)
        
        // Date
        let dateText = DateFormatter.shortDate.string(from: Date())
        let dateSize = dateText.size(withAttributes: pageAttributes)
        let dateRect = CGRect(
            x: 36,
            y: 20,
            width: dateSize.width,
            height: dateSize.height
        )
        dateText.draw(in: dateRect, withAttributes: pageAttributes)
        
        // Separator line
        context.cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
        context.cgContext.setLineWidth(0.5)
        context.cgContext.move(to: CGPoint(x: 36, y: 45))
        context.cgContext.addLine(to: CGPoint(x: bounds.width - 36, y: 45))
        context.cgContext.strokePath()
    }
}

// MARK: - Error Types
enum PDFExportError: LocalizedError {
    case captureFailure
    
    var errorDescription: String? {
        switch self {
        case .captureFailure:
            return "Failed to capture the insights view"
        }
    }
}

// MARK: - Date Formatter Extension
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
