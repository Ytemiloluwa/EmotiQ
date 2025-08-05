//
//  ContentViewModel.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation

class ContentViewModel: BaseViewModel {
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var dailyCheckInsRemaining: Int = 3
    @Published var emotionalData: [EmotionalData] = []
    
    private let subscriptionService = SubscriptionService()
    private let emotionAnalysisService = EmotionAnalysisService()
    
    override init() {
        super.init()
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        subscriptionService.subscriptionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.subscriptionStatus = status
                self?.updateDailyLimits()
            }
            .store(in: &cancellables)
    }
    
    func loadUserData() {
        setLoading(true)
        
        // Load subscription status
        subscriptionService.checkSubscriptionStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.setLoading(false)
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] status in
                    self?.subscriptionStatus = status
                    self?.updateDailyLimits()
                }
            )
            .store(in: &cancellables)
    }
    
    func startVoiceAnalysis() {
        guard canPerformAnalysis() else {
            errorMessage = "Daily limit reached. Upgrade to Premium for unlimited analysis."
            return
        }
        
        setLoading(true)
        
        emotionAnalysisService.startVoiceRecording()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.setLoading(false)
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] emotionalData in
                    self?.emotionalData.append(emotionalData)
                    self?.decrementDailyUsage()
                }
            )
            .store(in: &cancellables)
    }
    
    func showInsights() {
        // Navigate to insights view
        print("Showing emotional insights...")
    }
    
    private func canPerformAnalysis() -> Bool {
        switch subscriptionStatus {
        case .free:
            return dailyCheckInsRemaining > 0
        case .premium, .pro:
            return true
        }
    }
    
    private func updateDailyLimits() {
        switch subscriptionStatus {
        case .free:
            dailyCheckInsRemaining = max(0, 3 - getTodayUsageCount())
        case .premium, .pro:
            dailyCheckInsRemaining = -1 // Unlimited
        }
    }
    
    private func decrementDailyUsage() {
        if subscriptionStatus == .free && dailyCheckInsRemaining > 0 {
            dailyCheckInsRemaining -= 1
        }
    }
    
    private func getTodayUsageCount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return emotionalData.filter { data in
            Calendar.current.isDate(data.timestamp, inSameDayAs: today)
        }.count
    }
}

