//
//  VoiceRecordingViewModel.swift
//  EmotiQ
//
//  Created by Temiloluwa on 07-08-2025.
//

import Foundation
import Combine
import SwiftUI

class VoiceRecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var recordingQuality: VoiceQuality = .good
    @Published var hasRecording = false
    @Published var isLoading = false
    @Published var showError = false
    @Published var showPermissionAlert = false
    @Published var errorMessage = ""
    
    private let voiceRecordingService: VoiceRecordingServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentRecordingURL: URL?
    
    init(voiceRecordingService: VoiceRecordingServiceProtocol = VoiceRecordingService(),
         subscriptionService: SubscriptionServiceProtocol = SubscriptionService()) {
        self.voiceRecordingService = voiceRecordingService
        self.subscriptionService = subscriptionService
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind recording state
        voiceRecordingService.isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        // Bind recording duration
        voiceRecordingService.recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: \.recordingDuration, on: self)
            .store(in: &cancellables)
        
        // Bind audio levels
        voiceRecordingService.audioLevels
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioLevel, on: self)
            .store(in: &cancellables)
        
        // Bind recording quality
        voiceRecordingService.recordingQuality
            .receive(on: DispatchQueue.main)
            .assign(to: \.recordingQuality, on: self)
            .store(in: &cancellables)
    }
    
    func requestPermissionIfNeeded() {
        voiceRecordingService.requestPermission()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] granted in
                    if !granted {
                        self?.showPermissionAlert = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func startRecording() {
        // Check subscription limits
        guard subscriptionService.canPerformVoiceAnalysis() else {
            showError(message: "Daily limit reached. Upgrade to Premium for unlimited access.")
            return
        }
        
        isLoading = true
        
        voiceRecordingService.startRecording()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.showError(message: error.localizedDescription)
                    }
                },
                receiveValue: { _ in
                    if Config.isDebugMode {
                        print("🎤 Recording started successfully")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func stopRecording() {
        isLoading = true
        
        voiceRecordingService.stopRecording()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.showError(message: error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] url in
                    self?.currentRecordingURL = url
                    self?.hasRecording = true
                    
                    if Config.isDebugMode {
                        print("🎤 Recording saved: \(url.lastPathComponent)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func cancelRecording() {
        voiceRecordingService.cancelRecording()
        hasRecording = false
        currentRecordingURL = nil
    }
    
    func processRecording() {
        guard let url = currentRecordingURL else {
            showError(message: "No recording found")
            return
        }
        
        isLoading = true
        
        // Validate audio quality first
        voiceRecordingService.validateAudioQuality(url: url)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.showError(message: error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] quality in
                    if quality.isAcceptable {
                        self?.proceedWithAnalysis(url: url, quality: quality)
                    } else {
                        self?.showError(message: "Audio quality is too low. Please try recording again in a quieter environment.")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func proceedWithAnalysis(url: URL, quality: VoiceQuality) {
        // Increment daily usage for free users
        subscriptionService.incrementDailyUsage()
        
        // TODO: Proceed to emotion analysis
        if Config.isDebugMode {
            print(" Proceeding with emotion analysis for recording with \(quality.displayName) quality")
        }
        
        // For now, just show success
        // In the next phase, this will integrate with EmotionAnalysisService
    }
    
    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        
        if Config.isDebugMode {
            print("Voice Recording Error: \(message)")
        }
    }
}
