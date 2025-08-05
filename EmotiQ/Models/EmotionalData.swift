//
//  EmotionData.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation

struct EmotionalData: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let primaryEmotion: EmotionType
    let confidence: Double
    let intensity: Double
    let voiceFeatures: VoiceFeatures?
    let context: EmotionalContext?
    
    init(
        timestamp: Date = Date(),
        primaryEmotion: EmotionType,
        confidence: Double,
        intensity: Double,
        voiceFeatures: VoiceFeatures? = nil,
        context: EmotionalContext? = nil
    ) {
        self.timestamp = timestamp
        self.primaryEmotion = primaryEmotion
        self.confidence = confidence
        self.intensity = intensity
        self.voiceFeatures = voiceFeatures
        self.context = context
    }
}

struct VoiceFeatures: Codable {
    let pitch: Double
    let energy: Double
    let tempo: Double
    let spectralCentroid: Double
    let mfccCoefficients: [Double]
    
    init(
        pitch: Double,
        energy: Double,
        tempo: Double,
        spectralCentroid: Double,
        mfccCoefficients: [Double]
    ) {
        self.pitch = pitch
        self.energy = energy
        self.tempo = tempo
        self.spectralCentroid = spectralCentroid
        self.mfccCoefficients = mfccCoefficients
    }
}

struct EmotionalContext: Codable {
    let timeOfDay: String
    let dayOfWeek: String
    let location: String?
    let activity: String?
    let notes: String?
    
    init(
        timeOfDay: String = "",
        dayOfWeek: String = "",
        location: String? = nil,
        activity: String? = nil,
        notes: String? = nil
    ) {
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.location = location
        self.activity = activity
        self.notes = notes
    }
}

extension EmotionalData {
    static let sampleData: [EmotionalData] = [
        EmotionalData(
            timestamp: Date().addingTimeInterval(-3600),
            primaryEmotion: .joy,
            confidence: 0.85,
            intensity: 0.7,
            voiceFeatures: VoiceFeatures(
                pitch: 220.0,
                energy: 0.8,
                tempo: 1.2,
                spectralCentroid: 1500.0,
                mfccCoefficients: [1.2, 0.8, 0.5, 0.3, 0.2]
            ),
            context: EmotionalContext(
                timeOfDay: "Morning",
                dayOfWeek: "Monday",
                activity: "Coffee break"
            )
        ),
        EmotionalData(
            timestamp: Date().addingTimeInterval(-7200),
            primaryEmotion: .neutral,
            confidence: 0.92,
            intensity: 0.4,
            voiceFeatures: VoiceFeatures(
                pitch: 180.0,
                energy: 0.5,
                tempo: 1.0,
                spectralCentroid: 1200.0,
                mfccCoefficients: [0.8, 0.6, 0.4, 0.2, 0.1]
            ),
            context: EmotionalContext(
                timeOfDay: "Evening",
                dayOfWeek: "Sunday",
                activity: "Relaxing"
            )
        )
    ]
}


