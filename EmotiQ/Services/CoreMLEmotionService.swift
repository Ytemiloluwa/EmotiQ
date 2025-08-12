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
            // 1. Load and convert .m4a to PCM samples
            print("📁 Loading audio file...")
            let audioSamples = try await loadAudioSamples(from: audioURL)
            print("✅ Loaded \(audioSamples.count) audio samples")
            
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
            
            // 5. Run CoreML inference
            print("🧠 Running CoreML inference...")
            let emotionScores = try await runEmotionInference(featureVector: featureVector)
            print("✅ Got emotion predictions: \(emotionScores)")
            
            // 6. Create analysis result
            let result = createAnalysisResult(
                emotionScores: emotionScores,
                audioQuality: assessAudioQuality(audioSamples),
                sessionDuration: Double(audioSamples.count) / Config.sampleRate
            )
            
            lastAnalysisResult = result
            analysisError = nil
            
            print("🎉 Emotion analysis completed successfully")
            return result
            
        } catch let error as EmotionAnalysisError {
            print("❌ Emotion analysis error: \(error.localizedDescription)")
            analysisError = error
            throw error
        } catch {
            print("❌ Unexpected error: \(error.localizedDescription)")
            let analysisError = EmotionAnalysisError.analysisFailure(error.localizedDescription)
            self.analysisError = analysisError
            throw analysisError
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
                    // For development, create a simple mock model that works with our feature vector
                    print("⚠️ Custom model not found, using development fallback")
                    // We'll handle this in the inference method
                }
            } catch {
                print("❌ Failed to load emotion model: \(error)")
                await MainActor.run {
                    self.analysisError = .modelNotLoaded
                }
            }
        }
    }
    
    /// Loads audio samples from .m4a file using AVAssetReader
    private func loadAudioSamples(from url: URL) async throws -> [Float] {
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
    
    /// Creates feature vector by combining MFCC and audio features
    private func createFeatureVector(mfcc: [Float], audioFeatures: ProductionAudioFeatures) -> [Float] {
        var featureVector = mfcc
        featureVector.append(audioFeatures.pitch)
        featureVector.append(audioFeatures.energy)
        featureVector.append(audioFeatures.spectralCentroid)
        featureVector.append(audioFeatures.zeroCrossingRate)
        featureVector.append(audioFeatures.spectralRolloff)
        return featureVector
    }
    
    /// Runs emotion inference using CoreML or fallback logic
    private func runEmotionInference(featureVector: [Float]) async throws -> [EmotionCategory: Double] {
        if let model = model {
            // Use real CoreML model
            return try await runCoreMLInference(model: model, featureVector: featureVector)
        } else {
            // Development fallback - analyze features to determine emotion
            return generateEmotionScoresFromFeatures(featureVector: featureVector)
        }
    }
    
    /// Runs inference using actual CoreML model
    private func runCoreMLInference(model: MLModel, featureVector: [Float]) async throws -> [EmotionCategory: Double] {
        // Create MLMultiArray from feature vector
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: featureVector.count)], dataType: .float32)
        
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
    
    /// Generates emotion scores from audio features (development fallback)
    private func generateEmotionScoresFromFeatures(featureVector: [Float]) -> [EmotionCategory: Double] {
        // Extract key features for emotion analysis
        let mfccMean = featureVector.prefix(Config.numMFCCCoefficients).reduce(0, +) / Float(Config.numMFCCCoefficients)
        let pitch = featureVector[Config.numMFCCCoefficients]
        let energy = featureVector[Config.numMFCCCoefficients + 1]
        let spectralCentroid = featureVector[Config.numMFCCCoefficients + 2]
        
        // Analyze features to determine emotional state
        var emotionScores: [EmotionCategory: Double] = [:]
        
        // High energy + high pitch = excitement/joy
        if energy > 0.6 && pitch > 200 {
            emotionScores[.joy] = 0.7 + Double.random(in: 0...0.2)
            emotionScores[.surprise] = 0.3 + Double.random(in: 0...0.2)
        }
        // Low energy + low pitch = sadness
        else if energy < 0.3 && pitch < 150 {
            emotionScores[.sadness] = 0.6 + Double.random(in: 0...0.3)
            emotionScores[.neutral] = 0.2 + Double.random(in: 0...0.2)
        }
        // High spectral centroid + moderate energy = anger
        else if spectralCentroid > 2000 && energy > 0.4 {
            emotionScores[.anger] = 0.5 + Double.random(in: 0...0.3)
            emotionScores[.disgust] = 0.2 + Double.random(in: 0...0.2)
        }
        // Low energy + variable pitch = fear
        else if energy < 0.4 && abs(mfccMean) > 0.5 {
            emotionScores[.fear] = 0.4 + Double.random(in: 0...0.3)
            emotionScores[.neutral] = 0.3 + Double.random(in: 0...0.2)
        }
        // Default to neutral with some variation
        else {
            emotionScores[.neutral] = 0.5 + Double.random(in: 0...0.3)
            emotionScores[.joy] = 0.2 + Double.random(in: 0...0.2)
        }
        
        // Fill in remaining emotions with low scores
        for emotion in EmotionCategory.allCases {
            if emotionScores[emotion] == nil {
                emotionScores[emotion] = Double.random(in: 0...0.2)
            }
        }
        
        // Normalize scores to sum to 1.0
        let totalScore = emotionScores.values.reduce(0, +)
        for emotion in EmotionCategory.allCases {
            emotionScores[emotion] = emotionScores[emotion]! / totalScore
        }
        
        return emotionScores
    }
    
    /// Assesses audio quality based on signal characteristics
    private func assessAudioQuality(_ samples: [Float]) -> AudioQuality {
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0
        
        if rms > 0.1 && maxAmplitude > 0.3 {
            return .excellent
        } else if rms > 0.05 && maxAmplitude > 0.2 {
            return .good
        } else if rms > 0.02 && maxAmplitude > 0.1 {
            return .fair
        } else {
            return .poor
        }
    }
    
    /// Creates final analysis result
    private func createAnalysisResult(
        emotionScores: [EmotionCategory: Double],
        audioQuality: AudioQuality,
        sessionDuration: TimeInterval
    ) -> EmotionAnalysisResult {
        // Find primary emotion
        let (primaryEmotion, confidence) = emotionScores.max { $0.value < $1.value } ?? (.neutral, 0.5)
        
        return EmotionAnalysisResult(
            timestamp: Date(),
            primaryEmotion: primaryEmotion,
            confidence: confidence,
            emotionScores: emotionScores,
            audioQuality: audioQuality,
            sessionDuration: sessionDuration
        )
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
        
        return ProductionAudioFeatures(
            pitch: pitch,
            energy: energy,
            spectralCentroid: spectralCentroid,
            zeroCrossingRate: zeroCrossingRate,
            spectralRolloff: spectralRolloff
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
        
        var realParts = frame
        var imagParts = Array(repeating: Float(0), count: n)
        
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        var magnitudes = Array(repeating: Float(0), count: n/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(n/2))
        
        // Convert to dB and apply log
        //vDSP_vdbcon(&magnitudes, 1, &magnitudes, 1, vDSP_Length(n/2), 1, 1)
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
}

// MARK: - Supporting Types

//struct ProductionAudioFeatures {
//    let pitch: Float
//    let energy: Float
//    let tempo: Float
//    let spectralCentroid: Float
//    let zeroCrossingRate: Float
//    let spectralRolloff: Float
//}


// MARK: - Error Types
enum EmotionAnalysisError: LocalizedError {
    case modelNotLoaded
    case audioTooShort
    case audioTooLong
    case invalidAudioFormat
    case audioProcessingFailed
    case analysisFailure(String)
    case invalidModelOutput
    case recordingFailed
    case analysisTimeout
    case serviceUnavailable
    case invalidAudioData
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Emotion analysis model is not loaded"
        case .audioTooShort:
            return "Audio recording is too short for analysis (minimum 1 second)"
        case .audioTooLong:
            return "Audio recording is too long for analysis (maximum 2 minutes)"
        case .invalidAudioFormat:
            return "Invalid audio format for emotion analysis"
        case .audioProcessingFailed:
            return "Failed to process audio data"
        case .analysisFailure(let message):
            return "Emotion analysis failed: \(message)"
        case .invalidModelOutput:
            return "Invalid output from emotion analysis model"
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

