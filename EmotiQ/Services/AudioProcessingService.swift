//
//  AudioProcessingService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 05-08-2025.
//

//  Production-ready audio processing service with real feature extraction
//

import Foundation
import Combine
import AVFoundation
import Accelerate

// MARK: - Production Audio Processing Service
class AudioProcessingService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var audioLevelsArray: [Float] = Array(repeating: 0.0, count: 20)
    @Published var recordingError: AudioProcessingError?
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var audioLevelTimer: Timer?
    private var recordingURL: URL?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Audio Level Publishers
    private let audioLevelSubject = PassthroughSubject<Float, Never>()
    private let audioLevelsArraySubject = PassthroughSubject<[Float], Never>()
    
    var audioLevels: AnyPublisher<Float, Never> {
        audioLevelSubject.eraseToAnyPublisher()
    }
    
    var audioLevelsArrayPublisher: AnyPublisher<[Float], Never> {
        audioLevelsArraySubject.eraseToAnyPublisher()
    }
    
    // MARK: - Configuration
    private struct Config {
        static let sampleRate: Double = 44100
        static let channels: UInt32 = 1
        static let bitDepth: UInt32 = 16
        static let audioFormat = kAudioFormatMPEG4AAC
        static let audioQuality = AVAudioQuality.high
        static let levelUpdateInterval: TimeInterval = 0.05 // 20 FPS
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    /// Starts recording audio with real-time level monitoring
    func startRecording() async throws -> URL {
        
        
        // Request microphone permission
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw AudioProcessingError.permissionDenied
        }
        
        // Setup recording
        try setupRecording()
        
        // Start recording
        guard audioRecorder?.record() == true else {
            throw AudioProcessingError.recordingFailed
        }
        
        isRecording = true
        recordingDuration = 0
        audioLevel = 0
        audioLevelsArray = Array(repeating: 0.0, count: 20)
        
        // Start timers
        startRecordingTimer()
        startAudioLevelTimer()
        

        return recordingURL!
    }
    
    /// Stops recording and returns the recorded audio URL
    func stopRecording() async throws -> URL {
        
        
        guard isRecording else {
            throw AudioProcessingError.recordingFailed
        }
        
        // Stop recording
        audioRecorder?.stop()
        stopTimers()
        
        isRecording = false
        audioLevel = 0
        audioLevelsArray = Array(repeating: 0.0, count: 20)
        
        // Clean up audio session
        cleanupAudioSession()
        
        // Reset audio recorder for next use
        audioRecorder = nil
        
        // Verify recording file exists
        guard let url = recordingURL, FileManager.default.fileExists(atPath: url.path) else {
            throw AudioProcessingError.recordingFailed
        }
        
    
        return url
    }
    
    /// Cancels current recording
    func cancelRecording() {

        
        audioRecorder?.stop()
        stopTimers()
        
        isRecording = false
        recordingDuration = 0
        audioLevel = 0
        audioLevelsArray = Array(repeating: 0.0, count: 20)
        
        // Clean up audio session
        cleanupAudioSession()
        
        // Reset audio recorder for next use
        audioRecorder = nil
        
        // Delete recording file if it exists
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordingURL = nil
    }
    
    /// Extracts production-ready audio features from recorded data
    func extractFeatures(from audioURL: URL) async throws -> ProductionAudioFeatures {
 
        
        // Load audio samples
        let audioSamples = try await loadAudioSamples(from: audioURL)
     
        
        // Extract features using production algorithms
        let features = try extractProductionFeatures(from: audioSamples)
        
        
        return features
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        Task {
            do {
                try await AudioSessionManager.shared.configureAudioSession(for: .recording)
         
            } catch {
        
                recordingError = .audioSessionFailed
            }
        }
    }
    
    private func cleanupAudioSession() {
        Task {
            try await AudioSessionManager.shared.deactivateAudioSession()
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func setupRecording() throws {
        // Ensure any existing recorder is cleaned up first
        if let existingRecorder = audioRecorder {
            existingRecorder.stop()
            audioRecorder = nil
        }
        
        // Create unique recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Date().timeIntervalSince1970
        recordingURL = documentsPath.appendingPathComponent("voice_recording_\(timestamp).m4a")
        
        guard let url = recordingURL else {
            throw AudioProcessingError.recordingFailed
        }
        
        // Configure recording settings for high quality
        let settings: [String: Any] = [
            AVFormatIDKey: Int(Config.audioFormat),
            AVSampleRateKey: Config.sampleRate,
            AVNumberOfChannelsKey: Config.channels,
            AVEncoderAudioQualityKey: Config.audioQuality.rawValue,
            AVEncoderBitRateKey: 128000 // 128 kbps for good quality
        ]
        
        // Create audio recorder
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        
    }
    

    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 0.1
            
            // Auto-stop after 2 minutes
            if self.recordingDuration >= 120 {
                Task {
                    try? await self.stopRecording()
                }
            }
        }
    }
    
    private func startAudioLevelTimer() {
        // Create timer and add to main run loop
        audioLevelTimer = Timer(timeInterval: Config.levelUpdateInterval, repeats: true) { [weak self] _ in
            self?.audioRecorder?.updateMeters()
            if let recorder = self?.audioRecorder {
                let averagePower = recorder.averagePower(forChannel: 0)
                let normalizedLevel = self?.normalizeAudioLevel(averagePower) ?? 0
                
                DispatchQueue.main.async {
                    self?.audioLevel = normalizedLevel
                    self?.audioLevelSubject.send(normalizedLevel)
                    
                    // Update animated bars array
                    self?.updateAudioLevelsArray(with: normalizedLevel)
                }
            }
        }
        
        // Add timer to main run loop
        //RunLoop.main.add(audioLevelTimer!, forMode: .common)
    }
    
    private func updateAudioLevelsArray(with newLevel: Float) {
        // Remove the first element and add the new level at the end
        audioLevelsArray.removeFirst()
        audioLevelsArray.append(newLevel)
        
        // Send the updated array for animated bars
        audioLevelsArraySubject.send(audioLevelsArray)
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        audioLevelTimer?.invalidate()
        recordingTimer = nil
        audioLevelTimer = nil
    }
    
    private func normalizeAudioLevel(_ averagePower: Float) -> Float {
        // Convert dB to linear scale (0-1)
        // averagePower ranges from -160 dB (silence) to 0 dB (max)
        let minDb: Float = -60 // Threshold for silence
        let maxDb: Float = 0   // Maximum level
        
        let clampedPower = max(min(averagePower, maxDb), minDb)
        let normalizedLevel = (clampedPower - minDb) / (maxDb - minDb)
        
        return max(normalizedLevel, 0)
    }
    
    private func loadAudioSamples(from url: URL) async throws -> [Float] {
        let asset = AVAsset(url: url)
        
        // Load audio track
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioProcessingError.invalidAudioFormat
        }
        
        // Create asset reader
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
            throw AudioProcessingError.audioProcessingFailed
        }
        
        var audioSamples: [Float] = []
        
        while reader.status == .reading {
            if let sampleBuffer = output.copyNextSampleBuffer() {
                let samples = try extractFloatSamples(from: sampleBuffer)
                audioSamples.append(contentsOf: samples)
            }
        }
        
        guard reader.status == .completed else {
            throw AudioProcessingError.audioProcessingFailed
        }
        
        return audioSamples
    }
    
    private func extractFloatSamples(from sampleBuffer: CMSampleBuffer) throws -> [Float] {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            throw AudioProcessingError.audioProcessingFailed
        }
        
        let length = CMBlockBufferGetDataLength(blockBuffer)
        let floatCount = length / MemoryLayout<Float>.size
        let samples = UnsafeMutablePointer<Float>.allocate(capacity: floatCount)
        defer { samples.deallocate() }
        
        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: samples)
        
        return Array(UnsafeBufferPointer(start: samples, count: floatCount))
    }
    
    private func extractProductionFeatures(from samples: [Float]) throws -> ProductionAudioFeatures {
        // Calculate fundamental frequency (pitch) using autocorrelation
        let pitch = estimatePitch(samples, sampleRate: Config.sampleRate)
        
        // Calculate RMS energy
        let energy = calculateRMSEnergy(samples)
        
        // Calculate spectral centroid using FFT
        let spectralCentroid = calculateSpectralCentroid(samples, sampleRate: Config.sampleRate)
        
        // Calculate zero crossing rate
        let zeroCrossingRate = calculateZeroCrossingRate(samples)
        
        // Calculate spectral rolloff
        let spectralRolloff = calculateSpectralRolloff(samples, sampleRate: Config.sampleRate)
        
        // Advanced features for better emotion detection
        let jitter = calculateJitter(samples, sampleRate: Config.sampleRate)
        let shimmer = calculateShimmer(samples, sampleRate: Config.sampleRate)
        let formantFrequencies = calculateFormantFrequencies(samples, sampleRate: Config.sampleRate)
        let harmonicToNoiseRatio = calculateHarmonicToNoiseRatio(samples, sampleRate: Config.sampleRate)
        let voiceOnsetTime = calculateVoiceOnsetTime(samples, sampleRate: Config.sampleRate)
        
        // PRODUCTION: Extract MFCC coefficients for voice features
        let mfccCoefficients = try extractMFCCFeatures(from: samples, sampleRate: Config.sampleRate)
        
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
            mfccCoefficients: mfccCoefficients // PRODUCTION: Real MFCC coefficients
        )
    }
    
    // MARK: - DSP Feature Extraction Methods
    
    private func estimatePitch(_ samples: [Float], sampleRate: Double) -> Float {
        // Autocorrelation-based pitch estimation
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
        let rms = sqrt(sumOfSquares / Float(samples.count))
        
        // Convert to dB with noise floor protection
        let db = 20 * log10(max(rms, 0.0001)) // -80dB noise floor
        
        // Normalize to 0.0-1.0 range: -60dB to 0dB maps to 0.0-1.0
        let normalizedDB = max(0, min(1, (db + 60) / 60))
        
        return normalizedDB
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
    
    // MARK: - Advanced Feature Calculations
    
    private func calculateJitter(_ samples: [Float], sampleRate: Double) -> Float {
        // Jitter: cycle-to-cycle variation in fundamental frequency
        let pitch = estimatePitch(samples, sampleRate: sampleRate)
        guard pitch > 0 else { return 0 }
        
        let period = Int(Double(sampleRate) / Double(pitch))
        guard period > 0 && period < samples.count / 2 else { return 0 }
        
        var periods: [Int] = []
        var currentIndex = 0
        
        // Find period boundaries using zero crossings
        while currentIndex + period < samples.count {
            let nextZeroCrossing = findNextZeroCrossing(samples, from: currentIndex)
            if nextZeroCrossing > 0 {
                periods.append(nextZeroCrossing - currentIndex)
                currentIndex = nextZeroCrossing
            } else {
                break
            }
        }
        
        guard periods.count > 2 else { return 0 }
        
        // Calculate jitter as relative average perturbation
        let meanPeriod = Float(periods.reduce(0, +)) / Float(periods.count)
        var sumJitter: Float = 0
        
        for i in 1..<periods.count {
            let diff = abs(Float(periods[i]) - Float(periods[i-1]))
            sumJitter += diff
        }
        
        return periods.count > 1 ? (sumJitter / Float(periods.count - 1)) / meanPeriod : 0
    }
    
    private func calculateShimmer(_ samples: [Float], sampleRate: Double) -> Float {
        // Shimmer: cycle-to-cycle variation in amplitude
        let pitch = estimatePitch(samples, sampleRate: sampleRate)
        guard pitch > 0 else { return 0 }
        
        let period = Int(Double(sampleRate) / Double(pitch))
        guard period > 0 && period < samples.count / 2 else { return 0 }
        
        var amplitudes: [Float] = []
        var currentIndex = 0
        
        // Find peak amplitudes for each period
        while currentIndex + period < samples.count {
            let nextZeroCrossing = findNextZeroCrossing(samples, from: currentIndex)
            if nextZeroCrossing > 0 {
                let periodSamples = Array(samples[currentIndex..<nextZeroCrossing])
                let peakAmplitude = periodSamples.map { abs($0) }.max() ?? 0
                amplitudes.append(peakAmplitude)
                currentIndex = nextZeroCrossing
            } else {
                break
            }
        }
        
        guard amplitudes.count > 2 else { return 0 }
        
        // Calculate shimmer as relative average perturbation
        let meanAmplitude = amplitudes.reduce(0, +) / Float(amplitudes.count)
        var sumShimmer: Float = 0
        
        for i in 1..<amplitudes.count {
            let diff = abs(amplitudes[i] - amplitudes[i-1])
            sumShimmer += diff
        }
        
        return amplitudes.count > 1 ? (sumShimmer / Float(amplitudes.count - 1)) / meanAmplitude : 0
    }
    
    private func findNextZeroCrossing(_ samples: [Float], from startIndex: Int) -> Int {
        guard startIndex < samples.count - 1 else { return -1 }
        
        for i in startIndex..<samples.count - 1 {
            if (samples[i] >= 0 && samples[i + 1] < 0) || (samples[i] < 0 && samples[i + 1] >= 0) {
                return i + 1
            }
        }
        
        return -1
    }
    
    private func calculateFormantFrequencies(_ samples: [Float], sampleRate: Double) -> [Float] {
        let magnitudes = computeFFTMagnitudes(samples)
        let numBins = magnitudes.count
        
        var formantFreqs: [Float] = []
        
        // Apply smoothing to reduce noise
        let smoothedMagnitudes = applySmoothing(magnitudes, windowSize: 5)
        
        // Find peaks using peak detection algorithm with proper bin analysis
        let peaks = findPeaks(smoothedMagnitudes, minPeakHeight: 0.3)
        
        // Sort peaks by magnitude and take top 3
        let sortedPeaks = peaks.sorted { smoothedMagnitudes[$0] > smoothedMagnitudes[$1] }
        let topPeaks = Array(sortedPeaks.prefix(3))
        
        // Convert bin indices to frequencies and filter by human speech range
        for peakIndex in topPeaks {
            let frequency = Float(peakIndex) * Float(sampleRate) / Float(numBins * 2) // Proper frequency calculation
            
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
    
    private func applySmoothing(_ data: [Float], windowSize: Int) -> [Float] {
        var smoothed: [Float] = []
        let halfWindow = windowSize / 2
        
        for i in 0..<data.count {
            let start = max(0, i - halfWindow)
            let end = min(data.count, i + halfWindow + 1)
            let window = Array(data[start..<end])
            let average = window.reduce(0, +) / Float(window.count)
            smoothed.append(average)
        }
        
        return smoothed
    }
    
    private func findPeaks(_ data: [Float], minPeakHeight: Float) -> [Int] {
        var peaks: [Int] = []
        
        for i in 1..<data.count - 1 {
            if data[i] > data[i-1] && data[i] > data[i+1] && data[i] > minPeakHeight {
                peaks.append(i)
            }
        }
        
        return peaks
    }
    
    private func calculateHarmonicToNoiseRatio(_ samples: [Float], sampleRate: Double) -> Float {
        let magnitudes = computeFFTMagnitudes(samples)
        let numBins = magnitudes.count
        
        // Find fundamental frequency
        let pitch = estimatePitch(samples, sampleRate: sampleRate)
        guard pitch > 0 else { return 0 }
        
        var harmonicEnergy: Float = 0
        var noiseEnergy: Float = 0
        
        // Calculate energy around harmonic frequencies
        for harmonic in 1...5 {
            let harmonicFreq = pitch * Float(harmonic)
            let binIndex = Int(harmonicFreq * Float(samples.count) / Float(sampleRate))
            
            if binIndex < numBins {
                // Add energy from harmonic and nearby bins
                let startBin = max(0, binIndex - 2)
                let endBin = min(numBins - 1, binIndex + 2)
                
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
        // Voice Onset Time: time between consonant release and vocal fold vibration
        let windowSize = Int(0.025 * sampleRate) // 25ms windows
        let hopSize = Int(0.010 * sampleRate)     // 10ms hop
        
        var onsetTime: Float = 0
        var foundOnset = false
        
        // Look for sudden increase in energy (consonant release)
        for i in stride(from: 0, to: samples.count - windowSize, by: hopSize) {
            let window = Array(samples[i..<min(i + windowSize, samples.count)])
            let energy = calculateRMSEnergy(window)
            
            // Check if this is a significant energy increase
            if energy > 0.1 && !foundOnset {
                // Now look for vocal fold vibration (periodic signal)
                let nextWindow = Array(samples[min(i + windowSize, samples.count)..<min(i + 2 * windowSize, samples.count)])
                let pitch = estimatePitch(nextWindow, sampleRate: sampleRate)
                
                if pitch > 80 { // Vocal fold vibration detected
                    onsetTime = Float(i) / Float(sampleRate)
                    foundOnset = true
                    break
                }
            }
        }
        
        return onsetTime
    }
    
    private func computeFFTMagnitudes(_ samples: [Float]) -> [Float] {
        let n = samples.count
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
        
        // Copy samples to real parts, initialize imaginary parts to zero
        realParts.initialize(from: samples, count: n)
        imagParts.initialize(repeating: 0, count: n)
        
        // Create split complex structure with proper pointers
        var splitComplex = DSPSplitComplex(realp: realParts, imagp: imagParts)
        
        // Perform FFT
        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitudes
        var magnitudes = Array(repeating: Float(0), count: n/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(n/2))
        
        return magnitudes
    }
    
    // MARK: - MFCC Feature Extraction
    
    /// Extracts MFCC features using Accelerate framework
    private func extractMFCCFeatures(from samples: [Float], sampleRate: Double) throws -> [Float] {
        let frameSize = 1024
        let hopSize = 512
        let numCoefficients = 13
        let numFilters = 26
        
        // Ensure we have enough samples
        guard samples.count >= frameSize else {
            throw AudioProcessingError.featureExtractionFailed
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
    
    private func applyHammingWindow(_ frame: [Float]) -> [Float] {
        let n = frame.count
        return frame.enumerated().map { index, sample in
            let hammingValue = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(index) / Float(n - 1))
            return sample * hammingValue
        }
    }
    
    private func applyMelFilterBank(_ fftMagnitudes: [Float], sampleRate: Double, numFilters: Int) -> [Float] {
        let numBins = fftMagnitudes.count
        let maxFreq = Float(sampleRate) / 2.0
        let minFreq = 0.0
        let maxMel = 2595.0 * log10(1.0 + maxFreq / 700.0)
        let minMel = 2595.0 * log10(1.0 + minFreq / 700.0)
        let melStep = (maxMel - Float(minMel)) / Float(numFilters + 1)
        
        var melEnergies = Array(repeating: Float(0), count: numFilters)
        
        for filterIndex in 0..<numFilters {
            let centerMel = minMel + Double(filterIndex + 1) * Double(melStep)
            let centerFreq = 700.0 * (pow(10.0, Double(centerMel) / 2595.0) - 1.0)
            
            for binIndex in 0..<numBins {
                let binFreq = Float(binIndex) * Float(sampleRate) / Float(numBins * 2)
                let melFreq = 2595.0 * log10(1.0 + binFreq / 700.0)
                
                let filterResponse = calculateTriangularFilterResponse(melFreq, Float(centerMel), melStep)
                melEnergies[filterIndex] += fftMagnitudes[binIndex] * filterResponse
            }
        }
        
        return melEnergies
    }
    
    private func calculateTriangularFilterResponse(_ melFreq: Float, _ centerMel: Float, _ melStep: Float) -> Float {
        let diff = abs(melFreq - centerMel)
        return max(0, 1.0 - diff / melStep)
    }
    
    private func computeDCT(_ melEnergies: [Float], numCoefficients: Int) -> [Float] {
        let numFilters = melEnergies.count
        var mfccCoefficients = Array(repeating: Float(0), count: numCoefficients)
        
        for k in 0..<numCoefficients {
            for n in 0..<numFilters {
                let cosTerm = cos(Float.pi * Float(k) * Float(2 * n + 1) / Float(2 * numFilters))
                mfccCoefficients[k] += melEnergies[n] * cosTerm
            }
        }
        
        return mfccCoefficients
    }
    
    private func computeMeanMFCC(_ allMFCC: [Float], numCoefficients: Int, numFrames: Int) -> [Float] {
        var meanMFCC = Array(repeating: Float(0), count: numCoefficients)
        
        for frameIndex in 0..<numFrames {
            for coeffIndex in 0..<numCoefficients {
                let mfccIndex = frameIndex * numCoefficients + coeffIndex
                if mfccIndex < allMFCC.count {
                    meanMFCC[coeffIndex] += allMFCC[mfccIndex]
                }
            }
        }
        
        return meanMFCC.map { $0 / Float(numFrames) }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioProcessingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            recordingError = .recordingFailed
        }

    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        recordingError = .recordingFailed
        
    }
}

// MARK: - Error Types
enum AudioProcessingError: Error, LocalizedError {
    case permissionDenied
    case recordingFailed
    case audioSessionFailed
    case audioProcessingFailed
    case invalidAudioFormat
    case featureExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required for voice analysis."
        case .recordingFailed:
            return "Failed to record audio. Please try again."
        case .audioSessionFailed:
            return "Failed to configure audio session."
        case .audioProcessingFailed:
            return "Failed to process audio data."
        case .invalidAudioFormat:
            return "Invalid audio format provided."
        case .featureExtractionFailed:
            return "Failed to extract features from audio."
        }
    }
}
