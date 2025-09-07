//
//  EmotionAnalysisService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation
import Combine
import AVFoundation

protocol EmotionAnalysisServiceProtocol {
    func startVoiceRecording() -> AnyPublisher<EmotionalData, Error>
    func analyzeEmotion(from audioURL: URL) -> AnyPublisher<EmotionalData, Error>
    func startRealTimeSpeechAnalysis() async throws -> AsyncStream<EmotionalData>
    func stopRealTimeSpeechAnalysis()
}

@MainActor
class EmotionAnalysisService: EmotionAnalysisServiceProtocol {
    private let audioProcessingService = AudioProcessingService()
    private let voiceRecordingService = VoiceRecordingService()
    private let emotionService = CoreMLEmotionService.shared
    private let speechAnalyzer = SpeechAnalysisService()
    private var cancellables = Set<AnyCancellable>()
    private var realTimeAnalysisTask: Task<Void, Never>?
    
    func startVoiceRecording() -> AnyPublisher<EmotionalData, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(EmotionAnalysisError.serviceUnavailable))
                return
            }
            
            // Start recording (permissions already handled by VoiceRecordingService)
            self.voiceRecordingService.startRecording()
                .mapError { $0 as Error }
                .flatMap { _ in
                    // Wait for minimum recording duration and then stop
                    self.voiceRecordingService.recordingDuration
                        .filter { $0 >= 3.0 } // Minimum 3 seconds for analysis
                        .first()
                        .flatMap { _ in
                            self.voiceRecordingService.stopRecording()
                                .mapError { $0 as Error }
                        }
                }
                .flatMap { recordingURL in
                    // Validate audio quality
                    self.voiceRecordingService.validateAudioQuality(url: recordingURL)
                        .flatMap { quality in
                            // Analyze emotion with quality information
                            Future { promise in
                                Task {
                                    do {
                                        let result = try await self.emotionService.analyzeEmotion(from: recordingURL)
                                        
                                        let emotionalData = EmotionalData(
                                            timestamp: result.timestamp,
                                            primaryEmotion: self.convertEmotionCategoryToType(result.primaryEmotion),
                                            confidence: result.confidence,
                                            intensity: result.confidence,
                                            voiceFeatures: self.createRealVoiceFeatures(from: result),
                                            context: self.createEmotionalContext()
                                        )
                                        
                                        promise(.success(emotionalData))
                                    } catch let emotionError as EmotionAnalysisError {
                                        // PRODUCTION: Handle specific emotion analysis errors
                                        promise(.failure(emotionError))
                                    } catch let voiceError as VoiceRecordingError {
                                        // PRODUCTION: Handle voice recording errors
                                        promise(.failure(voiceError))
                                    } catch let audioError as AudioProcessingError {
                                        // PRODUCTION: Handle audio processing errors
                                        promise(.failure(audioError))
                                    } catch {
                                        // PRODUCTION: Handle any other unexpected errors
                                        let analysisError = EmotionAnalysisError.analysisFailure(error.localizedDescription)
                                        promise(.failure(analysisError))
                                    }
                                }
                            }
                        }
                }
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { emotionalData in
                        promise(.success(emotionalData))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    func analyzeEmotion(from audioURL: URL) -> AnyPublisher<EmotionalData, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(EmotionAnalysisError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    // PRODUCTION: No fallback to fake data - must succeed or fail
                    let result = try await self.emotionService.analyzeEmotion(from: audioURL)
                    
                    let emotionalData = EmotionalData(
                        timestamp: result.timestamp,
                        primaryEmotion: self.convertEmotionCategoryToType(result.primaryEmotion),
                        confidence: result.confidence,
                        intensity: result.confidence,
                        voiceFeatures: self.createRealVoiceFeatures(from: result),
                        context: self.createEmotionalContext()
                    )
                    
                    promise(.success(emotionalData))
                } catch let emotionError as EmotionAnalysisError {
                    // PRODUCTION: Handle specific emotion analysis errors
                    promise(.failure(emotionError))
                } catch let voiceError as VoiceRecordingError {
                    // PRODUCTION: Handle voice recording errors
                    promise(.failure(voiceError))
                } catch let audioError as AudioProcessingError {
                    // PRODUCTION: Handle audio processing errors
                    promise(.failure(audioError))
                } catch {
                    // PRODUCTION: Handle any other unexpected errors
                    let analysisError = EmotionAnalysisError.analysisFailure(error.localizedDescription)
                    promise(.failure(analysisError))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func createEmotionalContext() -> EmotionalContext {
        let now = Date()
        let formatter = DateFormatter()
        
        formatter.dateFormat = "HH:mm"
        let timeOfDay = formatter.string(from: now)
        
        formatter.dateFormat = "EEEE"
        let dayOfWeek = formatter.string(from: now)
        
        return EmotionalContext(
            timeOfDay: timeOfDay,
            dayOfWeek: dayOfWeek
        )
    }
    
    func convertEmotionCategoryToType(_ category: EmotionCategory) -> EmotionType {
        switch category {
        case .joy: return .joy
        case .sadness: return .sadness
        case .anger: return .anger
        case .fear: return .fear
        case .surprise: return .surprise
        case .disgust: return .disgust
        case .neutral: return .neutral
        }
    }
    
    private func createRealVoiceFeatures(from result: EmotionAnalysisResult) -> VoiceFeatures? {
        // PRODUCTION: Extract real voice features from actual audio analysis
        guard let audioFeatures = result.audioFeatures else {
            print("⚠️ No audio features available for voice feature creation")
            return nil
        }
        
        // Enhanced conversion: Use the new fromProductionFeatures method for complete data preservation
        let voiceFeatures = VoiceFeatures.fromProductionFeatures(audioFeatures)
        
        // Log the enhanced conversion for debugging
        print("🎯 Enhanced voice features created from production features:")
        print("   - Core features preserved: pitch=\(voiceFeatures.pitch), energy=\(voiceFeatures.energy)")
        print("   - Enhanced features: \(voiceFeatures.featureSummary)")
        print("   - Data completeness: \(voiceFeatures.hasEnhancedFeatures ? "Enhanced" : "Basic") (\(voiceFeatures.featureCount) features)")
        
        return voiceFeatures
    }
    
    // MARK: - Real-Time Analysis
    
    /// Starts real-time speech analysis during recording
    /// NOTE: Temporarily disabled due to local speech recognition issues
    func startRealTimeSpeechAnalysis() async throws -> AsyncStream<EmotionalData> {
        print("🎤 Real-time speech analysis temporarily disabled...")
        
        // TEMPORARY: Return empty stream since live speech recognition is disabled
        // This will be re-enabled once we resolve the local speech recognition issues
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    /// Stops real-time speech analysis
    func stopRealTimeSpeechAnalysis() {
        print("⏹️ Stopping real-time analysis...")
        realTimeAnalysisTask?.cancel()
        realTimeAnalysisTask = nil
        
        Task { @MainActor in
            speechAnalyzer.stopLiveSpeechAnalysis()
        }
    }
    
    /// Converts speech analysis result to emotional data
    private func convertSpeechResultToEmotionalData(_ speechResult: SpeechEmotionResult) -> EmotionalData {
        return EmotionalData(
            timestamp: Date(),
            primaryEmotion: convertEmotionCategoryToType(speechResult.primaryEmotion),
            confidence: speechResult.confidence,
            intensity: speechResult.confidence, // Use confidence as intensity proxy
            voiceFeatures: createVoiceFeaturesFromSpeech(speechResult),
            context: createEmotionalContext()
        )
    }
    
    private func createVoiceFeaturesFromSpeech(_ speechResult: SpeechEmotionResult) -> VoiceFeatures? {
        
        return nil
        
    }
}



