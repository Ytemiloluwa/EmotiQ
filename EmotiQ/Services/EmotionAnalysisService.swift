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
}

class EmotionAnalysisService: EmotionAnalysisServiceProtocol {
    private let audioProcessingService = AudioProcessingService()
    private let emotionService = CoreMLEmotionService.shared
    
    func startVoiceRecording() -> AnyPublisher<EmotionalData, Error> {
        return Future { [weak self] promise in
            Task {
                do {
                    let audioURL = try await self?.audioProcessingService.startRecording() ?? URL(fileURLWithPath: "")
                    let result = try await self?.emotionService.analyzeEmotion(from: audioURL) ?? EmotionAnalysisResult(
                        timestamp: Date(),
                        primaryEmotion: .neutral,
                        confidence: 0.0,
                        emotionScores: [:],
                        audioQuality: .poor,
                        sessionDuration: 0.0
                    )
                    
                    let emotionalData = EmotionalData(
                        timestamp: result.timestamp,
                        primaryEmotion: self?.convertEmotionCategoryToType(result.primaryEmotion) ?? .neutral,
                        confidence: result.confidence,
                        intensity: result.confidence,
                        voiceFeatures: nil,
                        context: self?.createEmotionalContext()
                    )
                    
                    promise(.success(emotionalData))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func analyzeEmotion(from audioURL: URL) -> AnyPublisher<EmotionalData, Error> {
        return Future { [weak self] promise in
            Task {
                do {
                    let result = try await self?.emotionService.analyzeEmotion(from: audioURL) ?? EmotionAnalysisResult(
                        timestamp: Date(),
                        primaryEmotion: .neutral,
                        confidence: 0.0,
                        emotionScores: [:],
                        audioQuality: .poor,
                        sessionDuration: 0.0
                    )
                    
                    let emotionalData = EmotionalData(
                        timestamp: result.timestamp,
                        primaryEmotion: self?.convertEmotionCategoryToType(result.primaryEmotion) ?? .neutral,
                        confidence: result.confidence,
                        intensity: result.confidence,
                        voiceFeatures: nil,
                        context: self?.createEmotionalContext()
                    )
                    
                    promise(.success(emotionalData))
                } catch {
                    promise(.failure(error))
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
    
    private func convertEmotionCategoryToType(_ category: EmotionCategory) -> EmotionType {
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
}


