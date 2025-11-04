//
//  InsightsView.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//


import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @StateObject private var pdfExportManager = ScreenshotPDFExportManager()
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var showingSubscriptionPaywall = false
    @State private var showingShareSheet = false
    @State private var pdfURL: URL?
    @State private var showingSuccessAlert = false
    @State private var showProToast = false
    @State private var isExportPressed = false

    @EnvironmentObject private var themeManager: ThemeManager
    
    let showBackButton: Bool
        
    init(showBackButton: Bool = false) {
        self.showBackButton = showBackButton
    }
    
    var body: some View {
        
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    mainContent
                }
            } else {
                NavigationView {
                    mainContent
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
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

    // MARK: - Main Content (shared for NavigationView/NavigationStack)
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            
            ThemeColors.primaryBackground
            
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    InsightsOverviewSection(
                        weeklyCheckIns: viewModel.weeklyCheckIns,
                        averageMood: viewModel.averageMood,
                        currentStreak: viewModel.currentStreak
                    )
                    VoiceCharacteristicsSection(
                        data: viewModel.voiceCharacteristicsData,
                        insights: viewModel.voiceInsights
                    )
        
                    EmotionTrendsChart(
                        data: viewModel.emotionIntensityData,
                        uniqueEmotions: viewModel.uniqueEmotions
                    )
                    EmotionDistributionChart(data: viewModel.emotionDistribution)
                    WeeklyPatternsChart(data: viewModel.weeklyPatternData)

                    TodaySummarySection(
                        emotionalValence: viewModel.emotionalValence,
                        mostCommonEmotion: viewModel.mostCommonEmotion,
                        averageIntensity: viewModel.averageIntensity
                    )
                    Spacer(minLength: 100)
                }
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
            
            if showProToast {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("This feature is only for Pro users")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .shadow(radius: 8)
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showProToast)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showBackButton)
        .toolbar(content: {
            
            if showBackButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(ThemeColors.accent)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if subscriptionService.hasDataExport() {
                        HapticManager.shared.buttonPress(.primary)
                        Task {
                            await exportToPDF()
                        }
                    } else {
                        showProToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showProToast = false
                        }
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
                    .scaleEffect(isExportPressed ? 0.96 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isExportPressed)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isExportPressed { isExportPressed = true }
                    }
                    .onEnded { _ in
                        isExportPressed = false
                    }
                )
                .help(subscriptionService.hasDataExport() ? "Export all charts and insights data as a PDF report" : "Upgrade to Pro to export data")
            }
        })
    }
    
    // MARK: - PDF Export Function
    
    private func exportToPDF() async {
        await MainActor.run {
            viewModel.refreshData()
        }
        
        // Wait for data to be processed and UI to update
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Force another refresh to ensure data is current
        await MainActor.run {
            viewModel.refreshData()
        }
        
        // Additional wait for data processing
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard let exportedURL = await pdfExportManager.exportInsightsToPDF(viewModel: viewModel) else { return }
    
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
            .environmentObject(ThemeManager())
    }
}

