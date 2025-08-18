//
//  VoiceRecordingViewModel.swift
//  EmotiQ
//
//  Created by Temiloluwa on 07-08-2025.
//

import Foundation
import SwiftUI
import Combine

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
        
        // Request permissions first, then start recording
        voiceRecordingService.requestPermission()
            .mapError { _ in VoiceRecordingError.permissionDenied }
            .flatMap { granted -> AnyPublisher<Void, VoiceRecordingError> in
                if granted {
                    return self.voiceRecordingService.startRecording()
                } else {
                    return Fail(error: VoiceRecordingError.permissionDenied).eraseToAnyPublisher()
                }
            }
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
            showError(message: "No recording found. Please record your voice first.")
            return
        }
        
        // Check if we're already processing
        guard !isLoading else {
            if Config.isDebugMode {
                print("⚠️ Analysis already in progress, ignoring duplicate request")
            }
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
                        self?.showError(message: "Audio validation failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] quality in
                    if quality.isAcceptable {
                        if Config.isDebugMode {
                            print("✅ Audio quality validated: \(quality.displayName)")
                        }
                        self?.proceedWithAnalysis(url: url, quality: quality)
                    } else {
                        self?.isLoading = false
                        self?.showError(message: "Audio quality is too low (\(quality.displayName)). Please try recording again in a quieter environment with clear speech.")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func proceedWithAnalysis(url: URL, quality: VoiceQuality) {
        // Increment daily usage for free users
        subscriptionService.incrementDailyUsage()
        
        isLoading = true
        
        // Use the production-ready CoreMLEmotionService for emotion analysis
        Task {
            do {
                // Analyze emotion using the comprehensive CoreMLEmotionService
                let result = try await CoreMLEmotionService.shared.analyzeEmotion(from: url)
                
                await MainActor.run {
                    self.isLoading = false
                    
                    // Store the result in the shared service for persistence
                    CoreMLEmotionService.shared.lastAnalysisResult = result
                    
                    // Post notification with the analysis result
                    NotificationCenter.default.post(
                        name: .recordingCompleted,
                        object: result,
                        userInfo: ["audioQuality": quality]
                    )
                    
                    // Log successful analysis for debugging
                    if Config.isDebugMode {
                        print("🎤 Emotion analysis completed successfully")
                        print("📊 Primary emotion: \(result.primaryEmotion.displayName)")
                        print("🎯 Confidence: \(String(format: "%.1f%%", result.confidence * 100))")
                        print("⏱️ Session duration: \(String(format: "%.1f", result.sessionDuration))s")
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    
                    // Handle specific error types
                    let errorMessage: String
                    if let emotionError = error as? EmotionAnalysisError {
                        errorMessage = emotionError.localizedDescription
                    } else {
                        errorMessage = "Emotion analysis failed: \(error.localizedDescription)"
                    }
                    
                    self.showError(message: errorMessage)
                    
                    // Log error for debugging
                    if Config.isDebugMode {
                        print("❌ Emotion analysis failed: \(error)")
                    }
                }
            }
        }
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
            print("❌ Voice Recording Error: \(message)")
        }
    }
}
