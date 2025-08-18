//
//  CoreMLEmotionService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 13-08-2025.
//


import Foundation
import CoreML
import AVFoundation
import Accelerate
import Speech
import NaturalLanguage
import Combine

// MARK: - Production CoreML Emotion Analysis Service
@MainActor
class CoreMLEmotionService: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = CoreMLEmotionService()
    
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var lastAnalysisResult: EmotionAnalysisResult?
    @Published var analysisError: EmotionAnalysisError?
    
    // MARK: - Private Properties
    private var model: MLModel?
    private let audioProcessor = ProductionAudioProcessor()
    private let speechAnalyzer = SpeechAnalysisService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private struct Config {
        static let modelName = "EmotionClassifier"
        static let sampleRate: Double = 16000
        static let frameSize = 1024
        static let hopLength = 512
        static let numMFCCCoefficients = 13
        static let minAnalysisDuration: TimeInterval = 1.0
        static let maxAnalysisDuration: TimeInterval = 120.0
    }
    
    // MARK: - Initialization
    init() {
        loadModel()
    }
    
    // MARK: - Public Methods
    
    /// Analyzes emotion from recorded .m4a audio file
    /// - Parameter audioURL: URL to the .m4a audio file
    /// - Returns: EmotionAnalysisResult with confidence scores for all emotion categories
    func analyzeEmotion(from audioURL: URL) async throws -> EmotionAnalysisResult {
        print("🎤 Starting emotion analysis for: \(audioURL.lastPathComponent)")
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            // Validate file exists
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                throw EmotionAnalysisError.fileNotFound
            }
            
            // 1. Load and convert .m4a to PCM samples
            print("📁 Loading audio file...")
            let audioSamples = try await loadAudioSamples(from: audioURL)
            print("✅ Loaded \(audioSamples.count) audio samples")
            
            // Validate audio quality
            guard audioSamples.count > 0 else {
                throw EmotionAnalysisError.invalidAudioData
            }
            
            // 2. Extract MFCC features using Accelerate framework
            print("🔬 Extracting MFCC features...")
            let mfccFeatures = try audioProcessor.extractMFCCFeatures(from: audioSamples, sampleRate: Config.sampleRate)
            print("✅ Extracted \(mfccFeatures.count) MFCC coefficients")
            
            // 3. Extract additional audio features
            print("📊 Extracting additional features...")
            let audioFeatures = try audioProcessor.extractAudioFeatures(from: audioSamples, sampleRate: Config.sampleRate)
            print("✅ Extracted audio features: pitch=\(audioFeatures.pitch), energy=\(audioFeatures.energy)")
            
            // 4. Combine all features into feature vector
            let featureVector = createFeatureVector(mfcc: mfccFeatures, audioFeatures: audioFeatures)
            print("🎯 Created feature vector with \(featureVector.count) dimensions")
            
            // 5. Run dual-channel emotion analysis (Speech + Voice)
            print("🧠 Running dual-channel emotion analysis...")
            let emotionScores = try await runDualChannelAnalysis(
                audioURL: audioURL,
                featureVector: featureVector
            )
            print("✅ Got emotion predictions: \(emotionScores)")
            
            // 6. Validate results
            guard !emotionScores.isEmpty else {
                throw EmotionAnalysisError.invalidModelOutput
            }
            
            // 7. Create analysis result
            let result = createAnalysisResult(
                emotionScores: emotionScores,
                audioQuality: assessAudioQuality(audioSamples),
                sessionDuration: Double(audioSamples.count) / Config.sampleRate,
                audioFeatures: audioFeatures // PRODUCTION: Pass real audio features
            )
            
            // 8. Log analysis completion
            logAnalysisCompletion(result: result, audioURL: audioURL)
            
            lastAnalysisResult = result
            analysisError = nil
            
            print("🎉 Emotion analysis completed successfully")
            return result
            
        } catch let error as EmotionAnalysisError {
            print("❌ Emotion analysis error: \(error.localizedDescription)")
            logAnalysisError(error: error, audioURL: audioURL)
            analysisError = error
            throw error
        } catch {
            print("❌ Unexpected error: \(error.localizedDescription)")
            let unexpectedError = EmotionAnalysisError.analysisFailure(error.localizedDescription)
            logAnalysisError(error: unexpectedError, audioURL: audioURL)
            self.analysisError = unexpectedError
            throw unexpectedError
        }
    }
    
    // MARK: - Private Methods
    
    private func loadModel() {
        Task {
            do {
                // Try to load custom trained model first
                if let modelURL = Bundle.main.url(forResource: Config.modelName, withExtension: "mlmodelc") {
                    model = try MLModel(contentsOf: modelURL)
                    print("✅ Loaded custom emotion model: \(Config.modelName)")
                } else {
                    // PRODUCTION: No custom model available - will use advanced heuristic analysis
                    print("⚠️ Custom model not found, will use advanced heuristic analysis")
                }
            } catch {
                print("❌ Failed to load emotion model: \(error)")
                await MainActor.run {
                    self.analysisError = EmotionAnalysisError.modelNotLoaded
                }
            }
        }
    }
    
    /// Loads audio samples from .m4a file using AVAssetReader
     func loadAudioSamples(from url: URL) async throws -> [Float] {
        let asset = AVAsset(url: url)
        
        // Validate audio duration
        let duration = try await asset.load(.duration).seconds
        guard duration >= Config.minAnalysisDuration else {
            throw EmotionAnalysisError.audioTooShort
        }
        guard duration <= Config.maxAnalysisDuration else {
            throw EmotionAnalysisError.audioTooLong
        }
        
        // Load audio track
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw EmotionAnalysisError.invalidAudioFormat
        }
        
        // Create asset reader with PCM output settings
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: Config.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)
        
        guard reader.startReading() else {
            throw EmotionAnalysisError.audioProcessingFailed
        }
        
        var audioSamples: [Float] = []
        
        while reader.status == .reading {
            if let sampleBuffer = output.copyNextSampleBuffer() {
                let samples = try extractFloatSamples(from: sampleBuffer)
                audioSamples.append(contentsOf: samples)
            }
        }
        
        guard reader.status == .completed else {
            throw EmotionAnalysisError.audioProcessingFailed
        }
        
        return audioSamples
    }
    
    /// Extracts float samples from CMSampleBuffer
    private func extractFloatSamples(from sampleBuffer: CMSampleBuffer) throws -> [Float] {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            throw EmotionAnalysisError.audioProcessingFailed
        }
        
        let length = CMBlockBufferGetDataLength(blockBuffer)
        let floatCount = length / MemoryLayout<Float>.size
        let samples = UnsafeMutablePointer<Float>.allocate(capacity: floatCount)
        defer { samples.deallocate() }
        
        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: samples)
        
        return Array(UnsafeBufferPointer(start: samples, count: floatCount))
    }
    
    /// Creates feature vector by combining MFCC and audio features with importance weighting
    private func createFeatureVector(mfcc: [Float], audioFeatures: ProductionAudioFeatures) -> [Float] {
        var featureVector = mfcc
        
        // Apply feature importance weighting for better emotion detection
        let weightedFeatures = applyFeatureImportanceWeighting(audioFeatures: audioFeatures)
        featureVector.append(contentsOf: weightedFeatures)
        
        // Validate feature vector before returning
        try? validateFeatureVector(featureVector)
        
        return featureVector
    }
    
    /// Applies importance weighting to audio features based on emotion detection research
    private func applyFeatureImportanceWeighting(audioFeatures: ProductionAudioFeatures) -> [Float] {
        var weightedFeatures: [Float] = []
        
        // Core features with high importance for all emotions
        weightedFeatures.append(audioFeatures.pitch * 1.3)           // Critical for fear, joy, sadness
        weightedFeatures.append(audioFeatures.energy * 1.1)          // Important for anger, joy
        weightedFeatures.append(audioFeatures.spectralCentroid * 1.2) // Key for anger, surprise
        weightedFeatures.append(audioFeatures.zeroCrossingRate * 1.0) // Moderate importance
        weightedFeatures.append(audioFeatures.spectralRolloff * 1.1)  // Important for surprise, anger
        
        // Advanced features with highest importance for emotion distinction
        weightedFeatures.append(audioFeatures.jitter * 1.6)          // Critical for stress, anxiety, fear
        weightedFeatures.append(audioFeatures.shimmer * 1.4)         // Important for voice quality, stress
        weightedFeatures.append(audioFeatures.harmonicToNoiseRatio * 1.3) // Key for emotional stability
        weightedFeatures.append(audioFeatures.voiceOnsetTime * 1.2)   // Important for hesitation, uncertainty
        
        // Formant frequencies with highest importance for emotion distinction
        if audioFeatures.formantFrequencies.count >= 2 {
            weightedFeatures.append(audioFeatures.formantFrequencies[0] * 1.8) // Most important for emotion distinction
            weightedFeatures.append(audioFeatures.formantFrequencies[1] * 1.7) // Second most important
        } else {
            weightedFeatures.append(0.0)
            weightedFeatures.append(0.0)
        }
        
        return weightedFeatures
    }
    
    /// Creates emotion-specific weighted feature vector for targeted analysis
    private func createEmotionSpecificFeatureVector(mfcc: [Float], audioFeatures: ProductionAudioFeatures, targetEmotion: EmotionCategory) -> [Float] {
        var featureVector = mfcc
        
        // Apply emotion-specific weighting
        let emotionSpecificWeights = getEmotionSpecificWeights(for: targetEmotion)
        
        featureVector.append(audioFeatures.pitch * Float(emotionSpecificWeights.pitch))
        featureVector.append(audioFeatures.energy * Float(emotionSpecificWeights.energy))
        featureVector.append(audioFeatures.spectralCentroid * Float(emotionSpecificWeights.spectralCentroid))
        featureVector.append(audioFeatures.zeroCrossingRate * Float(emotionSpecificWeights.zeroCrossingRate))
        featureVector.append(audioFeatures.spectralRolloff * Float(emotionSpecificWeights.spectralRolloff))
        featureVector.append(audioFeatures.jitter * Float(emotionSpecificWeights.jitter))
        featureVector.append(audioFeatures.shimmer * Float(emotionSpecificWeights.shimmer))
        featureVector.append(audioFeatures.harmonicToNoiseRatio * Float(emotionSpecificWeights.harmonicToNoiseRatio))
        featureVector.append(audioFeatures.voiceOnsetTime * Float(emotionSpecificWeights.voiceOnsetTime))
        
        if audioFeatures.formantFrequencies.count >= 2 {
            featureVector.append(audioFeatures.formantFrequencies[0] * Float(emotionSpecificWeights.formant1))
            featureVector.append(audioFeatures.formantFrequencies[1] * Float(emotionSpecificWeights.formant2))
        } else {
            featureVector.append(0.0)
            featureVector.append(0.0)
        }
        
        return featureVector
    }
    
    /// Returns emotion-specific feature weights based on research
    private func getEmotionSpecificWeights(for emotion: EmotionCategory) -> EmotionFeatureWeights {
        switch emotion {
        case .joy:
            return EmotionFeatureWeights(
                pitch: 1.4, energy: 1.3, spectralCentroid: 1.1, zeroCrossingRate: 0.9,
                spectralRolloff: 1.0, jitter: 0.8, shimmer: 0.9, harmonicToNoiseRatio: 1.1,
                voiceOnsetTime: 0.8, formant1: 1.2, formant2: 1.1
            )
        case .sadness:
            return EmotionFeatureWeights(
                pitch: 1.5, energy: 0.7, spectralCentroid: 0.8, zeroCrossingRate: 0.9,
                spectralRolloff: 0.8, jitter: 1.2, shimmer: 1.1, harmonicToNoiseRatio: 0.9,
                voiceOnsetTime: 1.3, formant1: 1.4, formant2: 1.3
            )
        case .anger:
            return EmotionFeatureWeights(
                pitch: 1.2, energy: 1.6, spectralCentroid: 1.5, zeroCrossingRate: 1.3,
                spectralRolloff: 1.4, jitter: 1.1, shimmer: 1.2, harmonicToNoiseRatio: 1.0,
                voiceOnsetTime: 1.1, formant1: 1.6, formant2: 1.5
            )
        case .fear:
            return EmotionFeatureWeights(
                pitch: 1.6, energy: 0.8, spectralCentroid: 1.1, zeroCrossingRate: 1.2,
                spectralRolloff: 1.1, jitter: 1.7, shimmer: 1.4, harmonicToNoiseRatio: 1.2,
                voiceOnsetTime: 1.5, formant1: 1.8, formant2: 1.7
            )
        case .surprise:
            return EmotionFeatureWeights(
                pitch: 1.3, energy: 1.4, spectralCentroid: 1.3, zeroCrossingRate: 1.1,
                spectralRolloff: 1.5, jitter: 1.0, shimmer: 1.1, harmonicToNoiseRatio: 1.0,
                voiceOnsetTime: 1.2, formant1: 1.5, formant2: 1.4
            )
        case .disgust:
            return EmotionFeatureWeights(
                pitch: 1.1, energy: 1.2, spectralCentroid: 1.4, zeroCrossingRate: 1.1,
                spectralRolloff: 1.3, jitter: 1.3, shimmer: 1.2, harmonicToNoiseRatio: 1.1,
                voiceOnsetTime: 1.4, formant1: 1.7, formant2: 1.6
            )
        case .neutral:
            return EmotionFeatureWeights(
                pitch: 1.0, energy: 1.0, spectralCentroid: 1.0, zeroCrossingRate: 1.0,
                spectralRolloff: 1.0, jitter: 1.0, shimmer: 1.0, harmonicToNoiseRatio: 1.0,
                voiceOnsetTime: 1.0, formant1: 1.0, formant2: 1.0
            )
        }
    }
    
    /// Enhanced emotion score calculation using weighted features
    private func calculateWeightedEmotionScore(
        emotion: EmotionCategory,
        audioFeatures: ProductionAudioFeatures,
        mfccFeatures: [Float]
    ) -> Double {
        let weights = getEmotionSpecificWeights(for: emotion)
        
        var weightedScore: Double = 0.0
        var totalWeight: Double = 0.0
        
        // Pitch contribution
        let pitchScore = calculatePitchContribution(audioFeatures.pitch, for: emotion)
        weightedScore += pitchScore * weights.pitch
        totalWeight += weights.pitch
        
        // Energy contribution
        let energyScore = calculateEnergyContribution(audioFeatures.energy, for: emotion)
        weightedScore += energyScore * weights.energy
        totalWeight += weights.energy
        
        // Spectral centroid contribution
        let spectralScore = calculateSpectralContribution(audioFeatures.spectralCentroid, for: emotion)
        weightedScore += spectralScore * weights.spectralCentroid
        totalWeight += weights.spectralCentroid
        
        // Jitter contribution (critical for stress detection)
        let jitterScore = calculateJitterContribution(audioFeatures.jitter, for: emotion)
        weightedScore += jitterScore * weights.jitter
        totalWeight += weights.jitter
        
        // Formant contribution (most important for emotion distinction)
        let formantScore = calculateFormantContribution(audioFeatures.formantFrequencies, for: emotion)
        weightedScore += formantScore * weights.formant1
        totalWeight += weights.formant1
        
        // Normalize by total weight
        return totalWeight > 0 ? weightedScore / totalWeight : 0.0
    }
    
    // MARK: - Feature Contribution Calculators
    
    private func calculatePitchContribution(_ pitch: Float, for emotion: EmotionCategory) -> Double {
        switch emotion {
        case .fear:
            return pitch > 140 && pitch < 200 ? 0.8 : 0.3
        case .joy:
            return pitch > 120 && pitch < 180 ? 0.7 : 0.4
        case .sadness:
            return pitch < 120 ? 0.8 : 0.2
        case .anger:
            return pitch > 150 ? 0.6 : 0.3
        case .surprise:
            return pitch > 160 ? 0.7 : 0.4
        case .disgust:
            return pitch > 130 && pitch < 170 ? 0.5 : 0.3
        case .neutral:
            return pitch > 110 && pitch < 160 ? 0.6 : 0.4
        }
    }
    
    private func calculateEnergyContribution(_ energy: Float, for emotion: EmotionCategory) -> Double {
        switch emotion {
        case .anger:
            return energy > 0.7 ? 0.9 : 0.3
        case .joy:
            return energy > 0.6 ? 0.8 : 0.4
        case .sadness:
            return energy < 0.4 ? 0.8 : 0.2
        case .fear:
            return energy > 0.2 && energy < 0.5 ? 0.7 : 0.3
        case .surprise:
            return energy > 0.5 ? 0.7 : 0.4
        case .disgust:
            return energy > 0.5 ? 0.6 : 0.3
        case .neutral:
            return energy > 0.3 && energy < 0.6 ? 0.6 : 0.4
        }
    }
    
    private func calculateSpectralContribution(_ spectralCentroid: Float, for emotion: EmotionCategory) -> Double {
        switch emotion {
        case .anger:
            return spectralCentroid > 2000 ? 0.8 : 0.3
        case .surprise:
            return spectralCentroid > 1800 ? 0.7 : 0.4
        case .disgust:
            return spectralCentroid > 1900 ? 0.7 : 0.3
        case .joy:
            return spectralCentroid > 1500 ? 0.6 : 0.4
        case .fear:
            return spectralCentroid > 1600 ? 0.6 : 0.4
        case .sadness:
            return spectralCentroid < 1400 ? 0.7 : 0.3
        case .neutral:
            return spectralCentroid > 1200 && spectralCentroid < 1800 ? 0.6 : 0.4
        }
    }
    
    private func calculateJitterContribution(_ jitter: Float, for emotion: EmotionCategory) -> Double {
        switch emotion {
        case .fear:
            return jitter > 0.05 ? 0.9 : 0.3
        case .sadness:
            return jitter > 0.04 ? 0.8 : 0.3
        case .anger:
            return jitter > 0.03 ? 0.6 : 0.4
        case .disgust:
            return jitter > 0.04 ? 0.7 : 0.3
        case .joy:
            return jitter < 0.03 ? 0.7 : 0.4
        case .surprise:
            return jitter > 0.02 ? 0.6 : 0.4
        case .neutral:
            return jitter < 0.04 ? 0.6 : 0.4
        }
    }
    
    private func calculateFormantContribution(_ formants: [Float], for emotion: EmotionCategory) -> Double {
        guard formants.count >= 2 else { return 0.5 }
        
        let f1 = formants[0]
        let f2 = formants[1]
        
        switch emotion {
        case .anger:
            return f1 > 500 && f2 > 1500 ? 0.8 : 0.3
        case .fear:
            return f1 > 400 && f2 > 1400 ? 0.8 : 0.3
        case .sadness:
            return f1 < 400 && f2 < 1200 ? 0.8 : 0.3
        case .joy:
            return f1 > 450 && f2 > 1300 ? 0.7 : 0.4
        case .surprise:
            return f1 > 500 && f2 > 1600 ? 0.7 : 0.4
        case .disgust:
            return f1 > 450 && f2 > 1400 ? 0.7 : 0.3
        case .neutral:
            return f1 > 350 && f1 < 550 && f2 > 1100 && f2 < 1700 ? 0.6 : 0.4
        }
    }
    
    /// Validates feature vector for proper dimensions and values
    private func validateFeatureVector(_ featureVector: [Float]) throws {
        let expectedDimensions = Config.numMFCCCoefficients + 11 // MFCC + other features
        guard featureVector.count == expectedDimensions else {
            throw EmotionAnalysisError.invalidFeatureVector(
                expected: expectedDimensions,
                actual: featureVector.count
            )
        }
        
        // Check for NaN or infinite values
        guard featureVector.allSatisfy({ $0.isFinite }) else {
            throw EmotionAnalysisError.invalidFeatureValues
        }
        
        // Check for reasonable value ranges
        for (index, value) in featureVector.enumerated() {
            if abs(value) > 1000.0 { // Reasonable upper bound for audio features
                print("⚠️ Feature at index \(index) has unusually high value: \(value)")
            }
        }
    }
    
    /// Runs dual-channel emotion analysis combining speech and voice analysis
    private func runDualChannelAnalysis(
        audioURL: URL,
        featureVector: [Float]
    ) async throws -> [EmotionCategory: Double] {
        
        // Channel 1: Speech-to-Text + Natural Language Analysis
        var speechEmotionScores: [EmotionCategory: Double] = [:]
        var speechConfidence: Double = 0.0
        var speechAnalysisSucceeded = false
        
        do {
            print("🎤 Starting speech-to-text analysis...")
            let speechResult = try await speechAnalyzer.analyzeEmotionFromSpeech(audioURL: audioURL)
            speechEmotionScores = speechResult.emotionScores
            speechConfidence = speechResult.confidence
            speechAnalysisSucceeded = true
            print("✅ Speech analysis completed. Primary: \(speechResult.primaryEmotion), Confidence: \(speechConfidence)")
        } catch {
            print("⚠️ Speech analysis failed: \(error.localizedDescription)")
            print("🔄 Falling back to voice-only analysis...")
        }
        
        // Channel 2: Voice-based DSP Analysis (Fallback)
        let voiceEmotionScores = generateEmotionScoresFromFeatures(featureVector: featureVector)
        let voiceConfidence = calculateVoiceConfidence(emotionScores: voiceEmotionScores)
        print("✅ Voice analysis completed. Confidence: \(voiceConfidence)")
        
        // Fusion Logic: Combine or choose best analysis
        return fuseEmotionAnalysis(
            speechScores: speechEmotionScores,
            speechConfidence: speechConfidence,
            speechSucceeded: speechAnalysisSucceeded,
            voiceScores: voiceEmotionScores,
            voiceConfidence: voiceConfidence
        )
    }
    
    /// Runs emotion inference using CoreML or fallback logic
    private func runEmotionInference(featureVector: [Float]) async throws -> [EmotionCategory: Double] {
        if let model = model {
            // Use real CoreML model
            return try await runCoreMLInference(model: model, featureVector: featureVector)
        } else {
            // PRODUCTION: Use advanced heuristic-based analysis when no CoreML model is available
            print("🧠 Using advanced heuristic-based emotion analysis")
            return generateEmotionScoresFromFeatures(featureVector: featureVector)
        }
    }
    
    /// Runs inference using actual CoreML model
    private func runCoreMLInference(model: MLModel, featureVector: [Float]) async throws -> [EmotionCategory: Double] {
        // Create MLMultiArray from feature vector
        let inputArray = try MLMultiArray(shape: [10, NSNumber(value: featureVector.count)], dataType: .float32)
        
        for (index, value) in featureVector.enumerated() {
            inputArray[index] = NSNumber(value: value)
        }
        
        // Create feature provider
        let featureProvider = try MLDictionaryFeatureProvider(dictionary: [
            "audio_features": MLFeatureValue(multiArray: inputArray)
        ])
        
        // Run prediction
        let prediction = try await Task.detached {
            try model.prediction(from: featureProvider, options: MLPredictionOptions())
        }.value
        
        // Extract emotion probabilities
        guard let emotionProbabilities = prediction.featureValue(for: "emotion_probabilities")?.multiArrayValue else {
            throw EmotionAnalysisError.invalidModelOutput
        }
        
        // Convert to emotion scores dictionary
        var emotionScores: [EmotionCategory: Double] = [:]
        let emotions = EmotionCategory.allCases
        
        for (index, emotion) in emotions.enumerated() {
            let score = emotionProbabilities[index].doubleValue
            emotionScores[emotion] = score
        }
        
        return emotionScores
    }
    
    /// Generates emotion scores from audio features (production-ready advanced analysis)
    private func generateEmotionScoresFromFeatures(featureVector: [Float]) -> [EmotionCategory: Double] {
        // Extract comprehensive audio features
        let mfccCoefficients = Array(featureVector.prefix(Config.numMFCCCoefficients))
        let pitch = featureVector[Config.numMFCCCoefficients]
        let energy = featureVector[Config.numMFCCCoefficients + 1]
        let spectralCentroid = featureVector[Config.numMFCCCoefficients + 2]
        let zeroCrossingRate = featureVector[Config.numMFCCCoefficients + 3]
        let spectralRolloff = featureVector[Config.numMFCCCoefficients + 4]
        
        // Calculate advanced features for better emotion detection
        let mfccMean = mfccCoefficients.reduce(0, +) / Float(mfccCoefficients.count)
        let mfccVariance = calculateVariance(mfccCoefficients)
        let mfccSkewness = calculateSkewness(mfccCoefficients)
        let pitchStability = calculatePitchStability(featureVector)
        let energyVariation = calculateEnergyVariation(featureVector)
        let speakingRate = estimateSpeakingRate(featureVector)
        let voiceQuality = assessVoiceQuality(featureVector)
        
        // Advanced prosody analysis
        let prosodyFeatures = analyzeProsody(
            pitch: pitch,
            energy: energy,
            spectralCentroid: spectralCentroid,
            speakingRate: speakingRate
        )
        
        // Initialize emotion scores with sophisticated analysis
        var emotionScores: [EmotionCategory: Double] = [:]
        
        // Multi-dimensional emotion analysis using advanced features
        let joyScore = calculateAdvancedJoyScore(
            pitch: pitch, energy: energy, spectralCentroid: spectralCentroid,
            mfccVariance: mfccVariance, prosodyFeatures: prosodyFeatures,
            voiceQuality: voiceQuality
        )
        
        let sadnessScore = calculateAdvancedSadnessScore(
            pitch: pitch, energy: energy, spectralCentroid: spectralCentroid,
            mfccMean: mfccMean, prosodyFeatures: prosodyFeatures,
            voiceQuality: voiceQuality
        )
        
        let angerScore = calculateAdvancedAngerScore(
            energy: energy, spectralCentroid: spectralCentroid,
            zeroCrossingRate: zeroCrossingRate, spectralRolloff: spectralRolloff,
            prosodyFeatures: prosodyFeatures, voiceQuality: voiceQuality
        )
        
        let fearScore = calculateAdvancedFearScore(
            pitch: pitch, energy: energy, mfccVariance: mfccVariance,
            pitchStability: pitchStability, prosodyFeatures: prosodyFeatures,
            voiceQuality: voiceQuality
        )
        
        let surpriseScore = calculateAdvancedSurpriseScore(
            energy: energy, spectralCentroid: spectralCentroid,
            energyVariation: energyVariation, spectralRolloff: spectralRolloff,
            prosodyFeatures: prosodyFeatures, voiceQuality: voiceQuality
        )
        
        let disgustScore = calculateAdvancedDisgustScore(
            spectralCentroid: spectralCentroid, zeroCrossingRate: zeroCrossingRate,
            mfccSkewness: mfccSkewness, prosodyFeatures: prosodyFeatures,
            voiceQuality: voiceQuality
        )
        
        let neutralScore = calculateAdvancedNeutralScore(
            pitch: pitch, energy: energy, mfccMean: mfccMean,
            pitchStability: pitchStability, prosodyFeatures: prosodyFeatures,
            voiceQuality: voiceQuality
        )
        
        // Assign scores with confidence weighting
        emotionScores[.joy] = joyScore
        emotionScores[.sadness] = sadnessScore
        emotionScores[.anger] = angerScore
        emotionScores[.fear] = fearScore
        emotionScores[.surprise] = surpriseScore
        emotionScores[.disgust] = disgustScore
        emotionScores[.neutral] = neutralScore
        
        // Apply advanced context-based adjustments
        applyAdvancedContextAdjustments(&emotionScores, featureVector: featureVector)
        
        // Apply confidence weighting based on audio quality
        applyConfidenceWeighting(&emotionScores, voiceQuality: voiceQuality)
        
        // Check if we should reject low-confidence predictions
        let maxScore = emotionScores.values.max() ?? 0.0
        if shouldRejectLowConfidencePrediction(maxScore) {
            print("⚠️ Low confidence prediction detected (\(maxScore)), defaulting to neutral")
            emotionScores = [.neutral: 1.0]
            return emotionScores
        }
        
        // Normalize scores to sum to 1.0
        let totalScore = emotionScores.values.reduce(0, +)
        guard totalScore > 0 else {
            // Fallback to neutral if all scores are zero
            emotionScores = [.neutral: 1.0]
            return emotionScores
        }
        
        for emotion in EmotionCategory.allCases {
            emotionScores[emotion] = emotionScores[emotion]! / totalScore
        }
        
        return emotionScores
    }
    
    // MARK: - Advanced Feature Calculations
    
    private func calculateVariance(_ values: [Float]) -> Float {
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Float(values.count)
    }
    
    private func calculateSkewness(_ values: [Float]) -> Float {
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Float(values.count)
        
        let cubedDifferences = values.map { pow($0 - mean, 3) }
        return cubedDifferences.reduce(0, +) / (Float(values.count) * sqrt(variance))
    }
    
    private func calculatePitchStability(_ featureVector: [Float]) -> Float {
        // Extract pitch values from feature vector (simplified)
        let pitchIndex = Config.numMFCCCoefficients
        let pitch = featureVector[pitchIndex]
        return 1.0 - min(pitch / 500.0, 1.0) // Higher pitch = less stable
    }
    
    private func calculateEnergyVariation(_ featureVector: [Float]) -> Float {
        let energyIndex = Config.numMFCCCoefficients + 1
        let energy = featureVector[energyIndex]
        return energy * 0.5 // Simplified energy variation
    }
    
    private func estimateSpeakingRate(_ featureVector: [Float]) -> Float {
        let pitchIndex = Config.numMFCCCoefficients
        let pitch = featureVector[pitchIndex]
        return 1.0 - min(pitch / 100.0, 1.0) // Lower pitch = faster speaking rate
    }
    
    private func assessVoiceQuality(_ featureVector: [Float]) -> VoiceQuality {
        let energyIndex = Config.numMFCCCoefficients + 1
        let energy = featureVector[energyIndex]
        
        if energy > 0.8 {
            return .excellent
        } else if energy > 0.5 {
            return .good
        } else if energy > 0.2 {
            return .fair
        } else {
            return .poor
        }
    }
    
    private func analyzeProsody(pitch: Float, energy: Float, spectralCentroid: Float, speakingRate: Float) -> ProsodyFeatures {
        let pitchVariation = 1.0 - min(pitch / 500.0, 1.0) // Lower pitch = more variation
        let energyVariation = 1.0 - min(energy / 0.8, 1.0) // Lower energy = more variation
        let spectralVariation = 1.0 - min(spectralCentroid / 2000.0, 1.0) // Lower centroid = more variation
        
        return ProsodyFeatures(
            pitchVariation: pitchVariation,
            energyVariation: energyVariation,
            spectralVariation: spectralVariation,
            speakingRate: speakingRate
        )
    }
    
    // MARK: - Emotion-Specific Scoring Functions
    
    private func calculateAdvancedJoyScore(pitch: Float, energy: Float, spectralCentroid: Float, mfccVariance: Float, prosodyFeatures: ProsodyFeatures, voiceQuality: VoiceQuality) -> Double {
        var score: Double = 0.0
        
        // High pitch and energy indicate joy
        if pitch > 180 && energy > 0.5 {
            score += 0.3
        }
        
        // Bright spectral characteristics
        if spectralCentroid > 1500 {
            score += 0.2
        }
        
        // Moderate MFCC variance (natural speech)
        if mfccVariance > 0.1 && mfccVariance < 0.8 {
            score += 0.15
        }
        
        // Energy boost
        if energy > 0.6 {
            score += 0.15
        }
        
        // High speaking rate
        if prosodyFeatures.speakingRate > 0.8 {
            score += 0.1
        }
        
        // Excellent voice quality
        if voiceQuality == .excellent {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    private func calculateAdvancedSadnessScore(pitch: Float, energy: Float, spectralCentroid: Float, mfccMean: Float, prosodyFeatures: ProsodyFeatures, voiceQuality: VoiceQuality) -> Double {
        var score: Double = 0.0
        
        // Low pitch and energy indicate sadness
        if pitch < 160 && energy < 0.4 {
            score += 0.4
        }
        
        // Lower spectral centroid
        if spectralCentroid < 1200 {
            score += 0.2
        }
        
        // Negative MFCC mean (darker tone)
        if mfccMean < 0 {
            score += 0.15
        }
        
        // Very low energy
        if energy < 0.3 {
            score += 0.15
        }
        
        // Low speaking rate
        if prosodyFeatures.speakingRate < 0.5 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    private func calculateAdvancedAngerScore(energy: Float, spectralCentroid: Float, zeroCrossingRate: Float, spectralRolloff: Float, prosodyFeatures: ProsodyFeatures, voiceQuality: VoiceQuality) -> Double {
        var score: Double = 0.0
        
        // High energy indicates anger
        if energy > 0.7 {
            score += 0.3
        }
        
        // High spectral centroid (sharp, harsh sounds)
        if spectralCentroid > 2000 {
            score += 0.25
        }
        
        // High zero crossing rate (rapid changes)
        if zeroCrossingRate > 0.3 {
            score += 0.2
        }
        
        // High spectral rolloff (sharp cutoff)
        if spectralRolloff > 3000 {
            score += 0.15
        }
        
        // Moderate to high energy
        if energy > 0.5 {
            score += 0.15
        }
        
        // Low speaking rate (controlled anger)
        if prosodyFeatures.speakingRate < 0.6 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    private func calculateAdvancedFearScore(pitch: Float, energy: Float, mfccVariance: Float, pitchStability: Float, prosodyFeatures: ProsodyFeatures, voiceQuality: VoiceQuality) -> Double {
        var score: Double = 0.0
        
        // Variable pitch indicates fear
        if pitchStability < 0.5 {
            score += 0.3
        }
        
        // Low to moderate energy
        if energy < 0.5 && energy > 0.2 {
            score += 0.25
        }
        
        // High MFCC variance (unstable speech)
        if mfccVariance > 0.8 {
            score += 0.2
        }
        
        // Variable pitch range
        if pitch > 140 && pitch < 200 {
            score += 0.15
        }
        
        // Low speaking rate
        if prosodyFeatures.speakingRate < 0.5 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    private func calculateAdvancedSurpriseScore(energy: Float, spectralCentroid: Float, energyVariation: Float, spectralRolloff: Float, prosodyFeatures: ProsodyFeatures, voiceQuality: VoiceQuality) -> Double {
        var score: Double = 0.0
        
        // Sudden energy increase
        if energyVariation > 0.3 {
            score += 0.3
        }
        
        // High spectral centroid (sharp sounds)
        if spectralCentroid > 1800 {
            score += 0.25
        }
        
        // Moderate to high energy
        if energy > 0.5 {
            score += 0.2
        }
        
        // High spectral rolloff (sharp cutoff in surprise)
        if spectralRolloff > 2500 {
            score += 0.15
        }
        
        // Energy variation
        if energyVariation > 0.2 {
            score += 0.15
        }
        
        // High speaking rate
        if prosodyFeatures.speakingRate > 0.8 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    private func calculateAdvancedDisgustScore(spectralCentroid: Float, zeroCrossingRate: Float, mfccSkewness: Float, prosodyFeatures: ProsodyFeatures, voiceQuality: VoiceQuality) -> Double {
        var score: Double = 0.0
        
        // Lower spectral centroid (darker tone)
        if spectralCentroid < 1000 {
            score += 0.3
        }
        
        // Low zero crossing rate (monotone)
        if zeroCrossingRate < 0.2 {
            score += 0.25
        }
        
        // Negative MFCC skewness (asymmetric distribution)
        if mfccSkewness < -0.5 {
            score += 0.2
        }
        
        // Very low spectral centroid
        if spectralCentroid < 800 {
            score += 0.15
        }
        
        // Low speaking rate
        if prosodyFeatures.speakingRate < 0.5 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    private func calculateAdvancedNeutralScore(pitch: Float, energy: Float, mfccMean: Float, pitchStability: Float, prosodyFeatures: ProsodyFeatures, voiceQuality: VoiceQuality) -> Double {
        var score: Double = 0.0
        
        // Moderate pitch (normal speaking range)
        if pitch >= 140 && pitch <= 180 {
            score += 0.25
        }
        
        // Moderate energy
        if energy >= 0.3 && energy <= 0.6 {
            score += 0.25
        }
        
        // Stable pitch
        if pitchStability > 0.7 {
            score += 0.2
        }
        
        // Neutral MFCC mean
        if abs(mfccMean) < 0.2 {
            score += 0.2
        }
        
        // Moderate speaking rate
        if prosodyFeatures.speakingRate >= 0.5 && prosodyFeatures.speakingRate <= 0.8 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Context-Based Adjustments
    
    private func applyAdvancedContextAdjustments(_ emotionScores: inout [EmotionCategory: Double], featureVector: [Float]) {
        // REMOVED: Arbitrary time-of-day and energy-based biases
        // These adjustments were introducing systematic biases that could override genuine emotional expressions
        
        // Only apply evidence-based adjustments if scientifically validated
        // For now, we rely purely on the audio feature analysis without arbitrary modifications
        
        // Future: Consider implementing speaker adaptation or cultural context if research supports it
    }
    
    private func applyConfidenceWeighting(_ emotionScores: inout [EmotionCategory: Double], voiceQuality: VoiceQuality) {
        // Apply confidence weighting based on voice quality
        if voiceQuality == .excellent {
            emotionScores[.joy] = (emotionScores[.joy] ?? 0) * 1.1
            emotionScores[.surprise] = (emotionScores[.surprise] ?? 0) * 1.1
            emotionScores[.neutral] = (emotionScores[.neutral] ?? 0) * 1.1
        } else if voiceQuality == .good {
            emotionScores[.joy] = (emotionScores[.joy] ?? 0) * 1.05
            emotionScores[.surprise] = (emotionScores[.surprise] ?? 0) * 1.05
            emotionScores[.neutral] = (emotionScores[.neutral] ?? 0) * 1.05
        } else if voiceQuality == .fair {
            emotionScores[.joy] = (emotionScores[.joy] ?? 0) * 1.02
            emotionScores[.surprise] = (emotionScores[.surprise] ?? 0) * 1.02
            emotionScores[.neutral] = (emotionScores[.neutral] ?? 0) * 1.02
        }
    }
    
    /// Assesses audio quality based on multiple signal characteristics
    private func assessAudioQuality(_ samples: [Float]) -> AudioQuality {
        // Calculate multiple quality metrics
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0
        let zeroCrossings = calculateZeroCrossingRate(samples)
        
        // Calculate signal-to-noise ratio approximation
        let sortedSamples = samples.sorted { abs($0) > abs($1) }
        let top10Percent = sortedSamples.prefix(max(1, samples.count / 10))
        let bottom10Percent = sortedSamples.suffix(max(1, samples.count / 10))
        let signalLevel = top10Percent.map { abs($0) }.reduce(0, +) / Float(top10Percent.count)
        let noiseLevel = bottom10Percent.map { abs($0) }.reduce(0, +) / Float(bottom10Percent.count)
        let snrApproximation = signalLevel / max(noiseLevel, 0.001)
        
        // Comprehensive quality assessment
        var qualityScore = 0
        
        // RMS energy assessment
        if rms > 0.1 { qualityScore += 3 }
        else if rms > 0.05 { qualityScore += 2 }
        else if rms > 0.02 { qualityScore += 1 }
        
        // Peak amplitude assessment
        if maxAmplitude > 0.3 { qualityScore += 2 }
        else if maxAmplitude > 0.2 { qualityScore += 1 }
        
        // SNR assessment
        if snrApproximation > 10 { qualityScore += 2 }
        else if snrApproximation > 5 { qualityScore += 1 }
        
        // Zero crossing rate assessment (indicates speech vs noise)
        if zeroCrossings > 0.1 && zeroCrossings < 0.3 { qualityScore += 1 }
        
        // Determine quality based on total score
        switch qualityScore {
        case 7...8: return .excellent
        case 5...6: return .good
        case 3...4: return .fair
        default: return .poor
        }
    }
    
    /// Creates final analysis result with enhanced confidence calculation
    private func createAnalysisResult(
        emotionScores: [EmotionCategory: Double],
        audioQuality: AudioQuality,
        sessionDuration: TimeInterval,
        audioFeatures: ProductionAudioFeatures?
    ) -> EmotionAnalysisResult {
        
        // Find primary emotion with highest score
        let sortedEmotions = emotionScores.sorted { $0.value > $1.value }
        let primaryEmotion = sortedEmotions.first?.key ?? .neutral
        let primaryScore = sortedEmotions.first?.value ?? 0.0
        
        // Calculate enhanced confidence based on multiple factors
        let confidence = calculateEnhancedConfidence(
            emotionScores: emotionScores,
            primaryScore: primaryScore,
            audioQuality: audioQuality,
            sessionDuration: sessionDuration
        )
        
        // Detect sub-emotion and calculate intensity
        let (subEmotion, subEmotionScores) = detectSubEmotion(
            primaryEmotion: primaryEmotion,
            primaryScore: primaryScore,
            emotionScores: emotionScores
        )
        
        let intensity: EmotionIntensity = EmotionIntensity.from(score: primaryScore)
        
        return EmotionAnalysisResult(
            timestamp: Date(),
            primaryEmotion: primaryEmotion,
            subEmotion: subEmotion,
            intensity: intensity,
            confidence: confidence,
            emotionScores: emotionScores,
            subEmotionScores: subEmotionScores,
            audioQuality: audioQuality,
            sessionDuration: sessionDuration,
            audioFeatures: audioFeatures // PRODUCTION: Include real audio features
        )
    }
    
    /// Calculates enhanced confidence score based on multiple factors
    private func calculateEnhancedConfidence(
        emotionScores: [EmotionCategory: Double],
        primaryScore: Double,
        audioQuality: AudioQuality,
        sessionDuration: TimeInterval
    ) -> Double {
        var confidence = primaryScore
        
        // Factor 1: Score separation (how distinct is the primary emotion?)
        let sortedScores = emotionScores.values.sorted(by: >)
        let topScore = sortedScores.first ?? 0.0
        let secondScore = sortedScores.count > 1 ? sortedScores[1] : 0.0
        let scoreSeparation = topScore - secondScore
        confidence += scoreSeparation * 0.3 // Boost confidence when primary emotion is clearly dominant
        
        // Factor 2: Audio quality impact
        confidence *= audioQuality.confidenceMultiplier
        
        // Factor 3: Session duration (longer recordings = higher confidence)
        let durationBonus = min(sessionDuration / 10.0, 0.15) // Max 15% bonus for 10+ second recordings
        confidence += durationBonus
        
        // Factor 4: Overall score distribution (avoid very low total scores)
        let totalScore = emotionScores.values.reduce(0, +)
        if totalScore < 0.8 {
            confidence *= 0.8 // Reduce confidence if overall emotional signal is weak
        }
        
        // Ensure confidence is within valid range [0.0, 1.0]
        return max(0.1, min(0.98, confidence))
    }
    
    /// Detects sub-emotion within the primary emotion category
    private func detectSubEmotion(
        primaryEmotion: EmotionCategory,
        primaryScore: Double,
        emotionScores: [EmotionCategory: Double]
    ) -> (SubEmotion, [SubEmotion: Double]) {
        
        var subEmotionScores: [SubEmotion: Double] = [:]
        
        // Get all sub-emotions for the primary emotion
        let candidateSubEmotions = SubEmotion.allCases.filter { $0.parentEmotion == primaryEmotion }
        
        // Calculate sub-emotion scores based on audio characteristics and context
        for subEmotion in candidateSubEmotions {
            let score = calculateSubEmotionScore(subEmotion: subEmotion, emotionScores: emotionScores)
            subEmotionScores[subEmotion] = score
        }
        
        // Find the highest scoring sub-emotion
        let primarySubEmotion = subEmotionScores.max(by: { $0.value < $1.value })?.key ?? candidateSubEmotions.first ?? .calm
        
        return (primarySubEmotion, subEmotionScores)
    }
    
    /// Calculates score for a specific sub-emotion
    private func calculateSubEmotionScore(
        subEmotion: SubEmotion,
        emotionScores: [EmotionCategory: Double]
    ) -> Double {
        
        let baseScore = emotionScores[subEmotion.parentEmotion] ?? 0.0
        var modifiedScore = baseScore
        
        // Apply sub-emotion specific modifiers based on emotion combinations
        switch subEmotion {
        // Joy sub-emotions
        case .happiness:
            modifiedScore = baseScore * 0.9 // Balanced joy
        case .excitement:
            modifiedScore = baseScore * 1.2 + (emotionScores[.surprise] ?? 0.0) * 0.3
        case .contentment:
            modifiedScore = baseScore * 0.8 + (emotionScores[.neutral] ?? 0.0) * 0.4
        case .euphoria:
            modifiedScore = baseScore * 1.5 // High intensity joy
        case .optimism:
            modifiedScore = baseScore * 0.9 + (emotionScores[.neutral] ?? 0.0) * 0.2
        case .gratitude:
            modifiedScore = baseScore * 0.8 + (emotionScores[.neutral] ?? 0.0) * 0.3
            
        // Sadness sub-emotions
        case .melancholy:
            modifiedScore = baseScore * 0.8 + (emotionScores[.neutral] ?? 0.0) * 0.2
        case .grief:
            modifiedScore = baseScore * 1.3 // High intensity sadness
        case .disappointment:
            modifiedScore = baseScore * 0.9 + (emotionScores[.anger] ?? 0.0) * 0.2
        case .loneliness:
            modifiedScore = baseScore * 1.0
        case .despair:
            modifiedScore = baseScore * 1.4 + (emotionScores[.fear] ?? 0.0) * 0.2
        case .sorrow:
            modifiedScore = baseScore * 1.1
            
        // Anger sub-emotions
        case .frustration:
            modifiedScore = baseScore * 0.9
        case .irritation:
            modifiedScore = baseScore * 0.7 + (emotionScores[.disgust] ?? 0.0) * 0.2
        case .rage:
            modifiedScore = baseScore * 1.5 // High intensity anger
        case .resentment:
            modifiedScore = baseScore * 1.0 + (emotionScores[.sadness] ?? 0.0) * 0.2
        case .indignation:
            modifiedScore = baseScore * 1.1
        case .hostility:
            modifiedScore = baseScore * 1.2 + (emotionScores[.disgust] ?? 0.0) * 0.3
            
        // Fear sub-emotions
        case .anxiety:
            modifiedScore = baseScore * 1.0
        case .worry:
            modifiedScore = baseScore * 0.8 + (emotionScores[.neutral] ?? 0.0) * 0.1
        case .nervousness:
            modifiedScore = baseScore * 0.9
        case .panic:
            modifiedScore = baseScore * 1.4 // High intensity fear
        case .dread:
            modifiedScore = baseScore * 1.2 + (emotionScores[.sadness] ?? 0.0) * 0.2
        case .apprehension:
            modifiedScore = baseScore * 0.8
            
        // Surprise sub-emotions
        case .amazement:
            modifiedScore = baseScore * 1.2 + (emotionScores[.joy] ?? 0.0) * 0.3
        case .astonishment:
            modifiedScore = baseScore * 1.3
        case .bewilderment:
            modifiedScore = baseScore * 1.0 + (emotionScores[.fear] ?? 0.0) * 0.2
        case .curiosity:
            modifiedScore = baseScore * 0.8 + (emotionScores[.joy] ?? 0.0) * 0.2
        case .confusion:
            modifiedScore = baseScore * 0.9 + (emotionScores[.fear] ?? 0.0) * 0.1
        case .wonder:
            modifiedScore = baseScore * 1.1 + (emotionScores[.joy] ?? 0.0) * 0.2
            
        // Disgust sub-emotions
        case .contempt:
            modifiedScore = baseScore * 1.1 + (emotionScores[.anger] ?? 0.0) * 0.3
        case .aversion:
            modifiedScore = baseScore * 0.9
        case .repulsion:
            modifiedScore = baseScore * 1.2
        case .revulsion:
            modifiedScore = baseScore * 1.3
        case .loathing:
            modifiedScore = baseScore * 1.4 + (emotionScores[.anger] ?? 0.0) * 0.2
        case .distaste:
            modifiedScore = baseScore * 0.8
            
        // Neutral variations
        case .calm:
            modifiedScore = baseScore * 1.1
        case .balanced:
            modifiedScore = baseScore * 1.0
        case .stable:
            modifiedScore = baseScore * 0.9
        case .peaceful:
            modifiedScore = baseScore * 1.2 + (emotionScores[.joy] ?? 0.0) * 0.1
        case .composed:
            modifiedScore = baseScore * 1.0
        case .indifferent:
            modifiedScore = baseScore * 0.8
        }
        
        return max(0.0, min(1.0, modifiedScore))
    }
    
    /// Determines if a prediction should be rejected due to low confidence
    private func shouldRejectLowConfidencePrediction(_ confidence: Double) -> Bool {
        return confidence < 0.4 // Configurable threshold - reject predictions below 40% confidence
    }
    
    // MARK: - Dual-Channel Fusion Logic
    
    /// Calculates confidence score for voice-based analysis
    private func calculateVoiceConfidence(emotionScores: [EmotionCategory: Double]) -> Double {
        // Calculate confidence based on score distribution
        let sortedScores = emotionScores.values.sorted(by: >)
        let topScore = sortedScores.first ?? 0.0
        let secondScore = sortedScores.count > 1 ? sortedScores[1] : 0.0
        let scoreSeparation = topScore - secondScore
        
        // Confidence is based on how distinct the primary emotion is
        return min(1.0, topScore + (scoreSeparation * 0.5))
    }
    
    /// Fuses speech and voice emotion analysis results using intelligent weighting
    private func fuseEmotionAnalysis(
        speechScores: [EmotionCategory: Double],
        speechConfidence: Double,
        speechSucceeded: Bool,
        voiceScores: [EmotionCategory: Double],
        voiceConfidence: Double
    ) -> [EmotionCategory: Double] {
        
        // Configuration thresholds
        let speechConfidenceThreshold: Double = 0.6
        let voiceConfidenceThreshold: Double = 0.5
        let combinationThreshold: Double = 0.4
        
        print("🔀 Fusing emotion analysis - Speech: \(speechConfidence), Voice: \(voiceConfidence)")
        
        // Case 1: Speech analysis failed - use voice only
        guard speechSucceeded else {
            print("📊 Using voice-only analysis (speech failed)")
            return voiceScores
        }
        
        // Case 2: High confidence speech analysis - prioritize speech
        if speechConfidence >= speechConfidenceThreshold {
            print("📊 Using speech-primary analysis (high speech confidence: \(speechConfidence))")
            return combineScores(
                primary: speechScores, primaryWeight: 0.8,
                secondary: voiceScores, secondaryWeight: 0.2
            )
        }
        
        // Case 3: High confidence voice analysis, low speech confidence - prioritize voice
        if voiceConfidence >= voiceConfidenceThreshold && speechConfidence < combinationThreshold {
            print("📊 Using voice-primary analysis (high voice confidence: \(voiceConfidence))")
            return combineScores(
                primary: voiceScores, primaryWeight: 0.7,
                secondary: speechScores, secondaryWeight: 0.3
            )
        }
        
        // Case 4: Both have reasonable confidence - balanced combination
        if speechConfidence >= combinationThreshold && voiceConfidence >= combinationThreshold {
            print("📊 Using balanced combination (Speech: \(speechConfidence), Voice: \(voiceConfidence))")
            
            // Dynamic weighting based on relative confidence
            let totalConfidence = speechConfidence + voiceConfidence
            let speechWeight = speechConfidence / totalConfidence
            let voiceWeight = voiceConfidence / totalConfidence
            
            return combineScores(
                primary: speechScores, primaryWeight: speechWeight,
                secondary: voiceScores, secondaryWeight: voiceWeight
            )
        }
        
        // Case 5: Both have low confidence - fallback to voice with warning
        print("⚠️ Both analyses have low confidence - using voice analysis as fallback")
        return voiceScores
    }
    
    /// Combines two emotion score dictionaries with specified weights
    private func combineScores(
        primary: [EmotionCategory: Double], primaryWeight: Double,
        secondary: [EmotionCategory: Double], secondaryWeight: Double
    ) -> [EmotionCategory: Double] {
        
        var combinedScores: [EmotionCategory: Double] = [:]
        
        // Initialize all emotion categories
        for emotion in EmotionCategory.allCases {
            let primaryScore = primary[emotion] ?? 0.0
            let secondaryScore = secondary[emotion] ?? 0.0
            
            combinedScores[emotion] = (primaryScore * primaryWeight) + (secondaryScore * secondaryWeight)
        }
        
        // Normalize scores to sum to 1.0
        let totalScore = combinedScores.values.reduce(0, +)
        if totalScore > 0 {
            for emotion in EmotionCategory.allCases {
                combinedScores[emotion] = combinedScores[emotion]! / totalScore
            }
        }
        
        return combinedScores
    }
    
    /// Calculates zero crossing rate for audio quality assessment
    private func calculateZeroCrossingRate(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0.0 }
        
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i-1] >= 0 && samples[i] < 0) || (samples[i-1] < 0 && samples[i] >= 0) {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(samples.count - 1)
    }
    
    // MARK: - Advanced Emotion Scoring Helpers
    
    private func normalizeValue(_ value: Float, targetRange: ClosedRange<Float>) -> Double {
        let normalized = (value - targetRange.lowerBound) / (targetRange.upperBound - targetRange.lowerBound)
        return Double(max(0.0, min(1.0, normalized)))
    }
    
    private func calculatePitchScore(_ pitch: Float, targetRange: ClosedRange<Float>, weight: Double) -> Double {
        let normalizedPitch = normalizeValue(pitch, targetRange: targetRange)
        return normalizedPitch * weight
    }
    
    private func calculateEnergyScore(_ energy: Float, targetRange: ClosedRange<Float>, weight: Double) -> Double {
        let normalizedEnergy = normalizeValue(energy, targetRange: targetRange)
        return normalizedEnergy * weight
    }
    
    private func calculateSpectralScore(_ spectralCentroid: Float, targetRange: ClosedRange<Float>, weight: Double) -> Double {
        let normalizedSpectral = normalizeValue(spectralCentroid, targetRange: targetRange)
        return normalizedSpectral * weight
    }
    
    private func calculateProsodyScore(_ prosody: ProsodyFeatures, emotion: EmotionCategory, weight: Double) -> Double {
        var score: Double = 0.0
        
        switch emotion {
        case .joy:
            // Joy: moderate pitch variation, high energy variation, moderate speaking rate
            score += normalizeValue(prosody.pitchVariation, targetRange: 0.2...0.6) * 0.4
            score += normalizeValue(prosody.energyVariation, targetRange: 0.3...0.7) * 0.4
            score += normalizeValue(prosody.speakingRate, targetRange: 2.0...4.0) * 0.2
        case .sadness:
            // Sadness: low pitch variation, low energy variation, slow speaking rate
            score += normalizeValue(prosody.pitchVariation, targetRange: 0.0...0.3) * 0.4
            score += normalizeValue(prosody.energyVariation, targetRange: 0.0...0.3) * 0.4
            score += normalizeValue(prosody.speakingRate, targetRange: 1.0...2.5) * 0.2
        case .anger:
            // Anger: high pitch variation, high energy variation, fast speaking rate
            score += normalizeValue(prosody.pitchVariation, targetRange: 0.4...0.8) * 0.4
            score += normalizeValue(prosody.energyVariation, targetRange: 0.5...0.9) * 0.4
            score += normalizeValue(prosody.speakingRate, targetRange: 3.5...5.0) * 0.2
        case .fear:
            // Fear: high pitch variation, moderate energy variation, variable speaking rate
            score += normalizeValue(prosody.pitchVariation, targetRange: 0.3...0.7) * 0.4
            score += normalizeValue(prosody.energyVariation, targetRange: 0.2...0.6) * 0.4
            score += normalizeValue(prosody.speakingRate, targetRange: 2.0...4.5) * 0.2
        case .surprise:
            // Surprise: very high pitch variation, high energy variation, fast speaking rate
            score += normalizeValue(prosody.pitchVariation, targetRange: 0.5...0.9) * 0.4
            score += normalizeValue(prosody.energyVariation, targetRange: 0.4...0.8) * 0.4
            score += normalizeValue(prosody.speakingRate, targetRange: 3.0...5.0) * 0.2
        case .disgust:
            // Disgust: low pitch variation, moderate energy variation, slow speaking rate
            score += normalizeValue(prosody.pitchVariation, targetRange: 0.0...0.4) * 0.4
            score += normalizeValue(prosody.energyVariation, targetRange: 0.2...0.5) * 0.4
            score += normalizeValue(prosody.speakingRate, targetRange: 1.5...3.0) * 0.2
        case .neutral:
            // Neutral: low pitch variation, low energy variation, moderate speaking rate
            score += normalizeValue(prosody.pitchVariation, targetRange: 0.0...0.2) * 0.4
            score += normalizeValue(prosody.energyVariation, targetRange: 0.0...0.2) * 0.4
            score += normalizeValue(prosody.speakingRate, targetRange: 2.0...3.5) * 0.2
        }
        
        return score * weight
    }
    
    private func calculateQualityScore(_ quality: VoiceQuality, weight: Double) -> Double {
        let qualityMultiplier: Double
        switch quality {
        case .excellent: qualityMultiplier = 1.0
        case .good: qualityMultiplier = 0.8
        case .fair: qualityMultiplier = 0.6
        case .poor: qualityMultiplier = 0.4
        }
        return qualityMultiplier * weight
    }
    
    private func calculateEmotionModifier(pitch: Float, energy: Float, spectralCentroid: Float, emotion: EmotionCategory) -> Double {
        var modifier = 1.0
        
        switch emotion {
        case .joy:
            // Boost joy for bright, energetic speech
            if spectralCentroid > 1500 && energy > 0.5 { modifier *= 1.2 }
            if pitch > 200 && energy > 0.6 { modifier *= 1.1 }
        case .sadness:
            // Boost sadness for low, quiet speech
            if pitch < 150 && energy < 0.4 { modifier *= 1.2 }
            if spectralCentroid < 1000 { modifier *= 1.1 }
        case .anger:
            // Boost anger for intense, harsh speech
            if energy > 0.7 && spectralCentroid > 1800 { modifier *= 1.2 }
            if pitch > 250 { modifier *= 1.1 }
        case .fear:
            // Boost fear for tense, variable speech
            if pitch > 200 && energy < 0.5 { modifier *= 1.2 }
            if spectralCentroid > 1600 { modifier *= 1.1 }
        case .surprise:
            // Boost surprise for sudden, bright speech
            if energy > 0.6 && spectralCentroid > 1700 { modifier *= 1.2 }
            if pitch > 220 { modifier *= 1.1 }
        case .disgust:
            // Boost disgust for nasal, constricted speech
            if spectralCentroid < 1200 && energy < 0.5 { modifier *= 1.2 }
            if pitch < 180 { modifier *= 1.1 }
        case .neutral:
            // Boost neutral for balanced speech
            if pitch >= 150 && pitch <= 200 && energy >= 0.3 && energy <= 0.6 { modifier *= 1.2 }
            if spectralCentroid >= 1000 && spectralCentroid <= 1500 { modifier *= 1.1 }
        }
        
        return modifier
    }
    
    // MARK: - Logging and Error Handling
    
    private func logAnalysisCompletion(result: EmotionAnalysisResult, audioURL: URL) {
        print("✅ Emotion analysis completed for \(audioURL.lastPathComponent). Primary emotion: \(result.primaryEmotion.rawValue) with confidence: \(result.confidence)")
    }
    
    private func logAnalysisError(error: EmotionAnalysisError, audioURL: URL) {
        print("❌ Emotion analysis failed for \(audioURL.lastPathComponent) with error: \(error.localizedDescription)")
        analysisError = error
    }
}

// MARK: - Production Audio Processor using Accelerate Framework
class ProductionAudioProcessor {
    
    /// Extracts MFCC features using Accelerate framework
    func extractMFCCFeatures(from samples: [Float], sampleRate: Double) throws -> [Float] {
        let frameSize = 1024
        let hopSize = 512
        let numCoefficients = 13
        let numFilters = 26
        
        // Ensure we have enough samples
        guard samples.count >= frameSize else {
            throw EmotionAnalysisError.audioTooShort
        }
        
        // Create windowed frames
        let numFrames = (samples.count - frameSize) / hopSize + 1
        var mfccCoefficients: [Float] = []
        
        for frameIndex in 0..<numFrames {
            let startIndex = frameIndex * hopSize
            let endIndex = min(startIndex + frameSize, samples.count)
            
            if endIndex - startIndex < frameSize {
                break // Skip incomplete frames
            }
            
            let frame = Array(samples[startIndex..<endIndex])
            
            // Apply Hamming window
            let windowedFrame = applyHammingWindow(frame)
            
            // Compute FFT using Accelerate
            let fftMagnitudes = computeFFTMagnitudes(windowedFrame)
            
            // Apply mel filter bank
            let melEnergies = applyMelFilterBank(fftMagnitudes, sampleRate: sampleRate, numFilters: numFilters)
            
            // Compute DCT to get MFCC coefficients
            let frameMFCC = computeDCT(melEnergies, numCoefficients: numCoefficients)
            
            mfccCoefficients.append(contentsOf: frameMFCC)
        }
        
        // Return mean MFCC coefficients across all frames
        return computeMeanMFCC(mfccCoefficients, numCoefficients: numCoefficients, numFrames: numFrames)
    }
    
    /// Extracts additional audio features
    func extractAudioFeatures(from samples: [Float], sampleRate: Double) throws -> ProductionAudioFeatures {
        let pitch = estimatePitch(samples, sampleRate: sampleRate)
        let energy = calculateRMSEnergy(samples)
        let spectralCentroid = calculateSpectralCentroid(samples, sampleRate: sampleRate)
        let zeroCrossingRate = calculateZeroCrossingRate(samples)
        let spectralRolloff = calculateSpectralRolloff(samples, sampleRate: sampleRate)
        
        // Advanced features for better emotion detection
        let jitter = calculateJitter(samples, sampleRate: sampleRate)
        let shimmer = calculateShimmer(samples, sampleRate: sampleRate)
        let formantFrequencies = calculateFormantFrequencies(samples, sampleRate: sampleRate)
        let harmonicToNoiseRatio = calculateHarmonicToNoiseRatio(samples, sampleRate: sampleRate)
        let voiceOnsetTime = calculateVoiceOnsetTime(samples, sampleRate: sampleRate)
        
        return ProductionAudioFeatures(
            pitch: pitch,
            energy: energy,
            spectralCentroid: spectralCentroid,
            zeroCrossingRate: zeroCrossingRate,
            spectralRolloff: spectralRolloff,
            jitter: jitter,
            shimmer: shimmer,
            formantFrequencies: formantFrequencies,
            harmonicToNoiseRatio: harmonicToNoiseRatio,
            voiceOnsetTime: voiceOnsetTime,
            mfccCoefficients: [] // PRODUCTION: Empty for now, will be populated by AudioProcessingService
        )
    }
    
    // MARK: - Private DSP Methods
    
    private func applyHammingWindow(_ frame: [Float]) -> [Float] {
        let n = frame.count
        return frame.enumerated().map { index, sample in
            let hammingValue = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(index) / Float(n - 1))
            return sample * hammingValue
        }
    }
    
    private func computeFFTMagnitudes(_ frame: [Float]) -> [Float] {
        let n = frame.count
        let log2n = vDSP_Length(log2(Float(n)))
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return Array(repeating: 0, count: n/2)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Allocate memory for real and imaginary parts
        let realParts = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let imagParts = UnsafeMutablePointer<Float>.allocate(capacity: n)
        
        defer {
            realParts.deallocate()
            imagParts.deallocate()
        }
        
        // Copy frame to real parts, initialize imaginary parts to zero
        realParts.initialize(from: frame, count: n)
        imagParts.initialize(repeating: 0, count: n)
        
        // Create split complex structure with proper pointers
        var splitComplex = DSPSplitComplex(realp: realParts, imagp: imagParts)
        
        // Perform FFT
        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitudes
        var magnitudes = Array(repeating: Float(0), count: n/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(n/2))
        
        // Convert to dB and apply log
        var reference: Float = 1.0
        var dbMagnitudes = magnitudes
        vDSP_vdbcon(&magnitudes, 1, &reference, &dbMagnitudes, 1, vDSP_Length(n/2), 0)
        magnitudes = dbMagnitudes
        
        return magnitudes
    }
    
    private func applyMelFilterBank(_ magnitudes: [Float], sampleRate: Double, numFilters: Int) -> [Float] {
        let numBins = magnitudes.count
        let melFilters = createMelFilterBank(numFilters: numFilters, numBins: numBins, sampleRate: sampleRate)
        
        var melEnergies = Array(repeating: Float(0), count: numFilters)
        
        for filterIndex in 0..<numFilters {
            var energy: Float = 0
            for binIndex in 0..<numBins {
                energy += magnitudes[binIndex] * melFilters[filterIndex][binIndex]
            }
            melEnergies[filterIndex] = max(energy, 1e-10) // Avoid log(0)
        }
        
        // Apply log
        //vvlogf(&melEnergies, &melEnergies, [Int32(numFilters)])
        
        var logMelEnergies = melEnergies
        vvlogf(&logMelEnergies, &melEnergies, [Int32(numFilters)])
        melEnergies = logMelEnergies
        
        return melEnergies
    }
    
    private func createMelFilterBank(numFilters: Int, numBins: Int, sampleRate: Double) -> [[Float]] {
        let lowFreq: Float = 0
        let highFreq = Float(sampleRate / 2)
        
        // Convert to mel scale
        let lowMel = 2595 * log10(1 + lowFreq / 700)
        let highMel = 2595 * log10(1 + highFreq / 700)
        
        // Create mel points
        let melPoints = (0...numFilters+1).map { i in
            lowMel + Float(i) * (highMel - lowMel) / Float(numFilters + 1)
        }
        
        // Convert back to Hz
        let hzPoints = melPoints.map { mel in
            700 * (pow(10, mel / 2595) - 1)
        }
        
        // Convert to bin indices
        let binPoints = hzPoints.map { hz in
            Int(floor((Float(numBins) * 2 * hz) / Float(sampleRate)))
        }
        
        // Create filter bank
        var filterBank = Array(repeating: Array(repeating: Float(0), count: numBins), count: numFilters)
        
        for filterIndex in 0..<numFilters {
            let leftBin = binPoints[filterIndex]
            let centerBin = binPoints[filterIndex + 1]
            let rightBin = binPoints[filterIndex + 2]
            
            // Left slope
            for bin in leftBin..<centerBin {
                if bin < numBins {
                    filterBank[filterIndex][bin] = Float(bin - leftBin) / Float(centerBin - leftBin)
                }
            }
            
            // Right slope
            for bin in centerBin..<rightBin {
                if bin < numBins {
                    filterBank[filterIndex][bin] = Float(rightBin - bin) / Float(rightBin - centerBin)
                }
            }
        }
        
        return filterBank
    }
    
    private func computeDCT(_ melEnergies: [Float], numCoefficients: Int) -> [Float] {
        let numFilters = melEnergies.count
        var mfccCoefficients = Array(repeating: Float(0), count: numCoefficients)
        
        for coeffIndex in 0..<numCoefficients {
            var sum: Float = 0
            for filterIndex in 0..<numFilters {
                sum += melEnergies[filterIndex] * cos(Float.pi * Float(coeffIndex) * (Float(filterIndex) + 0.5) / Float(numFilters))
            }
            mfccCoefficients[coeffIndex] = sum
        }
        
        return mfccCoefficients
    }
    
    private func computeMeanMFCC(_ allCoefficients: [Float], numCoefficients: Int, numFrames: Int) -> [Float] {
        guard numFrames > 0 else { return Array(repeating: 0, count: numCoefficients) }
        
        var meanCoefficients = Array(repeating: Float(0), count: numCoefficients)
        
        for coeffIndex in 0..<numCoefficients {
            var sum: Float = 0
            for frameIndex in 0..<numFrames {
                let index = frameIndex * numCoefficients + coeffIndex
                if index < allCoefficients.count {
                    sum += allCoefficients[index]
                }
            }
            meanCoefficients[coeffIndex] = sum / Float(numFrames)
        }
        
        return meanCoefficients
    }
    
    private func estimatePitch(_ samples: [Float], sampleRate: Double) -> Float {
        // Simple autocorrelation-based pitch estimation
        let minPeriod = Int(sampleRate / 800) // 800 Hz max
        let maxPeriod = Int(sampleRate / 80)  // 80 Hz min
        
        var maxCorrelation: Float = 0
        var bestPeriod = minPeriod
        
        for period in minPeriod...min(maxPeriod, samples.count / 2) {
            var correlation: Float = 0
            let numSamples = samples.count - period
            
            for i in 0..<numSamples {
                correlation += samples[i] * samples[i + period]
            }
            
            correlation /= Float(numSamples)
            
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestPeriod = period
            }
        }
        
        return Float(sampleRate) / Float(bestPeriod)
    }
    
    private func calculateRMSEnergy(_ samples: [Float]) -> Float {
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
    
    private func calculateSpectralCentroid(_ samples: [Float], sampleRate: Double) -> Float {
        let magnitudes = computeFFTMagnitudes(samples)
        let numBins = magnitudes.count
        
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for i in 0..<numBins {
            let frequency = Float(i) * Float(sampleRate) / Float(samples.count)
            weightedSum += frequency * magnitudes[i]
            magnitudeSum += magnitudes[i]
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
    }
    
    private func calculateZeroCrossingRate(_ samples: [Float]) -> Float {
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i-1] >= 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(samples.count - 1)
    }
    
    private func calculateSpectralRolloff(_ samples: [Float], sampleRate: Double) -> Float {
        let magnitudes = computeFFTMagnitudes(samples)
        let totalEnergy = magnitudes.reduce(0, +)
        let threshold = totalEnergy * 0.85 // 85% rolloff
        
        var cumulativeEnergy: Float = 0
        for i in 0..<magnitudes.count {
            cumulativeEnergy += magnitudes[i]
            if cumulativeEnergy >= threshold {
                return Float(i) * Float(sampleRate) / Float(samples.count)
            }
        }
        
        return Float(sampleRate) / 2 // Nyquist frequency
    }
    
    // MARK: - Advanced Feature Calculations (New)
    
    private func calculateJitter(_ samples: [Float], sampleRate: Double) -> Float {
        let pitch = estimatePitch(samples, sampleRate: sampleRate)
        guard pitch > 0 else { return 0 }
        
        // Calculate period based on pitch
        let period = Int(Double(sampleRate) / Double(pitch))
        let minPeriod = max(period - 2, Int(sampleRate / 800)) // 800 Hz max
        let maxPeriod = min(period + 2, Int(sampleRate / 80))  // 80 Hz min
        
        var sumJitter: Float = 0
        var numPeriods: Int = 0
        
        for period in minPeriod...maxPeriod {
            let numSamples = samples.count - period
            if numSamples < 0 { break }
            
            var sumDiff: Float = 0
            for i in 0..<numSamples {
                sumDiff += abs(samples[i] - samples[i + period])
            }
            sumDiff /= Float(numSamples)
            
            sumJitter += sumDiff
            numPeriods += 1
        }
        
        return numPeriods > 0 ? sumJitter / Float(numPeriods) : 0
    }
    
    private func calculateShimmer(_ samples: [Float], sampleRate: Double) -> Float {
        let pitch = estimatePitch(samples, sampleRate: sampleRate)
        guard pitch > 0 else { return 0 }
        
        // Calculate period based on pitch
        let period = Int(Double(sampleRate) / Double(pitch))
        let minPeriod = max(period - 2, Int(sampleRate / 800)) // 800 Hz max
        let maxPeriod = min(period + 2, Int(sampleRate / 80))  // 80 Hz min
        
        var sumShimmer: Float = 0
        var numPeriods: Int = 0
        
        for period in minPeriod...maxPeriod {
            let numSamples = samples.count - period
            if numSamples < 0 { break }
            
            var sumDiff: Float = 0
            for i in 0..<numSamples {
                sumDiff += abs(samples[i] - samples[i + period])
            }
            sumDiff /= Float(numSamples)
            
            sumShimmer += sumDiff
            numPeriods += 1
        }
        
        return numPeriods > 0 ? sumShimmer / Float(numPeriods) : 0
    }
    
    private func calculateFormantFrequencies(_ samples: [Float], sampleRate: Double) -> [Float] {
        let magnitudes = computeFFTMagnitudes(samples)
        let numBins = magnitudes.count
        
        var formantFreqs: [Float] = []
        
        // Find peaks using proper bin analysis
        let threshold = magnitudes.max()! * 0.3 // 30% of max magnitude for better detection
        var peakIndices: [Int] = []
        
        for i in 1..<numBins-1 {
            if magnitudes[i] > threshold &&
               magnitudes[i] > magnitudes[i-1] &&
               magnitudes[i] > magnitudes[i+1] {
                peakIndices.append(i)
            }
        }
        
        // Sort peaks by magnitude and take top 3
        let sortedPeaks = peakIndices.sorted { magnitudes[$0] > magnitudes[$1] }
        let topPeaks = Array(sortedPeaks.prefix(3))
        
        // Convert bin indices to frequencies
        for peakIndex in topPeaks {
            let frequency = Float(peakIndex) * Float(sampleRate) / Float(samples.count)
            
            // Filter for human speech formant range (80Hz - 4000Hz)
            if frequency >= 80 && frequency <= 4000 {
                formantFreqs.append(frequency)
            }
        }
        
        // Pad with zeros if we don't have enough formants
        while formantFreqs.count < 3 {
            formantFreqs.append(0.0)
        }
        
        return Array(formantFreqs.prefix(3))
    }
    
    private func calculateHarmonicToNoiseRatio(_ samples: [Float], sampleRate: Double) -> Float {
        let magnitudes = computeFFTMagnitudes(samples)
        let numBins = magnitudes.count
        
        // Find fundamental frequency (first significant peak)
        let threshold = magnitudes.max()! * 0.3 // 30% of max magnitude
        var fundamentalIndex = 0
        
        for i in 1..<numBins-1 {
            if magnitudes[i] > threshold &&
               magnitudes[i] > magnitudes[i-1] &&
               magnitudes[i] > magnitudes[i+1] {
                fundamentalIndex = i
                break
            }
        }
        
        // Calculate harmonic energy (energy around harmonic frequencies)
        var harmonicEnergy: Float = 0
        var noiseEnergy: Float = 0
        
        // Calculate energy around fundamental and its harmonics
        for harmonic in 1...5 {
            let harmonicIndex = fundamentalIndex * harmonic
            if harmonicIndex < numBins {
                // Add energy from harmonic and nearby bins
                let startBin = max(0, harmonicIndex - 2)
                let endBin = min(numBins - 1, harmonicIndex + 2)
                
                for i in startBin...endBin {
                    harmonicEnergy += magnitudes[i] * magnitudes[i]
                }
            }
        }
        
        // Calculate noise energy (total energy minus harmonic energy)
        let totalEnergy = magnitudes.reduce(0) { $0 + $1 * $1 }
        noiseEnergy = totalEnergy - harmonicEnergy
        
        // Return HNR in dB
        return noiseEnergy > 0 ? 10 * log10(harmonicEnergy / noiseEnergy) : 0
    }
    
    private func calculateVoiceOnsetTime(_ samples: [Float], sampleRate: Double) -> Float {
        let threshold = Float(0.05) // 5% of max amplitude
        let startIndex = samples.firstIndex(where: { abs($0) > threshold }) ?? 0
        return Float(startIndex) / Float(sampleRate)
    }
}

// MARK: - Supporting Types

struct ProsodyFeatures {
    let pitchVariation: Float
    let energyVariation: Float
    let spectralVariation: Float
    let speakingRate: Float
}

/// Represents emotion-specific feature weights for targeted analysis
struct EmotionFeatureWeights {
    let pitch: Double
    let energy: Double
    let spectralCentroid: Double
    let zeroCrossingRate: Double
    let spectralRolloff: Double
    let jitter: Double
    let shimmer: Double
    let harmonicToNoiseRatio: Double
    let voiceOnsetTime: Double
    let formant1: Double
    let formant2: Double
    
    init(
        pitch: Double = 1.0,
        energy: Double = 1.0,
        spectralCentroid: Double = 1.0,
        zeroCrossingRate: Double = 1.0,
        spectralRolloff: Double = 1.0,
        jitter: Double = 1.0,
        shimmer: Double = 1.0,
        harmonicToNoiseRatio: Double = 1.0,
        voiceOnsetTime: Double = 1.0,
        formant1: Double = 1.0,
        formant2: Double = 1.0
    ) {
        self.pitch = pitch
        self.energy = energy
        self.spectralCentroid = spectralCentroid
        self.zeroCrossingRate = zeroCrossingRate
        self.spectralRolloff = spectralRolloff
        self.jitter = jitter
        self.shimmer = shimmer
        self.harmonicToNoiseRatio = harmonicToNoiseRatio
        self.voiceOnsetTime = voiceOnsetTime
        self.formant1 = formant1
        self.formant2 = formant2
    }
}

