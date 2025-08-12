//
//  CoreMLService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation
import Combine
import CoreML

protocol CoreMLServiceProtocol {
    func predictEmotion(from features: AudioFeatures) -> AnyPublisher<EmotionPrediction, Error>
}

class CoreMLService: CoreMLServiceProtocol {
    
    func predictEmotion(from features: AudioFeatures) -> AnyPublisher<EmotionPrediction, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                // For now, we'll use a simple rule-based approach
                // In production, this would use a trained CoreML model
                let prediction = self.simulateEmotionPrediction(from: features)
                promise(.success(prediction))
                
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func simulateEmotionPrediction(from features: AudioFeatures) -> EmotionPrediction {
        // Simple rule-based emotion detection for MVP
        // This will be replaced with actual CoreML model
        
        let energy = features.energy
        let pitch = features.pitch
        let tempo = features.tempo
        
        var emotion: EmotionType
        var confidence: Double
        var intensity: Double
        
        // Basic emotion detection logic
        if energy > 0.7 && pitch > 200 {
            emotion = .joy
            confidence = 0.8
            intensity = energy
        } else if energy < 0.3 && pitch < 150 {
            emotion = .sadness
            confidence = 0.75
            intensity = 1.0 - energy
        } else if energy > 0.8 && tempo > 1.3 {
            emotion = .anger
            confidence = 0.7
            intensity = energy
        } else if pitch > 250 && tempo > 1.2 {
            emotion = .surprise
            confidence = 0.65
            intensity = (energy + tempo) / 2
        } else if energy < 0.4 && tempo < 0.8 {
            emotion = .fear
            confidence = 0.6
            intensity = 1.0 - energy
        } else {
            emotion = .neutral
            confidence = 0.9
            intensity = 0.5
        }
        
        return EmotionPrediction(
            emotion: emotion,
            confidence: confidence,
            intensity: intensity,
            alternativeEmotions: generateAlternativeEmotions(primary: emotion)
        )
    }
    
    private func generateAlternativeEmotions(primary: EmotionType) -> [EmotionPrediction.AlternativeEmotion] {
        let allEmotions = EmotionType.allCases.filter { $0 != primary }
        return allEmotions.prefix(2).map { emotion in
            EmotionPrediction.AlternativeEmotion(
                emotion: emotion,
                confidence: Double.random(in: 0.1...0.4)
            )
        }
    }
}

struct EmotionPrediction {
    let emotion: EmotionType
    let confidence: Double
    let intensity: Double
    let alternativeEmotions: [AlternativeEmotion]
    
    struct AlternativeEmotion {
        let emotion: EmotionType
        let confidence: Double
    }
}

enum CoreMLError: Error, LocalizedError {
    case modelNotFound
    case predictionFailed
    case invalidInput
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Emotion analysis model not found."
        case .predictionFailed:
            return "Failed to predict emotion from audio."
        case .invalidInput:
            return "Invalid audio features provided."
        }
    }
}

// MARK: - Audio Features Model
struct AudioFeatures {
    let pitch: Double
    let energy: Double
    let tempo: Double
    let spectralCentroid: Double
    let mfccCoefficients: [Double]
    
    // For CoreML compatibility
    var mfcc: [Float] {
        return mfccCoefficients.map { Float($0) }
    }
    
    var spectralRolloff: Float { Float(spectralCentroid * 0.85) }
    var zeroCrossingRate: Float { Float(energy * 0.5) }
    var rms: Float { Float(energy) }
    var harmonicity: Float { Float(tempo) }
    
    var featureVector: [Float] {
        return mfcc + [Float(spectralCentroid), spectralRolloff, zeroCrossingRate, rms, Float(pitch), harmonicity]
    }
}
