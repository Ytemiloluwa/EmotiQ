//
//  ContentViewModel.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation
import Combine

class ContentViewModel: BaseViewModel {
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var dailyUsageRemaining: Int = 3
    @Published var canPerformVoiceAnalysis: Bool = true
    @Published var showUpgradePrompt: Bool = false
    @Published var showError = false
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let persistenceController: PersistenceController
    
    init(subscriptionService: SubscriptionServiceProtocol = SubscriptionService(),
         persistenceController: PersistenceController = .shared) {
        self.subscriptionService = subscriptionService
        self.persistenceController = persistenceController
        super.init()
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind subscription status
        subscriptionService.currentSubscription
            .receive(on: DispatchQueue.main)
            .assign(to: \.subscriptionStatus, on: self)
            .store(in: &cancellables)
        
        // Bind daily usage remaining
        subscriptionService.dailyUsageRemaining
            .receive(on: DispatchQueue.main)
            .assign(to: \.dailyUsageRemaining, on: self)
            .store(in: &cancellables)
        
        // Update voice analysis availability
        Publishers.CombineLatest(
            subscriptionService.currentSubscription,
            subscriptionService.dailyUsageRemaining
        )
        .map { subscription, remaining in
            subscription != .free || remaining > 0
        }
        .receive(on: DispatchQueue.main)
        .assign(to: \.canPerformVoiceAnalysis, on: self)
        .store(in: &cancellables)
        
        // Monitor daily usage reset notifications
        NotificationCenter.default.publisher(for: .dailyUsageReset)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Refresh daily usage when reset is detected
                self?.subscriptionService.refreshDailyUsage()
              
            }
            .store(in: &cancellables)
    }
    
    func loadInitialData() {
        isLoading = true
        
        // Ensure user exists in Core Data
        let _ = persistenceController.createUserIfNeeded()
        
        // Refresh daily usage to check for daily reset
        subscriptionService.refreshDailyUsage()
        
        // Check subscription status
        subscriptionService.checkSubscriptionStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { status in

                }
            )
            .store(in: &cancellables)
    }
    
    func startVoiceAnalysis() {
        guard canPerformVoiceAnalysis else {
            showUpgradePrompt = true
            return
        }
        
        
        // Voice recording will be handled by VoiceRecordingView
        // This method is kept for compatibility but the actual navigation
        // is handled in ContentView through the sheet presentation
    }
    
    func showInsights() {
        
        // TODO: Navigate to insights view
        // This will be implemented in the next phase
    }
    
    internal override func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        
    }
}

