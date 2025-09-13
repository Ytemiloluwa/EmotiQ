//
//  ElevenLabsService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import AVFoundation
import Combine
import Network

// MARK: - ElevenLabs Service
@MainActor
class ElevenLabsService: ObservableObject {
    static let shared = ElevenLabsService()
    
    @Published var isVoiceCloned = false
    @Published var voiceCloneProgress: Double = 0.0
    @Published var isGeneratingAudio = false
    @Published var lastError: ElevenLabsError?
    
    // Voice profile status
    enum VoiceProfileStatus {
        case notCreated
        case active
        case inactive
    }
    
    private let baseURL = "https://emotiq-api-proxy-v2.vercel.app/api/elevenlabs"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Voice profile management
    @Published var userVoiceProfile: VoiceProfile?
    private let persistenceController = PersistenceController.shared
    
    // Audio caching
    private let audioCache = AudioCacheManager.shared
    private let maxCacheSize: Int = 100 // Maximum cached audio files
    
    private init() {
        
        loadVoiceProfile()
    }
    
    // MARK: - Voice Cloning
    
    /// Clone user's voice from audio sample
    func cloneVoice(from audioURL: URL, name: String = "EmotiQ User Voice") async throws -> VoiceProfile {
        
        voiceCloneProgress = 0.1
        
        // Validate audio file
        try await validateAudioFile(audioURL)
        voiceCloneProgress = 0.3
        
        // Upload audio and create voice
        let voiceID = try await uploadVoiceClone(audioURL: audioURL, name: name)
        voiceCloneProgress = 0.8
        
        // Create voice profile
        let profile = VoiceProfile(
            id: voiceID,
            name: name,
            createdAt: Date(),
            isActive: true,
            quality: .high
        )
        
        
        // Save profile
        userVoiceProfile = profile
        saveVoiceProfile(profile)
        isVoiceCloned = true
        voiceCloneProgress = 1.0
        
        // Trigger haptic feedback for completion
        HapticManager.shared.notification(.success)
        
        return profile
    }
    
    /// Validate audio file meets ElevenLabs requirements
    private func validateAudioFile(_ url: URL) async throws {
        let asset = AVAsset(url: url)
        
        // Check duration (minimum 30 seconds, maximum 5 minutes)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        guard durationSeconds >= 30 else {
            throw ElevenLabsError.audioTooShort
        }
        
        guard durationSeconds <= 300 else {
            throw ElevenLabsError.audioTooLong
        }
        
        // Check audio quality
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ElevenLabsError.invalidAudioFormat
        }
        
        let formatDescriptions = try await track.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions.first else {
            throw ElevenLabsError.invalidAudioFormat
        }
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let description = audioStreamBasicDescription?.pointee else {
            throw ElevenLabsError.invalidAudioFormat
        }
        
        // Ensure minimum quality (16kHz, 16-bit)
        guard description.mSampleRate >= 16000 else {
            throw ElevenLabsError.lowAudioQuality
        }
    }
    
    /// Upload audio file and create voice clone
    private func uploadVoiceClone(audioURL: URL, name: String) async throws -> String {

        let url = URL(string: "\(baseURL)?path=voices/add")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // API key is handled by the secure proxy
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Verify audio file exists and is readable
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw ElevenLabsError.invalidAudioFormat
        }
        
        let audioData = try Data(contentsOf: audioURL)
        
        // Verify audio data is not empty
        guard !audioData.isEmpty else {
            throw ElevenLabsError.invalidAudioFormat
        }
        
        // Verify audio file format (should be .m4a, .mp3, .wav, etc.)
        let fileExtension = audioURL.pathExtension.lowercased()
        let supportedFormats = ["m4a", "mp3", "wav", "flac", "aac"]
        guard supportedFormats.contains(fileExtension) else {

            throw ElevenLabsError.invalidAudioFormat
        }
        
        
        let formData = createMultipartFormData(
            boundary: boundary,
            name: name,
            audioData: audioData,
            fileName: "voice_sample.m4a"
        )
        
        request.httpBody = formData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.networkError
        }
        
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Try to parse ElevenLabs error response
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? [String: Any],
               let message = detail["message"] as? String {
                throw ElevenLabsError.apiError(message)
            } else {
                throw ElevenLabsError.apiError(errorMessage)
            }
        }
        
        do {
            let voiceResponse = try JSONDecoder().decode(VoiceCloneResponse.self, from: data)

            return voiceResponse.voice_id
        } catch {
            throw ElevenLabsError.apiError("Failed to decode response: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Voice Generation
    
    /// Generate speech from text using cloned voice
    func generateSpeech(
        text: String,
        emotion: EmotionType = .neutral,
        speed: Double = 1.0,
        stability: Double = 0.75
    ) async throws -> URL {
        guard let voiceProfile = userVoiceProfile else {
            throw ElevenLabsError.noVoiceProfile
        }
        
        // Check cache first
        if let cachedData = audioCache.getCachedAudio(for: text, emotion: emotion, voiceId: voiceProfile.id) {
            return cachedData
        }
        
        isGeneratingAudio = true
        defer { isGeneratingAudio = false }
        
        let url = URL(string: "\(baseURL)?path=text-to-speech/\(voiceProfile.id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // API key is handled by the secure proxy
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body with emotion-aware settings
        let voiceSettings = getVoiceSettings(for: emotion, speed: speed, stability: stability)
        let requestBody = TextToSpeechRequest(
            text: text,
            voice_settings: voiceSettings,
            model_id: "eleven_multilingual_v2"
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let responseTime = Date().timeIntervalSince(startTime)
        
        // Log performance (should be < 3 seconds)
        if responseTime > 3.0 {
      
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(errorMessage)
        }
        
        // Save audio to cache
        let audioURL = try await audioCache.cacheAudio(data: data, text: text, emotion: emotion, voiceId: voiceProfile.id)
        
        // Trigger haptic feedback for completion
        HapticManager.shared.impact(.light)
        
        return audioURL
    }
    
    /// Generate multiple affirmations in batch for better performance
    func generateAffirmationsBatch(
        affirmations: [String],
        emotion: EmotionType = .neutral
    ) async throws -> [URL] {
        var audioURLs: [URL] = []
        
        // Process in parallel for better performance
        try await withThrowingTaskGroup(of: URL.self) { group in
            for affirmation in affirmations {
                group.addTask {
                    try await self.generateSpeech(text: affirmation, emotion: emotion)
                }
            }
            
            for try await audioURL in group {
                audioURLs.append(audioURL)
            }
        }
        
        return audioURLs
    }
    
    // MARK: - Voice Settings
    
    /// Get emotion-aware voice settings
    private func getVoiceSettings(for emotion: EmotionType, speed: Double, stability: Double) -> VoiceSettings {
        switch emotion {
        case .joy, .surprise:
            return VoiceSettings(
                stability: stability * 0.9, // Slightly more expressive
                similarity_boost: 0.8,
                style: 0.3,
                use_speaker_boost: true
            )
        case .sadness, .fear:
            return VoiceSettings(
                stability: stability * 1.1, // More stable/calm
                similarity_boost: 0.9,
                style: 0.1,
                use_speaker_boost: false
            )
        case .anger:
            return VoiceSettings(
                stability: stability * 0.8, // More dynamic
                similarity_boost: 0.7,
                style: 0.4,
                use_speaker_boost: true
            )
        case .neutral, .disgust:
            return VoiceSettings(
                stability: stability,
                similarity_boost: 0.8,
                style: 0.2,
                use_speaker_boost: false
            )
        }
    }
    
    // MARK: - Voice Profile Management
    
    /// Load saved voice profile
    private func loadVoiceProfile() {
        Task {
            do {
                if let profile = try await fetchVoiceProfileFromCoreData() {
                    userVoiceProfile = profile
                    isVoiceCloned = profile.isActive
                    
                }
            } catch {

            }
        }
    }
    
    /// Save voice profile to Core Data
    private func saveVoiceProfile(_ profile: VoiceProfile) {
        Task {
            do {
                try await saveVoiceProfileToCoreData(profile)

            } catch {

            }
        }
    }
    
    /// Fetch voice profile from Core Data
    private func fetchVoiceProfileFromCoreData() async throws -> VoiceProfile? {
        return try await withCheckedThrowingContinuation { continuation in
            persistenceController.container.performBackgroundTask { context in
                do {
                    let request = VoiceProfileEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "isActive == YES")
                    request.fetchLimit = 1
                    
                    let entities = try context.fetch(request)
                    
                    if let entity = entities.first {
                        let profile = VoiceProfile(
                            id: entity.elevenLabsVoiceId ?? "",
                            name: entity.name ?? "",
                            createdAt: entity.createdAt ?? Date(),
                            isActive: entity.isActive,
                            quality: .high
                        )
                        continuation.resume(returning: profile)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Save voice profile to Core Data
    private func saveVoiceProfileToCoreData(_ profile: VoiceProfile) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            persistenceController.container.performBackgroundTask { context in
                do {
                    // Deactivate existing profiles
                    let request = VoiceProfileEntity.fetchRequest()
                    let existingProfiles = try context.fetch(request)
                    for existingProfile in existingProfiles {
                        existingProfile.isActive = false
                    }
                    
                    // Create new profile entity
                    let entity = VoiceProfileEntity(context: context)
                    entity.id = UUID()
                    entity.elevenLabsVoiceId = profile.id
                    entity.name = profile.name
                    entity.createdAt = profile.createdAt
                    entity.isActive = profile.isActive
                    entity.stability = 0.75
                    entity.similarityBoost = 0.75
                    entity.style = 0.0
                    entity.useSpeakerBoost = true
                    
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Check if voice profile exists and is ready for use
    var hasVoiceProfile: Bool {
        return userVoiceProfile != nil && userVoiceProfile?.isActive == true
    }
    
    /// Get voice profile status for UI feedback
    var voiceProfileStatus: VoiceProfileStatus {
        if userVoiceProfile == nil {
            return .notCreated
        } else if userVoiceProfile?.isActive == true {
            return .active
        } else {
            return .inactive
        }
    }
    
    /// Delete voice profile and clear cache
    func deleteVoiceProfile() async throws {
        guard let profile = userVoiceProfile else { return }
        
        // Delete from ElevenLabs
        let url = URL(string: "\(baseURL)?path=voices/\(profile.id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        // API key is handled by the secure proxy
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ElevenLabsError.deletionFailed
        }
        
        // Delete from Core Data
        try await deleteVoiceProfileFromCoreData(profile.id)
        
        // Clear local data
        userVoiceProfile = nil
        isVoiceCloned = false
        
        // Clear audio cache
        await audioCache.clearCache()
        
        HapticManager.shared.notification(.success)
    }
    
    /// Delete voice profile from Core Data
    private func deleteVoiceProfileFromCoreData(_ voiceId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            persistenceController.container.performBackgroundTask { context in
                do {
                    let request = VoiceProfileEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "elevenLabsVoiceId == %@", voiceId)
                    
                    let entities = try context.fetch(request)
                    for entity in entities {
                        context.delete(entity)
                    }
                    
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Safely check if voice features are available
    func canUseVoiceFeatures() -> Bool {
        return hasVoiceProfile // API key is handled by the secure proxy
    }
    
    /// Get user-friendly message about voice profile status
    func getVoiceProfileMessage() -> String {
        switch voiceProfileStatus {
        case .notCreated:
            return "Voice cloning required. Set up your voice profile in the Coaching section to use voice features."
        case .active:
            return "Voice profile is active and ready to use."
        case .inactive:
            return "Voice profile is inactive. Please reactivate it to use voice features."
        }
    }
    
    /// Refresh voice profile status from Core Data
    func refreshVoiceProfileStatus() async {
        do {
            if let profile = try await fetchVoiceProfileFromCoreData() {
                userVoiceProfile = profile
                isVoiceCloned = profile.isActive

            } else {
                userVoiceProfile = nil
                isVoiceCloned = false
            }
        } catch {

        }
    }
    
    
    /// Create multipart form data for voice upload
    private func createMultipartFormData(
        boundary: String,
        name: String,
        audioData: Data,
        fileName: String
    ) -> Data {
        var formData = Data()
        
        // Add name field
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(name)\r\n".data(using: .utf8)!)
        
        // Add audio file
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        formData.append(audioData)
        formData.append("\r\n".data(using: .utf8)!)
        
        // Add description
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
        formData.append("EmotiQ user voice for personalized emotional coaching\r\n".data(using: .utf8)!)
        
        // Close boundary
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return formData
    }
    
    // Get available voices from ElevenLabs
    func getAvailableVoices() async throws -> [ElevenLabsVoice] {
        let url = URL(string: "\(baseURL)?path=voices")!
        var request = URLRequest(url: url)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(errorMessage)
        }
        
        let voicesResponse = try JSONDecoder().decode(VoicesResponse.self, from: data)
        return voicesResponse.voices
    }
    
    func cloneVoice(audioData: Data, name: String, description: String) async throws -> String {
        // API key is handled by the secure proxy
        
        voiceCloneProgress = 0.1
        
        // Upload audio and create voice
        let voiceID = try await uploadVoiceCloneFromData(audioData: audioData, name: name, description: description)
        voiceCloneProgress = 0.8
        
        voiceCloneProgress = 1.0
        
        // Trigger haptic feedback for completion
        HapticManager.shared.notification(.success)
        
        return voiceID
    }
    
    private func uploadVoiceCloneFromData(audioData: Data, name: String, description: String) async throws -> String {
        let url = URL(string: "\(baseURL)?path=voices/add")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // API key is handled by the secure proxy
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let formData = createMultipartFormData(
            boundary: boundary,
            name: name,
            audioData: audioData,
            fileName: "voice_sample.m4a"
        )
        
        request.httpBody = formData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(errorMessage)
        }
        
        let voiceResponse = try JSONDecoder().decode(VoiceCloneResponse.self, from: data)
        return voiceResponse.voice_id
    }
    
    func generateSpeech(
        text: String,
        voiceId: String,
        emotion: EmotionType = .neutral,
        settings: ElevenLabsViewModel.VoiceSettings
    ) async throws -> Data {
        // Check cache first
        if let cachedURL = audioCache.getCachedAudio(for: text, emotion: emotion, voiceId: voiceId) {
            return try Data(contentsOf: cachedURL)
        }
        
        isGeneratingAudio = true
        defer { isGeneratingAudio = false }
        
        let url = URL(string: "\(baseURL)?path=text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // API key is handled by the secure proxy
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body with settings
        let voiceSettings = VoiceSettings(
            stability: settings.stability,
            similarity_boost: settings.similarityBoost,
            style: settings.style,
            use_speaker_boost: settings.useSpeakerBoost
        )
        
        let requestBody = TextToSpeechRequest(
            text: text,
            voice_settings: voiceSettings,
            model_id: "eleven_multilingual_v2"
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let responseTime = Date().timeIntervalSince(startTime)
        
        // Log performance (should be < 3 seconds)
        if responseTime > 3.0 {
            
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(errorMessage)
        }
        
        // Save audio to cache
        let audioURL = try await audioCache.cacheAudio(data: data, text: text, emotion: emotion, voiceId: voiceId)
        
        // Trigger haptic feedback for completion
        HapticManager.shared.impact(.light)
        
        return data
    }
    
    /// Get usage statistics
    func getUsageStats() async throws -> UsageStats {
        let url = URL(string: "\(baseURL)/user/subscription")!
        var request = URLRequest(url: url)
        // API key is handled by the secure proxy
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(errorMessage)
        }
        
        let usageResponse = try JSONDecoder().decode(UsageResponse.self, from: data)
        return UsageStats(
            characterCount: usageResponse.character_count,
            characterLimit: usageResponse.character_limit,
            requestCount: usageResponse.request_count,
            requestLimit: usageResponse.request_limit
        )
    }
    
    func deleteVoice(_ voiceId: String) async throws {
        let url = URL(string: "\(baseURL)/voices/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        // API key is handled by the secure proxy
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ElevenLabsError.deletionFailed
        }
    }
    
}

// MARK: - Additional Response Models

struct VoicesResponse: Codable {
    let voices: [ElevenLabsVoice]
}

struct UsageResponse: Codable {
    let character_count: Int
    let character_limit: Int
    let request_count: Int
    let request_limit: Int
}


// MARK: - Data Models

struct VoiceProfile: Codable {
    let id: String
    let name: String
    let createdAt: Date
    let isActive: Bool
    let quality: VoiceQuality
    
    enum VoiceQuality: String, Codable {
        case low, medium, high, premium
    }
}

struct VoiceSettings: Codable {
    let stability: Double
    let similarity_boost: Double
    let style: Double
    let use_speaker_boost: Bool
}

struct TextToSpeechRequest: Codable {
    let text: String
    let voice_settings: VoiceSettings
    let model_id: String
}

struct VoiceCloneResponse: Codable {
    let voice_id: String
    let requires_verification: Bool?
    
    // Optional fields that might be present in some responses
    // Current ElevenLabs API response format:
    // {"voice_id":"NlGwLQYBKboJjb0pry7V","requires_verification":false}
    let name: String?
    let status: String?
}

// MARK: - Error Types

enum ElevenLabsError: LocalizedError {
    case missingAPIKey
    case audioTooShort
    case audioTooLong
    case invalidAudioFormat
    case lowAudioQuality
    case networkError
    case apiError(String)
    case noVoiceProfile
    case deletionFailed
    case cacheError
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "ElevenLabs API key is missing. Please check your configuration."
        case .audioTooShort:
            return "Audio sample must be at least 30 seconds long for voice cloning."
        case .audioTooLong:
            return "Audio sample must be less than 5 minutes long."
        case .invalidAudioFormat:
            return "Invalid audio format. Please use a supported audio file."
        case .lowAudioQuality:
            return "Audio quality is too low. Please record in higher quality (16kHz minimum)."
        case .networkError:
            return "Network error occurred. Please check your internet connection."
        case .apiError(let message):
            return "ElevenLabs API error: \(message)"
        case .noVoiceProfile:
            return "Voice profile required. Please set up voice cloning in the Coaching section to use voice features."
        case .deletionFailed:
            return "Failed to delete voice profile. Please try again."
        case .cacheError:
            return "Audio cache error occurred."
        case.quotaExceeded:
            return "Quota exceeded. Please contact support@elevenlabs.com."
        }
    }
}
