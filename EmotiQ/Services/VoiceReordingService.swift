//
//  VoiceReordingService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 07-08-2025.
//

import Foundation
import AVFoundation
import Combine

protocol VoiceRecordingServiceProtocol {
    var isRecording: AnyPublisher<Bool, Never> { get }
    var recordingDuration: AnyPublisher<TimeInterval, Never> { get }
    var audioLevels: AnyPublisher<Float, Never> { get }
    var recordingQuality: AnyPublisher<VoiceQuality, Never> { get }
    
    func requestPermission() -> AnyPublisher<Bool, Error>
    func startRecording() -> AnyPublisher<Void, VoiceRecordingError>
    func stopRecording() -> AnyPublisher<URL, VoiceRecordingError>
    func cancelRecording()
    func validateAudioQuality(url: URL) -> AnyPublisher<VoiceQuality, Error>
}

enum VoiceQuality: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        }
    }
    
    var confidence: Double {
        switch self {
        case .excellent:
            return 0.95
        case .good:
            return 0.80
        case .fair:
            return 0.65
        case .poor:
            return 0.40
        }
    }
    
    var isAcceptable: Bool {
        return self != .poor
    }
}

enum VoiceRecordingError: Error, LocalizedError {
    case permissionDenied
    case audioSessionSetupFailed
    case recordingFailed
    case fileNotFound
    case invalidDuration
    case qualityTooLow
    case backgroundNoiseTooHigh
    case microphoneUnavailable
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record your voice."
        case .audioSessionSetupFailed:
            return "Failed to setup audio session. Please try again."
        case .recordingFailed:
            return "Recording failed. Please check your microphone and try again."
        case .fileNotFound:
            return "Recording file not found. Please try recording again."
        case .invalidDuration:
            return "Recording must be between 1 and 120 seconds."
        case .qualityTooLow:
            return "Audio quality is too low. Please speak closer to the microphone."
        case .backgroundNoiseTooHigh:
            return "Background noise is too high. Please find a quieter environment."
        case .microphoneUnavailable:
            return "Microphone is unavailable. Please check if another app is using it."
        }
    }
}

class VoiceRecordingService: NSObject, VoiceRecordingServiceProtocol {
    
    // MARK: - Published Properties
    @Published private var _isRecording: Bool = false
    @Published private var _recordingDuration: TimeInterval = 0
    @Published private var _audioLevels: Float = 0
    @Published private var _recordingQuality: VoiceQuality = .good
    
    var isRecording: AnyPublisher<Bool, Never> {
        $_isRecording.eraseToAnyPublisher()
    }
    
    var recordingDuration: AnyPublisher<TimeInterval, Never> {
        $_recordingDuration.eraseToAnyPublisher()
    }
    
    var audioLevels: AnyPublisher<Float, Never> {
        $_audioLevels.eraseToAnyPublisher()
    }
    
    var recordingQuality: AnyPublisher<VoiceQuality, Never> {
        $_recordingQuality.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var currentRecordingURL: URL?
    private var startTime: Date?
    
    // MARK: - Audio Settings
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: Config.VoiceAnalysis.sampleRate,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        AVEncoderBitRateKey: 128000
    ]
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            if Config.isDebugMode {
                print("🎤 Audio session configured successfully")
            }
        } catch {
            if Config.isDebugMode {
                print("Failed to setup audio session: \(error)")
            }
        }
    }
    
    // MARK: - Permission Management
    
    func requestPermission() -> AnyPublisher<Bool, Error> {
        return Future { [weak self] promise in
            self?.audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if Config.isDebugMode {
                        print("🎤 Microphone permission: \(granted ? " Granted" : " Denied")")
                    }
                    promise(.success(granted))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Recording Control
    
    func startRecording() -> AnyPublisher<Void, VoiceRecordingError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.recordingFailed))
                return
            }
            
            // Check if already recording
            if self._isRecording {
                promise(.failure(.recordingFailed))
                return
            }
            
            // Check microphone permission
            guard self.audioSession.recordPermission == .granted else {
                promise(.failure(.permissionDenied))
                return
            }
            
            // Setup recording URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("voice_recording_\(Date().timeIntervalSince1970).\(Config.VoiceAnalysis.audioFormat)")
            self.currentRecordingURL = audioFilename
            
            do {
                // Create and configure audio recorder
                self.audioRecorder = try AVAudioRecorder(url: audioFilename, settings: self.audioSettings)
                self.audioRecorder?.delegate = self
                self.audioRecorder?.isMeteringEnabled = true
                
                // Start recording
                guard self.audioRecorder?.record() == true else {
                    promise(.failure(.recordingFailed))
                    return
                }
                
                // Update state
                self._isRecording = true
                self.startTime = Date()
                self._recordingDuration = 0
                
                // Start timers
                self.startTimers()
                
                if Config.isDebugMode {
                    print("🎤 Recording started: \(audioFilename.lastPathComponent)")
                }
                
                promise(.success(()))
                
            } catch {
                if Config.isDebugMode {
                    print("❌ Failed to start recording: \(error)")
                }
                promise(.failure(.recordingFailed))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func stopRecording() -> AnyPublisher<URL, VoiceRecordingError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.recordingFailed))
                return
            }
            
            guard self._isRecording, let recorder = self.audioRecorder else {
                promise(.failure(.recordingFailed))
                return
            }
            
            // Stop recording
            recorder.stop()
            self._isRecording = false
            self.stopTimers()
            
            // Validate duration
            let duration = self._recordingDuration
            guard duration >= Config.VoiceAnalysis.minRecordingDuration else {
                self.cleanup()
                promise(.failure(.invalidDuration))
                return
            }
            
            guard duration <= Config.VoiceAnalysis.maxRecordingDuration else {
                self.cleanup()
                promise(.failure(.invalidDuration))
                return
            }
            
            // Return recording URL
            if let url = self.currentRecordingURL {
                if Config.isDebugMode {
                    print("🎤 Recording stopped: \(String(format: "%.1f", duration))s")
                }
                promise(.success(url))
            } else {
                promise(.failure(.fileNotFound))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func cancelRecording() {
        guard _isRecording else { return }
        
        audioRecorder?.stop()
        _isRecording = false
        stopTimers()
        
        // Delete the recording file
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        cleanup()
        
        if Config.isDebugMode {
            print("🎤 Recording cancelled")
        }
    }
    
    // MARK: - Audio Quality Validation
    
    func validateAudioQuality(url: URL) -> AnyPublisher<VoiceQuality, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let audioFile = try AVAudioFile(forReading: url)
                    let format = audioFile.processingFormat
                    let frameCount = UInt32(audioFile.length)
                    
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                        promise(.failure(VoiceRecordingError.recordingFailed))
                        return
                    }
                    
                    try audioFile.read(into: buffer)
                    
                    // Analyze audio quality
                    let quality = self.analyzeAudioQuality(buffer: buffer)
                    
                    DispatchQueue.main.async {
                        if Config.isDebugMode {
                            print("🎤 Audio quality analysis: \(quality.displayName)")
                        }
                        promise(.success(quality))
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func analyzeAudioQuality(buffer: AVAudioPCMBuffer) -> VoiceQuality {
        guard let channelData = buffer.floatChannelData?[0] else {
            return .poor
        }
        
        let frameLength = Int(buffer.frameLength)
        var rms: Float = 0
        var peak: Float = 0
        
        // Calculate RMS and peak levels
        for i in 0..<frameLength {
            let sample = channelData[i]
            rms += sample * sample
            peak = max(peak, abs(sample))
        }
        
        rms = sqrt(rms / Float(frameLength))
        
        // Convert to dB
        let rmsDB = 20 * log10(rms + 1e-10)
        let peakDB = 20 * log10(peak + 1e-10)
        
        // Quality assessment based on signal levels
        if rmsDB > -20 && peakDB > -6 && peakDB < -1 {
            return .excellent
        } else if rmsDB > -30 && peakDB > -12 {
            return .good
        } else if rmsDB > -40 && peakDB > -20 {
            return .fair
        } else {
            return .poor
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimers() {
        // Duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            
            self._recordingDuration = Date().timeIntervalSince(startTime)
            
            // Auto-stop at max duration
            if self._recordingDuration >= Config.VoiceAnalysis.maxRecordingDuration {
                self.stopRecording()
                    .sink(
                        receiveCompletion: { _ in },
                        receiveValue: { _ in }
                    )
                    .store(in: &self.cancellables)
            }
        }
        
        // Audio level timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevels()
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // Convert to normalized level (0.0 to 1.0)
        let normalizedLevel = pow(10.0, averagePower / 20.0)
        _audioLevels = Float(normalizedLevel)
        
        // Update quality based on levels
        updateQualityBasedOnLevels(average: averagePower, peak: peakPower)
    }
    
    private func updateQualityBasedOnLevels(average: Float, peak: Float) {
        let quality: VoiceQuality
        
        if average > -20 && peak > -6 {
            quality = .excellent
        } else if average > -30 && peak > -12 {
            quality = .good
        } else if average > -40 && peak > -20 {
            quality = .fair
        } else {
            quality = .poor
        }
        
        if quality != _recordingQuality {
            _recordingQuality = quality
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        audioRecorder = nil
        currentRecordingURL = nil
        startTime = nil
        stopTimers()
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - AVAudioRecorderDelegate

extension VoiceRecordingService: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if Config.isDebugMode {
            print(" Recording finished successfully: \(flag)")
        }
        
        if !flag {
            _isRecording = false
            stopTimers()
            cleanup()
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error, Config.isDebugMode {
            print(" Recording encode error: \(error)")
        }
        
        _isRecording = false
        stopTimers()
        cleanup()
    }
}

