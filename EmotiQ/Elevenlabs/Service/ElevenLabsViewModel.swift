//
//  ElevenLabsViewModel.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import Combine

@MainActor
class ElevenLabsViewModel: BaseViewModel {
    @Published var error: Error?
    @Published var voiceProfile: ModelVoiceProfile?
    @Published var isVoiceCloned = false
    @Published var voiceCloningProgress: Double = 0
    @Published var isGeneratingAudio = false
    @Published var audioGenerationProgress: Double = 0
    @Published var availableVoices: [ElevenLabsVoice] = []
    @Published var selectedVoiceId: String?
    @Published var voiceSettings = VoiceSettings()
    @Published var monthlyCharacterUsage = 0
    @Published var characterLimit = 10000
    
    private let elevenLabsService = ElevenLabsService.shared
    private let persistenceController = PersistenceController.shared
    private let cacheManager = AudioCacheManager.shared
    
    struct VoiceSettings {
        var stability: Double = 0.75
        var similarityBoost: Double = 0.75
        var style: Double = 0.0
        var useSpeakerBoost: Bool = true
    }
    
    override init() {
        super.init()
        Task {
            await loadVoiceProfile()
            await loadUsageStats()
        }
    }
    
    // MARK: - Voice Cloning
    
    func startVoiceCloning(audioData: Data, name: String) async {
        isLoading = true
        voiceCloningProgress = 0
        
        do {
            // Upload voice sample to ElevenLabs
            voiceCloningProgress = 0.3
            let voiceId = try await elevenLabsService.cloneVoice(
                audioData: audioData,
                name: name,
                description: "Personal voice clone for EmotiQ"
            )
            
            voiceCloningProgress = 0.7
            
            // Create voice profile
            let profile = ModelVoiceProfile(
                id: UUID(),
                elevenLabsVoiceId: voiceId,
                name: name,
                createdAt: Date(),
                isActive: true,
                settings: voiceSettings
            )
            
            // Save to Core Data
            try await saveVoiceProfile(profile)
            
            voiceCloningProgress = 1.0
            voiceProfile = profile
            isVoiceCloned = true
            selectedVoiceId = voiceId
            
            HapticManager.shared.celebration(.goalCompleted)
            
        } catch {
            await handleError(error, context: "Voice cloning failed")
        }
        
        isLoading = false
    }
    
    func updateVoiceSettings(_ settings: VoiceSettings) async {
        guard var profile = voiceProfile else { return }
        
        voiceSettings = settings
        profile.settings = settings
        
        do {
            try await saveVoiceProfile(profile)
            voiceProfile = profile
        } catch {
            await handleError(error, context: "Failed to update voice settings")
        }
    }
    
    func deleteVoiceClone() async {
        guard let profile = voiceProfile else { return }
        
        isLoading = true
        
        do {
            // Delete from ElevenLabs
            try await elevenLabsService.deleteVoice(profile.elevenLabsVoiceId)
            
            // Delete from Core Data
            try await deleteVoiceProfile(profile)
            
            // Clear cached audio
            await cacheManager.clearCache()
            
            voiceProfile = nil
            isVoiceCloned = false
            selectedVoiceId = nil
            
        } catch {
            await handleError(error, context: "Failed to delete voice clone")
        }
        
        isLoading = false
    }
    
    // MARK: - Audio Generation
    
    func generateAudio(text: String, emotion: EmotionType) async throws -> Data {
        guard let voiceId = selectedVoiceId else {
            throw ElevenLabsModelError.noVoiceSelected
        }
        
        isGeneratingAudio = true
        audioGenerationProgress = 0
        
        defer {
            isGeneratingAudio = false
            audioGenerationProgress = 0
        }
        
        do {
            audioGenerationProgress = 0.3
            
            let audioData = try await elevenLabsService.generateSpeech(
                text: text,
                voiceId: voiceId,
                emotion: emotion,
                settings: voiceSettings
            )
            
            audioGenerationProgress = 0.8
            
            // Update usage stats
            await updateUsageStats(characterCount: text.count)
            
            audioGenerationProgress = 1.0
            
            return audioData
            
        } catch {
            await handleError(error, context: "Audio generation failed")
            throw error
        }
    }
    
    func generateBatchAudio(texts: [String], emotion: EmotionType) async throws -> [Data] {
        guard let voiceId = selectedVoiceId else {
            throw ElevenLabsModelError.noVoiceSelected
        }
        
        isGeneratingAudio = true
        audioGenerationProgress = 0
        
        defer {
            isGeneratingAudio = false
            audioGenerationProgress = 0
        }
        
        var audioDataArray: [Data] = []
        let totalTexts = texts.count
        
        for (index, text) in texts.enumerated() {
            do {
                let audioData = try await elevenLabsService.generateSpeech(
                    text: text,
                    voiceId: voiceId,
                    emotion: emotion,
                    settings: voiceSettings
                )
                
                audioDataArray.append(audioData)
                audioGenerationProgress = Double(index + 1) / Double(totalTexts)
                
                // Update usage stats
                await updateUsageStats(characterCount: text.count)
                
            } catch {
                print("Failed to generate audio for text: \(text), error: \(error)")
                // Continue with other texts
            }
        }
        
        return audioDataArray
    }
    
    // MARK: - Voice Management
    
    func loadAvailableVoices() async {
        do {
            availableVoices = try await elevenLabsService.getAvailableVoices()
        } catch {
            await handleError(error, context: "Failed to load available voices")
        }
    }
    
    func previewVoice(_ voiceId: String, text: String) async {
        do {
            let audioData = try await elevenLabsService.generateSpeech(
                text: text,
                voiceId: voiceId,
                emotion: .neutral,
                settings: voiceSettings
            )
            
            // Play preview audio
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview.mp3")
            try audioData.write(to: tempURL)
            
            let audioPlayer = CachedAudioPlayer()
            try await audioPlayer.playFromURL(tempURL)
            
        } catch {
            await handleError(error, context: "Failed to preview voice")
        }
    }
    
    // MARK: - Usage Statistics
    
    private func loadUsageStats() async {
        do {
            let usage = try await elevenLabsService.getUsageStats()
            monthlyCharacterUsage = usage.characterCount
            characterLimit = usage.characterLimit
        } catch {
            print("Failed to load usage stats: \(error)")
        }
    }
    
    private func updateUsageStats(characterCount: Int) async {
        monthlyCharacterUsage += characterCount
        
        // Check if approaching limit
        let usagePercentage = Double(monthlyCharacterUsage) / Double(characterLimit)
        if usagePercentage > 0.8 {
            HapticManager.shared.notification(.warning)
        }
    }
    
    func getRemainingCharacters() -> Int {
        return max(0, characterLimit - monthlyCharacterUsage)
    }
    
    func getUsagePercentage() -> Double {
        guard characterLimit > 0 else { return 0 }
        return Double(monthlyCharacterUsage) / Double(characterLimit)
    }
    
    // MARK: - Core Data Operations
    
    func loadVoiceProfile() {
        Task {
            do {
                if let profile = try await fetchVoiceProfile() {
                    voiceProfile = profile
                    isVoiceCloned = true
                    selectedVoiceId = profile.elevenLabsVoiceId
                    voiceSettings = profile.settings
                }
            } catch {
                print("Failed to load voice profile: \(error)")
            }
        }
    }
    
    private func fetchVoiceProfile() async throws -> ModelVoiceProfile? {
        return try await withCheckedThrowingContinuation { continuation in
            persistenceController.container.performBackgroundTask { context in
                do {
                    let request = VoiceProfileEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "isActive == YES")
                    request.fetchLimit = 1
                    
                    let entities = try context.fetch(request)
                    
                    if let entity = entities.first {
                        let profile = ModelVoiceProfile(from: entity)
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
    
    private func saveVoiceProfile(_ profile: ModelVoiceProfile) async throws {
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
                    entity.id = profile.id
                    entity.elevenLabsVoiceId = profile.elevenLabsVoiceId
                    entity.name = profile.name
                    entity.createdAt = profile.createdAt
                    entity.isActive = profile.isActive
                    entity.stability = profile.settings.stability
                    entity.similarityBoost = profile.settings.similarityBoost
                    entity.style = profile.settings.style
                    entity.useSpeakerBoost = profile.settings.useSpeakerBoost
                    
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func deleteVoiceProfile(_ profile: ModelVoiceProfile) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            persistenceController.container.performBackgroundTask { context in
                do {
                    let request = VoiceProfileEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", profile.id as CVarArg)
                    
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
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error, context: String) async {
        print("\(context): \(error)")
        
        if let elevenLabsError = error as? ElevenLabsModelError {
            switch elevenLabsError {
            case .quotaExceeded:
                 HapticManager.shared.notification(.error)
                // Show quota exceeded alert
            case .invalidAPIKey:
                 HapticManager.shared.notification(.error)
                // Show API key error
            case .networkError:
                 HapticManager.shared.notification(.warning)
                // Show network error
            default:
                 HapticManager.shared.notification(.error)
            }
        } else {
             HapticManager.shared.notification(.error)
        }
        
        self.error = error
    }
}

// MARK: - Voice Profile Model

struct ModelVoiceProfile: Identifiable {
    let id: UUID
    let elevenLabsVoiceId: String
    let name: String
    let createdAt: Date
    let isActive: Bool
    var settings: ElevenLabsViewModel.VoiceSettings
    
    init(id: UUID, elevenLabsVoiceId: String, name: String, createdAt: Date, isActive: Bool, settings: ElevenLabsViewModel.VoiceSettings) {
        self.id = id
        self.elevenLabsVoiceId = elevenLabsVoiceId
        self.name = name
        self.createdAt = createdAt
        self.isActive = isActive
        self.settings = settings
    }
    
    init(from entity: VoiceProfileEntity) {
        self.id = entity.id ?? UUID()
        self.elevenLabsVoiceId = entity.elevenLabsVoiceId ?? ""
        self.name = entity.name ?? ""
        self.createdAt = entity.createdAt ?? Date()
        self.isActive = entity.isActive
        self.settings = ElevenLabsViewModel.VoiceSettings(
            stability: entity.stability,
            similarityBoost: entity.similarityBoost,
            style: entity.style,
            useSpeakerBoost: entity.useSpeakerBoost
        )
    }
}

// MARK: - ElevenLabs Voice Model

struct ElevenLabsVoice: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let description: String?
    let previewURL: String?
    let isCustom: Bool
    
    var displayName: String {
        return isCustom ? "\(name) (Custom)" : name
    }
}

// MARK: - Usage Stats Model

struct UsageStats: Codable {
    let characterCount: Int
    let characterLimit: Int
    let requestCount: Int
    let requestLimit: Int
    
    var characterUsagePercentage: Double {
        guard characterLimit > 0 else { return 0 }
        return Double(characterCount) / Double(characterLimit)
    }
    
    var requestUsagePercentage: Double {
        guard requestLimit > 0 else { return 0 }
        return Double(requestCount) / Double(requestLimit)
    }
}

// MARK: - ElevenLabs Errors

enum ElevenLabsModelError: LocalizedError {
    case invalidAPIKey
    case quotaExceeded
    case voiceNotFound
    case noVoiceSelected
    case networkError(String)
    case audioGenerationFailed(String)
    case voiceCloningFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid ElevenLabs API key. Please check your configuration."
        case .quotaExceeded:
            return "Monthly character quota exceeded. Please upgrade your plan."
        case .voiceNotFound:
            return "Voice not found. Please select a different voice."
        case .noVoiceSelected:
            return "No voice selected. Please clone your voice or select a preset voice."
        case .networkError(let message):
            return "Network error: \(message)"
        case .audioGenerationFailed(let message):
            return "Audio generation failed: \(message)"
        case .voiceCloningFailed(let message):
            return "Voice cloning failed: \(message)"
        }
    }
}

