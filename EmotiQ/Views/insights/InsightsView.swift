//
//  InsightsView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//


import SwiftUI
import Charts
import CoreData

// MARK: - Insights View
/// Production-ready insights and analytics view with emotion visualization
/// Provides comprehensive emotional intelligence tracking and trends
struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @StateObject private var pdfExportManager = PDFExportManager()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var showingSubscriptionPaywall = false
    @State private var showingShareSheet = false
    @State private var pdfURL: URL?
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.cyan.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // TODO: Re-enable paywall check when InsightsView is production ready
                // if subscriptionService.hasActiveSubscription {
                
                    // Premium insights content
                    ScrollView {
                        VStack(spacing: 20) {
                            // MARK: - Overview Cards
                            InsightsOverviewSection(viewModel: viewModel)
                            
                            // MARK: - Voice Characteristics Analysis
                            VoiceCharacteristicsSection(viewModel: viewModel)
                            
                            // MARK: - Emotion Trends Chart
                            EmotionTrendsChart(viewModel: viewModel)
                            
                            // MARK: - Emotion Distribution
                            EmotionDistributionChart(viewModel: viewModel)
                            
                            // MARK: - Weekly Patterns
                            WeeklyPatternsChart(viewModel: viewModel)
                            
                            // MARK: - Weekly Summary
                            TodaySummarySection(viewModel: viewModel)
                            
                            
                            Spacer(minLength: 100) // Tab bar spacing
                        }
                        .padding(.horizontal)
                    }
                
                // TODO: Re-enable premium feature locked state
                // } else {
                //     // Premium feature locked state
                //     PremiumFeatureLockedView {
                //         showingSubscriptionPaywall = true
                //     }
                // }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await exportToPDF()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if pdfExportManager.isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text(pdfExportManager.isExporting ? "Exporting..." : "Export")
                                .font(.caption)
                        }
                        .foregroundColor(pdfExportManager.isExporting ? .secondary : .primary)
                    }
                    .disabled(!subscriptionService.hasDataExport())
                    .help(subscriptionService.hasDataExport() ? "Export all charts and insights data as a PDF report" : "Upgrade to Pro to export data")
                }
            }
            // TODO: Re-enable subscription paywall sheet when InsightsView is production ready
            // .sheet(isPresented: $showingSubscriptionPaywall) {
            //     SubscriptionPaywallView()
            // }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfURL = pdfURL {
                    ShareSheet(activityItems: [pdfURL])
                }
            }
            .alert("Export Error", isPresented: .constant(pdfExportManager.exportError != nil)) {
                Button("OK") {
                    pdfExportManager.exportError = nil
                }
            } message: {
                if let error = pdfExportManager.exportError {
                    Text(error)
                }
            }
            .alert("Export Successful", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Your insights report has been exported successfully and is ready to share.")
            }
            .onAppear {
                // TODO: Re-enable subscription check when InsightsView is production ready
                // if subscriptionService.hasActiveSubscription {
                    viewModel.loadInsightsData()
                // }
            }
            .onChange(of: viewModel.selectedPeriod) {
                viewModel.refreshData()
            }
        }
    }
    
    // MARK: - PDF Export Function
    private func exportToPDF() async {
        guard let exportedURL = await pdfExportManager.exportInsightsToPDF(viewModel: viewModel) else {
            return
        }
        
        await MainActor.run {
            self.pdfURL = exportedURL
            self.showingSuccessAlert = true
            
            // Show share sheet after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showingShareSheet = true
            }
        }
    }
}

// MARK: - ShareSheet for PDF Export
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Premium Feature Locked View
struct PremiumFeatureLockedView: View {
    let upgradeAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Premium Feature")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Unlock detailed insights and analytics about your emotional patterns with Premium")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Preview features
            VStack(alignment: .leading, spacing: 12) {
                FeaturePreviewRow(icon: "chart.line.uptrend.xyaxis", title: "Emotion Trends Over Time")
                FeaturePreviewRow(icon: "chart.pie", title: "Emotion Distribution Analysis")
                FeaturePreviewRow(icon: "brain.head.profile", title: " Pattern Recognition")
                FeaturePreviewRow(icon: "calendar", title: "Weekly & Monthly Reports")
                FeaturePreviewRow(icon: "target", title: "Personalized Recommendations")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            
            Button(action: upgradeAction) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Premium")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
        }
        .padding()
    }
}

struct FeaturePreviewRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "checkmark")
                .foregroundColor(.green)
                .font(.caption)
        }
    }
}

// MARK: - Preview
struct InsightsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightsView()
            .environmentObject(SubscriptionService())
    }
}

