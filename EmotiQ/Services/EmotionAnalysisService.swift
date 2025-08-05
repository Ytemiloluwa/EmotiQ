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
    func analyzeEmotion(from audioData: Data) -> AnyPublisher<EmotionalData, Error>
}

class EmotionAnalysisService: EmotionAnalysisServiceProtocol {
    private let audioProcessingService = AudioProcessingService()
    private let coreMLService = CoreMLService()
    
    func startVoiceRecording() -> AnyPublisher<EmotionalData, Error> {
        return audioProcessingService.recordAudio(duration: 5.0)
            .flatMap { [weak self] audioData -> AnyPublisher<EmotionalData, Error> in
                guard let self = self else {
                    return Fail(error: EmotionAnalysisError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                return self.analyzeEmotion(from: audioData)
            }
            .eraseToAnyPublisher()
    }
    
    func analyzeEmotion(from audioData: Data) -> AnyPublisher<EmotionalData, Error> {
        return audioProcessingService.extractFeatures(from: audioData)
            .flatMap { [weak self] features -> AnyPublisher<EmotionalData, Error> in
                guard let self = self else {
                    return Fail(error: EmotionAnalysisError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                
                return self.coreMLService.predictEmotion(from: features)
                    .map { prediction in
                        EmotionalData(
                            primaryEmotion: prediction.emotion,
                            confidence: prediction.confidence,
                            intensity: prediction.intensity,
                            voiceFeatures: VoiceFeatures(
                                pitch: features.pitch,
                                energy: features.energy,
                                tempo: features.tempo,
                                spectralCentroid: features.spectralCentroid,
                                mfccCoefficients: features.mfccCoefficients
                            ),
                            context: self.createEmotionalContext()
                        )
                    }
                    .eraseToAnyPublisher()
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
}

enum EmotionAnalysisError: Error, LocalizedError {
    case recordingFailed
    case analysisTimeout
    case serviceUnavailable
    case invalidAudioData
    
    var errorDescription: String? {
        switch self {
        case .recordingFailed:
            return "Failed to record audio. Please check microphone permissions."
        case .analysisTimeout:
            return "Emotion analysis timed out. Please try again."
        case .serviceUnavailable:
            return "Emotion analysis service is currently unavailable."
        case .invalidAudioData:
            return "Invalid audio data received."
        }
    }
}


