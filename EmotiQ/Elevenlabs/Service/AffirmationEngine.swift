//
//  AffirmationEngine.swift
//  EmotiQ
//
//  Created by Temiloluwa on 06-09-2025.
//

import Foundation
import Combine
import UserNotifications
import CoreData

// MARK: - Affirmation Engine
@MainActor
class AffirmationEngine: ObservableObject {
    static let shared = AffirmationEngine()
    
    @Published var dailyAffirmations: [PersonalizedAffirmation] = []
    @Published var affirmationCategories: [AffirmationCategory] = []
    @Published var isGeneratingAffirmations = false
    @Published var lastGenerationDate: Date?
    
    private let elevenLabsService = ElevenLabsService.shared
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Affirmation templates and AI prompts
    private let affirmationTemplates = AffirmationTemplates()
    private let aiPromptGenerator = AIPromptGenerator()
    
    private init() {
        setupAffirmationCategories()
        loadDailyAffirmations()
    }
    
    // MARK: - Daily Affirmations
    
    /// Generate daily personalized affirmations based on user's emotional patterns
    func generateDailyAffirmations() async throws {
        guard !isGeneratingAffirmations else { return }
        
        isGeneratingAffirmations = true
        defer { isGeneratingAffirmations = false }
        
        // Get user's recent emotional data
        let recentEmotions = try await getRecentEmotionalData()
        let emotionalProfile = analyzeEmotionalProfile(from: recentEmotions)
        
        // Generate personalized affirmations
        let affirmations = try await generatePersonalizedAffirmations(
            for: emotionalProfile,
            count: 5
        )
        
        // Generate voice audio for each affirmation
        var voiceAffirmations: [PersonalizedAffirmation] = []
        
        for affirmation in affirmations {
            do {
                let audioURL = try await elevenLabsService.generateSpeech(
                    text: affirmation.text,
                    emotion: affirmation.targetEmotion,
                    speed: 0.9,
                    stability: 0.8
                )
                
                let voiceAffirmation = PersonalizedAffirmation(
                    id: UUID(),
                    text: affirmation.text,
                    category: affirmation.category,
                    targetEmotion: affirmation.targetEmotion,
                    audioURL: audioURL,
                    createdAt: Date(),
                    isCompleted: false,
                    effectiveness: nil
                )
                
                voiceAffirmations.append(voiceAffirmation)
                
            } catch ElevenLabsError.noVoiceProfile {
                throw ElevenLabsError.noVoiceProfile
                
            } catch {

                throw error
            }
        }
        
        // Update daily affirmations
        dailyAffirmations = voiceAffirmations
        lastGenerationDate = Date()
        
        // Save to persistence
        try await saveDailyAffirmations(voiceAffirmations)
        
        // Schedule delivery notifications
        //scheduleAffirmationNotifications(voiceAffirmations)
        
        HapticManager.shared.notification(.success)
    }
    
    /// Generate affirmations for a specific category
    func generateAffirmations(for category: AffirmationCategory) async throws {
        guard !isGeneratingAffirmations else { return }
        
        isGeneratingAffirmations = true
        defer { isGeneratingAffirmations = false }
        
        // Get user's recent emotional data
        let recentEmotions = try await getRecentEmotionalData()
        let emotionalProfile = analyzeEmotionalProfile(from: recentEmotions)
        
        // Generate personalized affirmations for the specific category
        let affirmations = try await generatePersonalizedAffirmations(
            for: emotionalProfile,
            category: category,
            count: 3
        )
        
        // Generate voice audio for each affirmation
        var voiceAffirmations: [PersonalizedAffirmation] = []
        
        for affirmation in affirmations {
            do {
                let audioURL = try await elevenLabsService.generateSpeech(
                    text: affirmation.text,
                    emotion: affirmation.targetEmotion,
                    speed: 0.9,
                    stability: 0.8
                )
                
                let voiceAffirmation = PersonalizedAffirmation(
                    id: UUID(),
                    text: affirmation.text,
                    category: affirmation.category,
                    targetEmotion: affirmation.targetEmotion,
                    audioURL: audioURL,
                    createdAt: Date(),
                    isCompleted: false,
                    effectiveness: nil
                )
                
                voiceAffirmations.append(voiceAffirmation)
                
            } catch ElevenLabsError.noVoiceProfile {
                throw ElevenLabsError.noVoiceProfile
                
            } catch {
                throw error
            }
        }
        
        // Update daily affirmations with category-specific ones
        dailyAffirmations = voiceAffirmations
        lastGenerationDate = Date()
        
        // Save to persistence
        try await saveDailyAffirmations(voiceAffirmations)
        
        HapticManager.shared.notification(.success)
    }
    
    /// Generate custom affirmation based on user input
    func generateCustomAffirmation(
        text: String,
        category: AffirmationCategory,
        emotion: EmotionType = .joy
    ) async throws -> PersonalizedAffirmation {
        // Enhance the user's text with AI if needed
        let enhancedText = try await enhanceAffirmationText(text, for: category)
        
        var audioURL: URL?
        
        do {
            // Generate voice audio - required for affirmations
            audioURL = try await elevenLabsService.generateSpeech(
                text: enhancedText,
                emotion: emotion,
                speed: 0.9,
                stability: 0.8
            )
        } catch ElevenLabsError.noVoiceProfile {

            throw ElevenLabsError.noVoiceProfile
        } catch {

            throw error
        }
        
        let affirmation = PersonalizedAffirmation(
            id: UUID(),
            text: enhancedText,
            category: category,
            targetEmotion: emotion,
            audioURL: audioURL,
            createdAt: Date(),
            isCompleted: false,
            effectiveness: nil
        )
        
        // Save to persistence
        try await saveCustomAffirmation(affirmation)
        
        HapticManager.shared.impact(.medium)
        
        return affirmation
    }
    
    /// Mark affirmation as completed and rate effectiveness
    func completeAffirmation(_ affirmation: PersonalizedAffirmation, effectiveness: Int) async {
        var updatedAffirmation = affirmation
        updatedAffirmation.isCompleted = true
        updatedAffirmation.effectiveness = effectiveness
        
        // Update in daily affirmations array
        if let index = dailyAffirmations.firstIndex(where: { $0.id == affirmation.id }) {
            dailyAffirmations[index] = updatedAffirmation
        }
        
        // Save to persistence
        try? await updateAffirmationCompletion(updatedAffirmation)
        
        // Learn from effectiveness rating
        await learnFromAffirmationFeedback(updatedAffirmation)
        
        HapticManager.shared.impact(.light)
    }
    
    // MARK: - Affirmation Categories
    
    /// Get affirmations for specific category
    func getAffirmationsForCategory(_ category: AffirmationCategory) async throws -> [PersonalizedAffirmation] {
        let recentEmotions = try await getRecentEmotionalData()
        let emotionalProfile = analyzeEmotionalProfile(from: recentEmotions)
        
        return try await generatePersonalizedAffirmations(
            for: emotionalProfile,
            category: category,
            count: 10
        )
    }
    
    /// Get affirmations for specific emotion
    func getAffirmationsForEmotion(_ emotion: EmotionType) async throws -> [PersonalizedAffirmation] {
        let category = getRecommendedCategoryForEmotion(emotion)
        let templates = affirmationTemplates.getTemplatesForEmotion(emotion)
        
        var affirmations: [PersonalizedAffirmation] = []
        
        for template in templates.prefix(5) {
            let personalizedText = try await personalizeAffirmationTemplate(template, for: emotion)
            
            let audioURL = try await elevenLabsService.generateSpeech(
                text: personalizedText,
                emotion: emotion,
                speed: 0.9,
                stability: 0.8
            )
            
            let affirmation = PersonalizedAffirmation(
                id: UUID(),
                text: personalizedText,
                category: category,
                targetEmotion: emotion,
                audioURL: audioURL,
                createdAt: Date(),
                isCompleted: false,
                effectiveness: nil
            )
            
            affirmations.append(affirmation)
        }
        
        return affirmations
    }
    
    // MARK: - AI-Powered Personalization
    
    /// Generate personalized affirmations using AI
    private func generatePersonalizedAffirmations(
        for profile: EmotionalProfile,
        category: AffirmationCategory? = nil,
        count: Int = 5
    ) async throws -> [PersonalizedAffirmation] {
        
        var affirmations: [PersonalizedAffirmation] = []
        let categories = category != nil ? [category!] : getRecommendedCategories(for: profile)
        
        for targetCategory in categories.prefix(count) {
            let prompt = aiPromptGenerator.generateAffirmationPrompt(
                for: profile,
                category: targetCategory
            )
            
            // In a real implementation, this would call OpenAI or similar AI service
            // For now, we'll use intelligent template selection and personalization
            let template = affirmationTemplates.getBestTemplate(
                for: targetCategory,
                emotionalProfile: profile
            )
            
            let personalizedText = try await personalizeAffirmationTemplate(template, for: profile.dominantEmotion)
            
            let affirmation = PersonalizedAffirmation(
                id: UUID(),
                text: personalizedText,
                category: targetCategory,
                targetEmotion: getTargetEmotionForCategory(targetCategory),
                audioURL: nil, // Will be generated later
                createdAt: Date(),
                isCompleted: false,
                effectiveness: nil
            )
            
            affirmations.append(affirmation)
        }
        
        return affirmations
    }
    
    /// Enhance user-provided affirmation text with AI
    private func enhanceAffirmationText(_ text: String, for category: AffirmationCategory) async throws -> String {
        // Simple enhancement logic - in production, this would use AI
        let enhancedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure it's in first person and positive
        if !enhancedText.lowercased().contains("i ") && !enhancedText.lowercased().starts(with: "i ") {
            return "I \(enhancedText.lowercased())"
        }
        
        return enhancedText
    }
    
    /// Personalize affirmation template based on user data
    private func personalizeAffirmationTemplate(_ template: String, for emotion: EmotionType) async throws -> String {
        // Get user's name if available
        let userName = await getCurrentUserName() ?? "friend"
        
        // Replace placeholders
        var personalizedText = template
            .replacingOccurrences(of: "{name}", with: userName)
            .replacingOccurrences(of: "{emotion}", with: emotion.displayName.lowercased())
        
        // Add emotional context
        switch emotion {
        case .sadness:
            personalizedText = personalizedText.replacingOccurrences(of: "{context}", with: "even in difficult moments")
        case .anger:
            personalizedText = personalizedText.replacingOccurrences(of: "{context}", with: "with patience and understanding")
        case .fear:
            personalizedText = personalizedText.replacingOccurrences(of: "{context}", with: "with courage and confidence")
        case .joy:
            personalizedText = personalizedText.replacingOccurrences(of: "{context}", with: "with gratitude and enthusiasm")
        case .surprise:
            personalizedText = personalizedText.replacingOccurrences(of: "{context}", with: "with openness and curiosity")
        case .disgust:
            personalizedText = personalizedText.replacingOccurrences(of: "{context}", with: "with acceptance and growth")
        case .neutral:
            personalizedText = personalizedText.replacingOccurrences(of: "{context}", with: "with balance and clarity")
        }
        
        return personalizedText
    }
    
    // MARK: - Emotional Analysis
    
    /// Analyze user's emotional profile from recent data
    private func analyzeEmotionalProfile(from emotions: [EmotionalData]) -> EmotionalProfile {
        guard !emotions.isEmpty else {
            return EmotionalProfile(
                dominantEmotion: .neutral,
                emotionDistribution: [:],
                stressLevel: 0.5,
                moodVariability: 0.5,
                needsSupport: false
            )
        }
        
        // Calculate emotion distribution
        var emotionCounts: [EmotionType: Int] = [:]
        var totalConfidence: Double = 0
        var stressIndicators: Double = 0
        
        for emotion in emotions {
            emotionCounts[emotion.primaryEmotion, default: 0] += 1
            totalConfidence += emotion.confidence
            
            // Calculate stress indicators
            if [EmotionType.anger, .fear, .sadness].contains(emotion.primaryEmotion) {
                stressIndicators += emotion.confidence
            }
        }
        
        // Find dominant emotion
        let dominantEmotion = emotionCounts.max(by: { $0.value < $1.value })?.key ?? .neutral
        
        // Calculate distribution percentages
        let total = emotions.count
        let emotionDistribution = emotionCounts.mapValues { Double($0) / Double(total) }
        
        // Calculate metrics
        let averageConfidence = totalConfidence / Double(emotions.count)
        let stressLevel = stressIndicators / totalConfidence
        let moodVariability = calculateMoodVariability(from: emotions)
        let needsSupport = stressLevel > 0.6 || moodVariability > 0.7
        
        return EmotionalProfile(
            dominantEmotion: dominantEmotion,
            emotionDistribution: emotionDistribution,
            stressLevel: stressLevel,
            moodVariability: moodVariability,
            needsSupport: needsSupport
        )
    }
    
    /// Calculate mood variability from emotional data
    private func calculateMoodVariability(from emotions: [EmotionalData]) -> Double {
        guard emotions.count > 1 else { return 0.0 }
        
        let emotionValues = emotions.map { emotion -> Double in
            switch emotion.primaryEmotion {
            case .joy: return 1.0
            case .surprise: return 0.5
            case .neutral: return 0.0
            case .disgust: return -0.3
            case .fear: return -0.6
            case .anger: return -0.8
            case .sadness: return -1.0
            }
        }
        
        let mean = emotionValues.reduce(0, +) / Double(emotionValues.count)
        let variance = emotionValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(emotionValues.count)
        
        return sqrt(variance) / 2.0 // Normalize to 0-1 range
    }
    
    // MARK: - Category Recommendations
    
    /// Get recommended affirmation categories based on emotional profile
    private func getRecommendedCategories(for profile: EmotionalProfile) -> [AffirmationCategory] {
        var categories: [AffirmationCategory] = []
        
        // Always include self-compassion for support
        if profile.needsSupport {
            categories.append(.selfCompassion)
        }
        
        // Add categories based on dominant emotion
        switch profile.dominantEmotion {
        case .sadness:
            categories.append(contentsOf: [.selfCompassion, .hope, .gratitude])
        case .anger:
            categories.append(contentsOf: [.calmness, .forgiveness, .selfCompassion])
        case .fear:
            categories.append(contentsOf: [.courage, .confidence, .safety])
        case .joy:
            categories.append(contentsOf: [.gratitude, .abundance, .confidence])
        case .surprise:
            categories.append(contentsOf: [.growth, .curiosity, .confidence])
        case .disgust:
            categories.append(contentsOf: [.acceptance, .growth, .selfCompassion])
        case .neutral:
            categories.append(contentsOf: [.motivation, .confidence, .gratitude])
        }
        
        // Add categories based on stress level
        if profile.stressLevel > 0.7 {
            categories.append(contentsOf: [.calmness, .relaxation, .selfCompassion])
        }
        
        // Add categories based on mood variability
        if profile.moodVariability > 0.6 {
            categories.append(contentsOf: [.stability, .grounding, .balance])
        }
        
        // Remove duplicates and return top 5
        return Array(Set(categories)).prefix(5).map { $0 }
    }
    
    /// Get recommended category for specific emotion
    private func getRecommendedCategoryForEmotion(_ emotion: EmotionType) -> AffirmationCategory {
        switch emotion {
        case .sadness: return .selfCompassion
        case .anger: return .calmness
        case .fear: return .courage
        case .joy: return .gratitude
        case .surprise: return .growth
        case .disgust: return .acceptance
        case .neutral: return .confidence
        }
    }
    
    /// Get target emotion for affirmation category
    private func getTargetEmotionForCategory(_ category: AffirmationCategory) -> EmotionType {
        switch category {
        case .confidence, .courage: return .joy
        case .gratitude, .abundance: return .joy
        case .calmness, .relaxation: return .neutral
        case .selfCompassion, .forgiveness: return .neutral
        case .hope, .motivation: return .joy
        case .growth, .curiosity: return .surprise
        case .acceptance, .balance: return .neutral
        case .stability, .grounding: return .neutral
        case .safety: return .neutral
        }
    }
    
    // MARK: - Notification Scheduling
    
    
    // MARK: - Learning and Adaptation
    
    /// Learn from user feedback on affirmation effectiveness
    private func learnFromAffirmationFeedback(_ affirmation: PersonalizedAffirmation) async {
        guard let effectiveness = affirmation.effectiveness else { return }
        
        // Store feedback for future personalization
        let feedback = AffirmationFeedback(
            affirmationId: affirmation.id,
            category: affirmation.category,
            targetEmotion: affirmation.targetEmotion,
            effectiveness: effectiveness,
            timestamp: Date()
        )
        
        try? await saveAffirmationFeedback(feedback)
        
        // Adjust future affirmation generation based on feedback
        if effectiveness >= 4 {
            // This was effective - remember the pattern
            await reinforceSuccessfulPattern(affirmation)
        } else if effectiveness <= 2 {
            // This wasn't effective - avoid similar patterns
            await avoidUnsuccessfulPattern(affirmation)
        }
    }
    
    /// Reinforce successful affirmation patterns
    private func reinforceSuccessfulPattern(_ affirmation: PersonalizedAffirmation) async {
        // In a production app, this would update ML models or preference weights
        // For now, we'll store successful patterns for future reference
        let pattern = SuccessfulPattern(
            category: affirmation.category,
            emotion: affirmation.targetEmotion,
            textPattern: extractTextPattern(from: affirmation.text),
            timestamp: Date()
        )
        
        try? await saveSuccessfulPattern(pattern)
    }
    
    /// Avoid unsuccessful affirmation patterns
    private func avoidUnsuccessfulPattern(_ affirmation: PersonalizedAffirmation) async {
        let pattern = UnsuccessfulPattern(
            category: affirmation.category,
            emotion: affirmation.targetEmotion,
            textPattern: extractTextPattern(from: affirmation.text),
            timestamp: Date()
        )
        
        try? await saveUnsuccessfulPattern(pattern)
    }
    
    /// Extract pattern from affirmation text for learning
    private func extractTextPattern(from text: String) -> String {
        // Simple pattern extraction - in production, this would be more sophisticated
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let keyWords = words.filter { $0.count > 3 && !$0.isEmpty }.prefix(3)
        return keyWords.joined(separator: "_")
    }
    
    // MARK: - Data Persistence
    
    /// Get recent emotional data for analysis
    private func getRecentEmotionalData() async throws -> [EmotionalData] {
        let context = persistenceController.container.viewContext
        let request = EmotionalDataEntity.fetchRequest()
        
        // Get data from last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "timestamp >= %@", sevenDaysAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: false)]
        request.fetchLimit = 50
        
        let entities = try context.fetch(request)
        return entities.compactMap { $0.toEmotionalData() }
    }
    
    /// Get current user name
    private func getCurrentUserName() async -> String? {
        let context = persistenceController.container.viewContext
        let request = User.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            return users.first?.name
        } catch {
            return nil
        }
    }
    
    /// Save daily affirmations to persistence
    private func saveDailyAffirmations(_ affirmations: [PersonalizedAffirmation]) async throws {
        let context = persistenceController.container.viewContext
        
        // Get current user
        let userRequest = User.fetchRequest()
        let users = try context.fetch(userRequest)
        guard let user = users.first else {
            throw AffirmationError.noUserFound
        }
        
        // Save each affirmation
        for affirmation in affirmations {
            let entity = AffirmationEntity(context: context)
            entity.id = affirmation.id
            entity.text = affirmation.text
            entity.category = affirmation.category.rawValue
            entity.targetEmotion = affirmation.targetEmotion.rawValue
            entity.audioURL = affirmation.audioURL?.absoluteString
            entity.createdAt = affirmation.createdAt
            entity.isCompleted = affirmation.isCompleted
            entity.effectivenessRating = Int16(affirmation.effectiveness ?? 0)
            entity.isCustom = false
            entity.playCount = 0
            entity.lastPlayedAt = nil
            entity.isFavorite = false
            entity.duration = 0.0
            entity.user = user
        }
        
        try context.save()
        
    }
    
    /// Save custom affirmation to persistence
    private func saveCustomAffirmation(_ affirmation: PersonalizedAffirmation) async throws {
        let context = persistenceController.container.viewContext
        
        // Get current user
        let userRequest = User.fetchRequest()
        let users = try context.fetch(userRequest)
        guard let user = users.first else {
            throw AffirmationError.noUserFound
        }
        
        let entity = AffirmationEntity(context: context)
        entity.id = affirmation.id
        entity.text = affirmation.text
        entity.category = affirmation.category.rawValue
        entity.targetEmotion = affirmation.targetEmotion.rawValue
        entity.audioURL = affirmation.audioURL?.absoluteString
        entity.createdAt = affirmation.createdAt
        entity.isCompleted = affirmation.isCompleted
        entity.effectivenessRating = Int16(affirmation.effectiveness ?? 0)
        entity.isCustom = true
        entity.playCount = 0
        entity.lastPlayedAt = nil
        entity.isFavorite = false
        entity.duration = 0.0
        entity.user = user
        
        try context.save()
        
    }
    
    /// Update affirmation completion status
    private func updateAffirmationCompletion(_ affirmation: PersonalizedAffirmation) async throws {
        let context = persistenceController.container.viewContext
        let request = AffirmationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", affirmation.id as CVarArg)
        
        let entities = try context.fetch(request)
        guard let entity = entities.first else {
            throw AffirmationError.affirmationNotFound
        }
        
        entity.isCompleted = affirmation.isCompleted
        entity.effectivenessRating = Int16(affirmation.effectiveness ?? 0)
        entity.lastPlayedAt = Date()
        entity.playCount += 1
        
        try context.save()
        
    }
    
    /// Save affirmation feedback
    private func saveAffirmationFeedback(_ feedback: AffirmationFeedback) async throws {
        let context = persistenceController.container.viewContext
        
        // Get current user
        let userRequest = User.fetchRequest()
        let users = try context.fetch(userRequest)
        guard let user = users.first else {
            throw AffirmationError.noUserFound
        }
        
        // Create feedback entity in Core Data
        let entity = AffirmationFeedbackEntity(context: context)
        entity.id = UUID()
        entity.affirmationId = feedback.affirmationId
        entity.category = feedback.category.rawValue
        entity.targetEmotion = feedback.targetEmotion.rawValue
        entity.effectiveness = Int16(feedback.effectiveness)
        entity.createdAt = feedback.timestamp
        entity.user = user
        
        try context.save()
        

    }
    
    /// Save successful pattern
    private func saveSuccessfulPattern(_ pattern: SuccessfulPattern) async throws {
        let context = persistenceController.container.viewContext
        
        // Get current user
        let userRequest = User.fetchRequest()
        let users = try context.fetch(userRequest)
        guard let user = users.first else {
            throw AffirmationError.noUserFound
        }
        
        // Create successful pattern entity in Core Data
        let entity = SuccessfulPatternEntity(context: context)
        entity.id = UUID()
        entity.category = pattern.category.rawValue
        entity.emotion = pattern.emotion.rawValue
        entity.textPattern = pattern.textPattern
        entity.createdAt = pattern.timestamp
        entity.user = user
        
        try context.save()

    }
    
    /// Save unsuccessful pattern
    private func saveUnsuccessfulPattern(_ pattern: UnsuccessfulPattern) async throws {
        let context = persistenceController.container.viewContext
        
        // Get current user
        let userRequest = User.fetchRequest()
        let users = try context.fetch(userRequest)
        guard let user = users.first else {
            throw AffirmationError.noUserFound
        }
        
        // Create unsuccessful pattern entity in Core Data
        let entity = UnsuccessfulPatternEntity(context: context)
        entity.id = UUID()
        entity.category = pattern.category.rawValue
        entity.emotion = pattern.emotion.rawValue
        entity.textPattern = pattern.textPattern
        entity.createdAt = pattern.timestamp
        entity.user = user
        
        try context.save()
        

    }
    
    /// Load daily affirmations from persistence
    private func loadDailyAffirmations() {
        let context = persistenceController.container.viewContext
        let request = AffirmationEntity.fetchRequest()
        
        // Get affirmations from today
        let today = Calendar.current.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "createdAt >= %@ AND isCustom == NO", today as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AffirmationEntity.createdAt, ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            dailyAffirmations = entities.compactMap { entity -> PersonalizedAffirmation? in
                guard let id = entity.id,
                      let text = entity.text,
                      let categoryString = entity.category,
                      let category = AffirmationCategory(rawValue: categoryString),
                      let targetEmotionString = entity.targetEmotion,
                      let targetEmotion = EmotionType(rawValue: targetEmotionString),
                      let createdAt = entity.createdAt else {
                    return nil
                }
                
                let audioURL = entity.audioURL.flatMap { URL(string: $0) }
                
                return PersonalizedAffirmation(
                    id: id,
                    text: text,
                    category: category,
                    targetEmotion: targetEmotion,
                    audioURL: audioURL,
                    createdAt: createdAt,
                    isCompleted: entity.isCompleted,
                    effectiveness: Int(entity.effectivenessRating)
                )
            }
//            

        } catch {

            dailyAffirmations = []
        }
    }
    
    /// Setup affirmation categories
    private func setupAffirmationCategories() {
        affirmationCategories = AffirmationCategory.allCases
    }
}

// MARK: - Data Models

struct PersonalizedAffirmation: Identifiable, Codable {
    let id: UUID
    let text: String
    let category: AffirmationCategory
    let targetEmotion: EmotionType
    let audioURL: URL?
    let createdAt: Date
    var isCompleted: Bool
    var effectiveness: Int? // 1-5 rating
}

// MARK: - Error Types

enum AffirmationError: LocalizedError {
    case noUserFound
    case affirmationNotFound
    case invalidData
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .noUserFound:
            return "No user found in the system"
        case .affirmationNotFound:
            return "Affirmation not found in database"
        case .invalidData:
            return "Invalid affirmation data"
        case .saveFailed:
            return "Failed to save affirmation data"
        }
    }
}

// MARK: - Core Data Integration Complete

enum AffirmationCategory: String, CaseIterable, Codable {
    case confidence = "confidence"
    case selfCompassion = "self_compassion"
    case gratitude = "gratitude"
    case courage = "courage"
    case calmness = "calmness"
    case hope = "hope"
    case motivation = "motivation"
    case abundance = "abundance"
    case forgiveness = "forgiveness"
    case acceptance = "acceptance"
    case growth = "growth"
    case curiosity = "curiosity"
    case relaxation = "relaxation"
    case stability = "stability"
    case grounding = "grounding"
    case balance = "balance"
    case safety = "safety"
    
    var displayName: String {
        switch self {
        case .confidence: return "Confidence"
        case .selfCompassion: return "Self-Compassion"
        case .gratitude: return "Gratitude"
        case .courage: return "Courage"
        case .calmness: return "Calmness"
        case .hope: return "Hope"
        case .motivation: return "Motivation"
        case .abundance: return "Abundance"
        case .forgiveness: return "Forgiveness"
        case .acceptance: return "Acceptance"
        case .growth: return "Growth"
        case .curiosity: return "Curiosity"
        case .relaxation: return "Relaxation"
        case .stability: return "Stability"
        case .grounding: return "Grounding"
        case .balance: return "Balance"
        case .safety: return "Safety"
        }
    }
    
    var icon: String {
        switch self {
        case .confidence: return "star.fill"
        case .selfCompassion: return "heart.fill"
        case .gratitude: return "hands.sparkles.fill"
        case .courage: return "shield.fill"
        case .calmness: return "leaf.fill"
        case .hope: return "sunrise.fill"
        case .motivation: return "flame.fill"
        case .abundance: return "infinity"
        case .forgiveness: return "peacesign"
        case .acceptance: return "checkmark.circle.fill"
        case .growth: return "tree.fill"
        case .curiosity: return "eye.fill"
        case .relaxation: return "moon.fill"
        case .stability: return "mountain.2.fill"
        case .grounding: return "globe"
        case .balance: return "scale.3d"
        case .safety: return "house.fill"
        }
    }
    
    var color: String {
        switch self {
        case .confidence: return "yellow"
        case .selfCompassion: return "pink"
        case .gratitude: return "green"
        case .courage: return "red"
        case .calmness: return "blue"
        case .hope: return "orange"
        case .motivation: return "purple"
        case .abundance: return "gold"
        case .forgiveness: return "mint"
        case .acceptance: return "teal"
        case .growth: return "green"
        case .curiosity: return "indigo"
        case .relaxation: return "lavender"
        case .stability: return "brown"
        case .grounding: return "earth"
        case .balance: return "gray"
        case .safety: return "blue"
        }
    }
}

struct EmotionalProfile {
    let dominantEmotion: EmotionType
    let emotionDistribution: [EmotionType: Double]
    let stressLevel: Double // 0.0 to 1.0
    let moodVariability: Double // 0.0 to 1.0
    let needsSupport: Bool
}

struct AffirmationFeedback {
    let affirmationId: UUID
    let category: AffirmationCategory
    let targetEmotion: EmotionType
    let effectiveness: Int
    let timestamp: Date
}

struct SuccessfulPattern {
    let category: AffirmationCategory
    let emotion: EmotionType
    let textPattern: String
    let timestamp: Date
}

struct UnsuccessfulPattern {
    let category: AffirmationCategory
    let emotion: EmotionType
    let textPattern: String
    let timestamp: Date
}

// MARK: - Affirmation Templates

class AffirmationTemplates {
    
    /// Get templates for specific emotion
    func getTemplatesForEmotion(_ emotion: EmotionType) -> [String] {
        switch emotion {
        case .sadness:
            return [
                "I am worthy of love and compassion, especially from myself.",
                "This difficult moment will pass, and I will emerge stronger.",
                "I allow myself to feel this emotion while knowing it doesn't define me.",
                "I am surrounded by love, even when I can't feel it right now.",
                "My feelings are valid, and I treat myself with kindness."
            ]
        case .anger:
            return [
                "I breathe deeply and choose peace over anger.",
                "I have the power to respond with wisdom rather than react with fury.",
                "My anger is information, and I listen to it with compassion.",
                "I release what I cannot control and focus on what I can change.",
                "I am in control of my responses and choose love over anger."
            ]
        case .fear:
            return [
                "I am braver than I believe and stronger than I feel.",
                "I face my fears with courage and take one step at a time.",
                "I am safe in this moment, and I trust in my ability to handle whatever comes.",
                "Fear is just a feeling, and I am bigger than any feeling.",
                "I choose courage over comfort and growth over safety."
            ]
        case .joy:
            return [
                "I celebrate this moment of joy and let it fill my entire being.",
                "I am grateful for this happiness and share it with the world.",
                "Joy is my natural state, and I welcome it with open arms.",
                "I deserve this happiness and allow myself to fully experience it.",
                "My joy is contagious and brings light to others around me."
            ]
        case .surprise:
            return [
                "I embrace the unexpected with curiosity and wonder.",
                "Life's surprises are opportunities for growth and discovery.",
                "I am adaptable and find opportunity in every change.",
                "I welcome new experiences with an open heart and mind.",
                "Surprises remind me that life is full of beautiful possibilities."
            ]
        case .disgust:
            return [
                "I accept what I cannot change and work to change what I can.",
                "I choose to focus on what brings me peace and joy.",
                "I release judgment and embrace acceptance and understanding.",
                "I trust that every experience teaches me something valuable.",
                "I find beauty and meaning even in difficult situations."
            ]
        case .neutral:
            return [
                "I am centered, balanced, and at peace with this moment.",
                "I trust in my ability to navigate whatever comes my way.",
                "I am exactly where I need to be in this moment.",
                "I embrace the calm and use it to recharge my spirit.",
                "I am grateful for this peaceful moment and the clarity it brings."
            ]
        }
    }
    
    /// Get best template for category and emotional profile
    func getBestTemplate(for category: AffirmationCategory, emotionalProfile: EmotionalProfile) -> String {
        let templates = getTemplatesForCategory(category)
        
        // Simple selection based on emotional profile
        // In production, this would use ML to select the most effective template
        if emotionalProfile.needsSupport {
            return templates.first { $0.contains("compassion") || $0.contains("worthy") || $0.contains("safe") } ?? templates.first ?? ""
        } else {
            return templates.randomElement() ?? ""
        }
    }
    
    /// Get templates for specific category
    private func getTemplatesForCategory(_ category: AffirmationCategory) -> [String] {
        switch category {
        case .confidence:
            return [
                "I believe in myself and my abilities.",
                "I am capable of achieving great things.",
                "I trust my decisions and stand by my choices.",
                "I am worthy of success and happiness.",
                "I embrace challenges as opportunities to grow."
            ]
        case .selfCompassion:
            return [
                "I treat myself with the same kindness I show to others.",
                "I am human, and making mistakes is part of learning.",
                "I forgive myself and choose to move forward with love.",
                "I am worthy of compassion, especially from myself.",
                "I speak to myself with gentleness and understanding."
            ]
        case .gratitude:
            return [
                "I am grateful for all the blessings in my life.",
                "I appreciate the small moments that bring me joy.",
                "I focus on what I have rather than what I lack.",
                "Gratitude fills my heart and transforms my perspective.",
                "I find something to be thankful for in every day."
            ]
        case .courage:
            return [
                "I have the courage to face any challenge.",
                "I am brave enough to pursue my dreams.",
                "I step outside my comfort zone with confidence.",
                "I trust in my strength to overcome obstacles.",
                "I choose courage over fear in every situation."
            ]
        case .calmness:
            return [
                "I am at peace with myself and the world around me.",
                "I breathe deeply and let tranquility wash over me.",
                "I remain calm and centered in all situations.",
                "Peace flows through me like a gentle river.",
                "I choose serenity over stress in every moment."
            ]
        case .hope:
            return [
                "I believe in the possibility of positive change.",
                "Tomorrow holds new opportunities and fresh beginnings.",
                "I maintain hope even in challenging times.",
                "I trust that everything will work out for my highest good.",
                "Hope lights my way through any darkness."
            ]
        case .motivation:
            return [
                "I am motivated to create the life I desire.",
                "I take action towards my goals every day.",
                "I have the energy and drive to succeed.",
                "I am inspired to make a positive difference.",
                "I turn my dreams into reality through consistent action."
            ]
        case .abundance:
            return [
                "I live in a world of infinite possibilities.",
                "Abundance flows to me in all areas of my life.",
                "I am open to receiving all the good life has to offer.",
                "I have everything I need to be happy and successful.",
                "I attract prosperity and abundance effortlessly."
            ]
        case .forgiveness:
            return [
                "I forgive others and free myself from resentment.",
                "I release the past and embrace the present moment.",
                "Forgiveness is a gift I give to myself.",
                "I choose understanding over judgment.",
                "I let go of what no longer serves me."
            ]
        case .acceptance:
            return [
                "I accept myself exactly as I am right now.",
                "I embrace all aspects of my journey.",
                "I find peace in accepting what I cannot change.",
                "I am perfectly imperfect, and that's enough.",
                "I accept life's ups and downs with grace."
            ]
        case .growth:
            return [
                "I am constantly growing and evolving.",
                "Every experience teaches me something valuable.",
                "I embrace change as an opportunity for growth.",
                "I am becoming the best version of myself.",
                "I learn from every challenge and become stronger."
            ]
        case .curiosity:
            return [
                "I approach life with wonder and curiosity.",
                "I am open to learning new things every day.",
                "I ask questions and seek to understand.",
                "Life is an adventure full of discoveries.",
                "I remain curious about the world around me."
            ]
        case .relaxation:
            return [
                "I allow my body and mind to relax completely.",
                "I release all tension and embrace peace.",
                "Relaxation comes naturally to me.",
                "I give myself permission to rest and recharge.",
                "I find calm in the midst of any storm."
            ]
        case .stability:
            return [
                "I am grounded and stable in all situations.",
                "I provide a steady foundation for myself and others.",
                "I remain balanced no matter what life brings.",
                "I am a rock of stability in changing times.",
                "I trust in my ability to remain centered."
            ]
        case .grounding:
            return [
                "I am connected to the earth and feel its support.",
                "I am rooted in the present moment.",
                "I feel stable and secure in my being.",
                "I draw strength from my connection to the ground beneath me.",
                "I am anchored in peace and stability."
            ]
        case .balance:
            return [
                "I maintain perfect balance in all areas of my life.",
                "I honor both my needs and the needs of others.",
                "I find harmony between work and rest.",
                "Balance comes naturally to me.",
                "I create equilibrium in my thoughts and actions."
            ]
        case .safety:
            return [
                "I am safe and protected in this moment.",
                "I trust in my ability to keep myself safe.",
                "I create a safe space wherever I go.",
                "I am surrounded by love and protection.",
                "I feel secure in my body and in my life."
            ]
        }
    }
}

// MARK: - AI Prompt Generator

class AIPromptGenerator {
    
    /// Generate AI prompt for affirmation creation
    func generateAffirmationPrompt(for profile: EmotionalProfile, category: AffirmationCategory) -> String {
        let emotionContext = getEmotionContext(for: profile.dominantEmotion)
        let stressContext = getStressContext(for: profile.stressLevel)
        let categoryContext = getCategoryContext(for: category)
        
        return """
        Create a personalized affirmation for someone who:
        - Is currently experiencing \(emotionContext)
        - Has a stress level of \(stressContext)
        - Needs support in the area of \(categoryContext)
        
        The affirmation should be:
        - Written in first person ("I" statements)
        - Positive and empowering
        - Specific to their emotional state
        - Actionable and believable
        - 10-20 words long
        """
    }
    
    private func getEmotionContext(for emotion: EmotionType) -> String {
        switch emotion {
        case .sadness: return "sadness and may need comfort and hope"
        case .anger: return "anger and may need calming and perspective"
        case .fear: return "fear and may need courage and reassurance"
        case .joy: return "joy and wants to amplify positive feelings"
        case .surprise: return "surprise and is adapting to change"
        case .disgust: return "dissatisfaction and needs acceptance"
        case .neutral: return "emotional balance and wants to maintain stability"
        }
    }
    
    private func getStressContext(for level: Double) -> String {
        switch level {
        case 0.0..<0.3: return "low stress"
        case 0.3..<0.6: return "moderate stress"
        case 0.6..<0.8: return "high stress"
        default: return "very high stress"
        }
    }
    
    private func getCategoryContext(for category: AffirmationCategory) -> String {
        return category.displayName.lowercased()
    }
}


