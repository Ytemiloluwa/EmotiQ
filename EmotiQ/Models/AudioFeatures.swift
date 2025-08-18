//
//  AudioFeatures.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import SwiftUI

// MARK: - Production Audio Features
/// Comprehensive audio features extracted from voice recordings for emotion analysis
/// This struct contains all the features needed for accurate emotion detection
struct ProductionAudioFeatures {
    let pitch: Float                    // Fundamental frequency (Hz)
    let energy: Float                   // Audio energy level (0.0 - 1.0)
    let spectralCentroid: Float         // Spectral centroid (Hz)
    let zeroCrossingRate: Float         // Zero crossing rate (0.0 - 1.0)
    let spectralRolloff: Float          // Spectral rolloff frequency (Hz)
    let jitter: Float                   // Pitch jitter (0.0 - 1.0)
    let shimmer: Float                  // Amplitude shimmer (0.0 - 1.0)
    let formantFrequencies: [Float]     // Formant frequencies (Hz)
    let harmonicToNoiseRatio: Float     // Harmonic-to-noise ratio (dB)
    let voiceOnsetTime: Float           // Voice onset time (seconds)
    let mfccCoefficients: [Float]       // MFCC coefficients
    
    init(
        pitch: Float,
        energy: Float,
        spectralCentroid: Float,
        zeroCrossingRate: Float,
        spectralRolloff: Float,
        jitter: Float,
        shimmer: Float,
        formantFrequencies: [Float],
        harmonicToNoiseRatio: Float,
        voiceOnsetTime: Float,
        mfccCoefficients: [Float]
    ) {
        self.pitch = pitch
        self.energy = energy
        self.spectralCentroid = spectralCentroid
        self.zeroCrossingRate = zeroCrossingRate
        self.spectralRolloff = spectralRolloff
        self.jitter = jitter
        self.shimmer = shimmer
        self.formantFrequencies = formantFrequencies
        self.harmonicToNoiseRatio = harmonicToNoiseRatio
        self.voiceOnsetTime = voiceOnsetTime
        self.mfccCoefficients = mfccCoefficients
    }
}

// MARK: - Audio Quality Assessment
enum AudioQuality: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "xmark.circle"
        }
    }
    
    var reliabilityScore: Double {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.8
        case .fair: return 0.6
        case .poor: return 0.3
        }
    }
    
    var confidenceMultiplier: Double {
        switch self {
        case .excellent: return 1.1
        case .good: return 1.0
        case .fair: return 0.9
        case .poor: return 0.7
        }
    }
    
    var isAcceptable: Bool {
        return self != .poor
    }
}

// MARK: - Voice Quality Assessment
enum VoiceQuality: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "xmark.circle"
        }
    }
    
    var reliabilityScore: Double {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.8
        case .fair: return 0.6
        case .poor: return 0.3
        }
    }
    
    var confidenceMultiplier: Double {
        switch self {
        case .excellent: return 1.1
        case .good: return 1.0
        case .fair: return 0.9
        case .poor: return 0.7
        }
    }
    
    var isAcceptable: Bool {
        return self != .poor
    }
}

