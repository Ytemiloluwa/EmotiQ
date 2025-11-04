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
            
            let publisher = self.voiceRecordingService.startRecording()
                .mapError { $0 as Error }
                .flatMap { [weak self] _ -> AnyPublisher<TimeInterval, Error> in
                    guard let self = self else {
                        return Fail(error: EmotionAnalysisError.serviceUnavailable).eraseToAnyPublisher()
                    }
                    return self.voiceRecordingService.recordingDuration
                        .filter { $0 >= 3.0 }
                        .first()
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                .flatMap { [weak self] _ -> AnyPublisher<URL, Error> in
                    guard let self = self else {
                        return Fail(error: EmotionAnalysisError.serviceUnavailable).eraseToAnyPublisher()
                    }
                    return self.voiceRecordingService.stopRecording()
                        .mapError { $0 as Error }
                        .eraseToAnyPublisher()
                }
                .flatMap { [weak self] recordingURL -> AnyPublisher<(URL, VoiceQuality), Error> in
                    guard let self = self else {
                        return Fail(error: EmotionAnalysisError.serviceUnavailable).eraseToAnyPublisher()
                    }
                    return self.voiceRecordingService.validateAudioQuality(url: recordingURL)
                        .map { quality in (recordingURL, quality) }
                        .eraseToAnyPublisher()
                }
                .flatMap { [weak self] (recordingURL, _) -> AnyPublisher<EmotionalData, Error> in
                    guard let self = self else {
                        return Fail(error: EmotionAnalysisError.serviceUnavailable).eraseToAnyPublisher()
                    }
                    return Future<EmotionalData, Error> { [weak self] promise in
                        guard let self = self else {
                            promise(.failure(EmotionAnalysisError.serviceUnavailable))
                            return
                        }
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
                                promise(.failure(emotionError))
                            } catch let voiceError as VoiceRecordingError {
                                promise(.failure(voiceError))
                            } catch let audioError as AudioProcessingError {
                                promise(.failure(audioError))
                            } catch {
                                let analysisError = EmotionAnalysisError.analysisFailure(error.localizedDescription)
                                promise(.failure(analysisError))
                            }
                        }
                    }
                    .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()

            let cancellable = publisher
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

            self.cancellables.insert(cancellable)
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

            return nil
        }
        
        // Enhanced conversion: Use the new fromProductionFeatures method for complete data preservation
        let voiceFeatures = VoiceFeatures.fromProductionFeatures(audioFeatures)
        
        
        return voiceFeatures
    }
    
    // MARK: - Real-Time Analysis
    
    /// Starts real-time speech analysis during recording
    /// NOTE: Temporarily disabled due to local speech recognition issues
    func startRealTimeSpeechAnalysis() async throws -> AsyncStream<EmotionalData> {
    
        
        // TEMPORARY: Return empty stream since live speech recognition is disabled
        // This will be re-enabled once we resolve the local speech recognition issues
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    /// Stops real-time speech analysis
    func stopRealTimeSpeechAnalysis() {
  
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



