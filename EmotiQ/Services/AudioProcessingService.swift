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
    @Published var recordingError: AudioProcessingError?
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var recordingTimer: Timer?
    private var audioLevelTimer: Timer?
    private var recordingURL: URL?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Audio Level Publishers
    private let audioLevelSubject = PassthroughSubject<Float, Never>()
    var audioLevels: AnyPublisher<Float, Never> {
        audioLevelSubject.eraseToAnyPublisher()
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
        print("🎤 Starting audio recording...")
        
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
        
        // Start real-time monitoring
        try startRealTimeMonitoring()
        
        isRecording = true
        recordingDuration = 0
        
        // Start timers
        startRecordingTimer()
        startAudioLevelTimer()
        
        print("✅ Recording started successfully")
        return recordingURL!
    }
    
    /// Stops recording and returns the recorded audio URL
    func stopRecording() async throws -> URL {
        print("⏹️ Stopping audio recording...")
        
        guard isRecording else {
            throw AudioProcessingError.recordingFailed
        }
        
        // Stop recording
        audioRecorder?.stop()
        stopRealTimeMonitoring()
        stopTimers()
        
        isRecording = false
        
        // Verify recording file exists
        guard let url = recordingURL, FileManager.default.fileExists(atPath: url.path) else {
            throw AudioProcessingError.recordingFailed
        }
        
        print("✅ Recording stopped successfully: \(url.lastPathComponent)")
        return url
    }
    
    /// Cancels current recording
    func cancelRecording() {
        print("❌ Cancelling audio recording...")
        
        audioRecorder?.stop()
        stopRealTimeMonitoring()
        stopTimers()
        
        isRecording = false
        recordingDuration = 0
        audioLevel = 0
        
        // Delete recording file if it exists
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordingURL = nil
    }
    
    /// Extracts production-ready audio features from recorded data
    func extractFeatures(from audioURL: URL) async throws -> ProductionAudioFeatures {
        print("🔬 Extracting audio features from: \(audioURL.lastPathComponent)")
        
        // Load audio samples
        let audioSamples = try await loadAudioSamples(from: audioURL)
        print("📊 Loaded \(audioSamples.count) audio samples")
        
        // Extract features using production algorithms
        let features = try extractProductionFeatures(from: audioSamples)
        print("✅ Extracted features: pitch=\(features.pitch), energy=\(features.energy)")
        
        return features
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
            recordingError = .audioSessionFailed
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
        
        print("🎙️ Recording setup complete: \(url.lastPathComponent)")
    }
    
    private func startRealTimeMonitoring() throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioProcessingError.audioSessionFailed
        }
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw AudioProcessingError.audioSessionFailed
        }
        
        // Configure audio format for real-time processing
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap for real-time audio level monitoring
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processRealTimeAudio(buffer: buffer)
        }
        
        // Start audio engine
        try audioEngine.start()
        print("🎧 Real-time monitoring started")
    }
    
    private func stopRealTimeMonitoring() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        print("⏸️ Real-time monitoring stopped")
    }
    
    private func processRealTimeAudio(buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))
        
        // Calculate RMS level for visualization
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        let level = min(max(rms * 10, 0), 1) // Scale and clamp to 0-1
        
        DispatchQueue.main.async {
            self.audioLevel = level
            self.audioLevelSubject.send(level)
        }
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
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: Config.levelUpdateInterval, repeats: true) { [weak self] _ in
            self?.audioRecorder?.updateMeters()
            if let recorder = self?.audioRecorder {
                let averagePower = recorder.averagePower(forChannel: 0)
                let normalizedLevel = self?.normalizeAudioLevel(averagePower) ?? 0
                
                DispatchQueue.main.async {
                    self?.audioLevel = normalizedLevel
                    self?.audioLevelSubject.send(normalizedLevel)
                }
            }
        }
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
        
        return ProductionAudioFeatures(
            pitch: pitch,
            energy: energy,
            spectralCentroid: spectralCentroid,
            zeroCrossingRate: zeroCrossingRate,
            spectralRolloff: spectralRolloff
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
    
    private func computeFFTMagnitudes(_ samples: [Float]) -> [Float] {
        let n = samples.count
        let log2n = vDSP_Length(log2(Float(n)))
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return Array(repeating: 0, count: n/2)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var realParts = samples
        var imagParts = Array(repeating: Float(0), count: n)
        
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        
        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        var magnitudes = Array(repeating: Float(0), count: n/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(n/2))
        
        return magnitudes
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioProcessingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            recordingError = .recordingFailed
        }
        print("🎤 Recording finished successfully: \(flag)")
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        recordingError = .recordingFailed
        print("❌ Recording encode error: \(error?.localizedDescription ?? "Unknown")")
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

// MARK: - Supporting Types
struct ProductionAudioFeatures {
    let pitch: Float
    let energy: Float
    let spectralCentroid: Float
    let zeroCrossingRate: Float
    let spectralRolloff: Float
}

