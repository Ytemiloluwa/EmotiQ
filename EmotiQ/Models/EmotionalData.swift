//
//  EmotionData.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

import Foundation

// MARK: - Real User Voice Analysis Data Model
/// Represents the result of analyzing a user's voice recording for emotions
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

// MARK: - Voice Features from Real Audio Analysis
/// Contains actual voice characteristics extracted from user recordings
/// Enhanced with critical features for better emotion analysis and historical data preservation
struct VoiceFeatures: Codable {
    // Core features (existing)
    let pitch: Double
    let energy: Double
    let tempo: Double
    let spectralCentroid: Double
    let mfccCoefficients: [Double]
    
    // Enhanced features for better emotion analysis (NEW)
    let jitter: Double?              // Voice instability - critical for stress/anxiety detection
    let shimmer: Double?             // Amplitude variation - important for voice quality assessment
    let formantFrequencies: [Double]? // Vocal tract characteristics - most important for emotion distinction
    let harmonicToNoiseRatio: Double? // Voice quality indicator - important for emotional stability
    let zeroCrossingRate: Double?    // Temporal characteristics - moderate importance
    let spectralRolloff: Double?     // Spectral characteristics - important for surprise/anger
    let voiceOnsetTime: Double?      // Timing characteristics - important for hesitation detection
    
    init(
        pitch: Double,
        energy: Double,
        tempo: Double,
        spectralCentroid: Double,
        mfccCoefficients: [Double],
        jitter: Double? = nil,
        shimmer: Double? = nil,
        formantFrequencies: [Double]? = nil,
        harmonicToNoiseRatio: Double? = nil,
        zeroCrossingRate: Double? = nil,
        spectralRolloff: Double? = nil,
        voiceOnsetTime: Double? = nil
    ) {
        self.pitch = pitch
        self.energy = energy
        self.tempo = tempo
        self.spectralCentroid = spectralCentroid
        self.mfccCoefficients = mfccCoefficients
        self.jitter = jitter
        self.shimmer = shimmer
        self.formantFrequencies = formantFrequencies
        self.harmonicToNoiseRatio = harmonicToNoiseRatio
        self.zeroCrossingRate = zeroCrossingRate
        self.spectralRolloff = spectralRolloff
        self.voiceOnsetTime = voiceOnsetTime
    }
    
    /// Creates VoiceFeatures from ProductionAudioFeatures with complete data preservation
    static func fromProductionFeatures(_ production: ProductionAudioFeatures) -> VoiceFeatures {
        // Convert core features
        let pitch = Double(production.pitch)
        let energy = Double(production.energy)
        let tempo = calculateTempoFromFeatures(production)
        let spectralCentroid = Double(production.spectralCentroid)
        let mfccCoefficients = production.mfccCoefficients.map { Double($0) }
        
        // Convert enhanced features
        let jitter = Double(production.jitter)
        let shimmer = Double(production.shimmer)
        let formantFrequencies = production.formantFrequencies.map { Double($0) }
        let harmonicToNoiseRatio = Double(production.harmonicToNoiseRatio)
        let zeroCrossingRate = Double(production.zeroCrossingRate)
        let spectralRolloff = Double(production.spectralRolloff)
        let voiceOnsetTime = Double(production.voiceOnsetTime)
        
        return VoiceFeatures(
            pitch: pitch,
            energy: energy,
            tempo: tempo,
            spectralCentroid: spectralCentroid,
            mfccCoefficients: mfccCoefficients,
            jitter: jitter,
            shimmer: shimmer,
            formantFrequencies: formantFrequencies,
            harmonicToNoiseRatio: harmonicToNoiseRatio,
            zeroCrossingRate: zeroCrossingRate,
            spectralRolloff: spectralRolloff,
            voiceOnsetTime: voiceOnsetTime
        )
    }
    
    /// Calculates tempo from available features when not directly available
    private static func calculateTempoFromFeatures(_ features: ProductionAudioFeatures) -> Double {
        // Estimate tempo from zero crossing rate and energy variations
        let baseTempo = Double(features.zeroCrossingRate) * 60.0 // Convert to BPM-like measure
        let energyFactor = Double(features.energy) * 30.0 // Energy influences perceived tempo
        
        // Normalize to reasonable tempo range (60-180 BPM)
        let estimatedTempo = baseTempo + energyFactor
        return max(60.0, min(180.0, estimatedTempo))
    }
    
    /// Returns a summary of available features for debugging
    var featureSummary: String {
        var summary = "Pitch: \(pitch), Energy: \(energy), Tempo: \(tempo)"
        
        // Add jitter if available
        if let jitter = jitter {
            summary += ", Jitter: \(jitter)"
        }
        
        // Add shimmer if available
        if let shimmer = shimmer {
            summary += ", Shimmer: \(shimmer)"
        }
        
        // Add formants if available
        if let formants = formantFrequencies, !formants.isEmpty {
            let formantStrings = formants.prefix(2).map { String(format: "%.0f", $0) }
            let formantText = formantStrings.joined(separator: ",")
            summary += ", Formants: \(formantText)"
        }
        
        // Add HNR if available
        if let hnr = harmonicToNoiseRatio {
            let hnrText = String(format: "%.1f", hnr)
            summary += ", HNR: \(hnrText)"
        }
        
        return summary
    }
    
    /// Checks if enhanced features are available
    var hasEnhancedFeatures: Bool {
        return jitter != nil || shimmer != nil || formantFrequencies != nil || harmonicToNoiseRatio != nil
    }
    
    /// Returns the number of available features
    var featureCount: Int {
        var count = 5 // Core features always present
        if jitter != nil { count += 1 }
        if shimmer != nil { count += 1 }
        if formantFrequencies != nil { count += formantFrequencies!.count }
        if harmonicToNoiseRatio != nil { count += 1 }
        if zeroCrossingRate != nil { count += 1 }
        if spectralRolloff != nil { count += 1 }
        if voiceOnsetTime != nil { count += 1 }
        return count
    }
}

// MARK: - Emotional Context
/// Provides context about when and where the emotion was recorded
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
