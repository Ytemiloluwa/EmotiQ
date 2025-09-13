//
//  CacheAudioPlayer.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class CachedAudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    @Published var isLooping = false
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private let elevenLabsService = ElevenLabsService.shared
    private let cacheManager = AudioCacheManager.shared
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        // Safely stop audio playback during deinit without haptic feedback
        audioPlayer?.stop()
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Public Methods
    
    func playAudio(text: String, emotion: EmotionType, voiceId: String? = nil) async throws {
        // Get the user's voice profile ID if not provided
        let userVoiceId = voiceId ?? elevenLabsService.userVoiceProfile?.id
        
        // Check if user has a voice profile
        guard let finalVoiceId = userVoiceId else {
            throw ElevenLabsError.noVoiceProfile
        }
        
        // Check cache first
        if let cachedURL = await cacheManager.getCachedAudio(for: text, emotion: emotion, voiceId: finalVoiceId) {
            try await playFromURL(cachedURL)
            return
        }
        
        // Generate new audio
        do {
            let audioData = try await elevenLabsService.generateSpeech(
                text: text,
                voiceId: finalVoiceId,
                emotion: emotion,
                settings: ElevenLabsViewModel.VoiceSettings(
                    stability: 0.75,
                    similarityBoost: 0.8,
                    style: 0.2,
                    useSpeakerBoost: true
                )
            )
            
            // Cache the audio
            let cacheURL = try await cacheManager.cacheAudio(data: audioData, text: text, emotion: emotion, voiceId: finalVoiceId)
            
            // Play the audio
            try await playFromURL(cacheURL)
            
        } catch ElevenLabsError.noVoiceProfile {
            throw ElevenLabsError.noVoiceProfile
            
        } catch {

            throw error
        }
    }
    
    func playFromURL(_ url: URL) async throws {
        stop()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.rate = playbackRate
            audioPlayer?.numberOfLoops = isLooping ? -1 : 0
            
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            
            if audioPlayer?.play() == true {
                isPlaying = true
                startTimer()
                
                // Haptic feedback for play
                HapticManager.shared.audioPlayback(.start)
            }
            
        } catch {

            throw error
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
        
        HapticManager.shared.audioPlayback(.pause)
    }
    
    func resume() {
        if audioPlayer?.play() == true {
            isPlaying = true
            startTimer()
            
            HapticManager.shared.audioPlayback(.resume)
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
        
        HapticManager.shared.audioPlayback(.stop)
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        let clampedTime = max(0, min(time, duration))
        player.currentTime = clampedTime
        currentTime = clampedTime
        
        HapticManager.shared.audioPlayback(.seek)
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = max(0.5, min(2.0, rate))
        audioPlayer?.rate = playbackRate
        
        HapticManager.shared.selection()
    }
    
    func toggleLoop() {
        isLooping.toggle()
        audioPlayer?.numberOfLoops = isLooping ? -1 : 0
        
        HapticManager.shared.selection()
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
    
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.updateCurrentTime()
            }
        }
        // Ensure timer runs on main run loop
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentTime() {
        guard let player = audioPlayer else { return }
        let newTime = player.currentTime
        if newTime != currentTime {
            currentTime = newTime

        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension CachedAudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if !isLooping {
                isPlaying = false
                currentTime = duration
                stopTimer()
                
                HapticManager.shared.audioPlayback(.complete)
            } else {
                // Reset current time for loop
                currentTime = 0
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            isPlaying = false
            stopTimer()
            
            HapticManager.shared.notification(.error)
        }
    }
}

// MARK: - Audio Session Management

extension CachedAudioPlayer {
    func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            pause()
            
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                resume()
            }
            
        @unknown default:
            break
        }
    }
    
    func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones were unplugged, pause playback
            pause()
            
        case .newDeviceAvailable:
            // New audio device connected, could resume if desired
            break
            
        default:
            break
        }
    }
}

// MARK: - Haptic Feedback Extensions

extension HapticManager {
    enum AudioPlaybackEvent {
        case start
        case pause
        case resume
        case stop
        case seek
        case complete
    }
    
    func audioPlayback(_ event: AudioPlaybackEvent) {
        switch event {
        case .start:
            buttonPress(.primary)
        case .pause:
            buttonPress(.subtle)
        case .resume:
            buttonPress(.primary)
        case .stop:
            buttonPress(.subtle)
        case .seek:
            selection()
        case .complete:
            notification(.success)
        }
    }
}

