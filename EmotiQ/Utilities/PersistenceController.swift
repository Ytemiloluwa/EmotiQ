//
//  Persistence.swift
//  EmotiQ
//
//  Created by Temiloluwa on 31-07-2025.
//

import CoreData
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        return result
    }()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: Config.CoreData.containerName)
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit if enabled
            if Config.CoreData.enableCloudKit {
                container.persistentStoreDescriptions.forEach { storeDescription in
                    storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                    storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                    
                    // CloudKit configuration
                    //storeDescription.setOption(true as NSNumber, forKey: NSPersistentCloudKitContainerOptionsKey)
                }
            }
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Handle different types of Core Data errors
                if Config.isDebugMode {
                    print("❌ Core Data Error: \(error)")
                    print("   Description: \(error.localizedDescription)")
                    print("   User Info: \(error.userInfo)")
                }
                
                // In production, you might want to handle this more gracefully
                // For now, we'll crash in debug but handle gracefully in production
                if Config.isDebugMode {
                    fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
                } else {
                    // Log error to crash reporting service
                    print("Core Data failed to load: \(error.localizedDescription)")
                }
            } else {
                if Config.isDebugMode {
                    print("✅ Core Data loaded successfully")
                    if Config.CoreData.enableCloudKit {
                        print("   CloudKit sync enabled")
                    }
                }
            }
        })
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configure merge policy for conflicts
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Enable persistent history tracking if configured
        if Config.CoreData.enablePersistentHistory {
            container.viewContext.transactionAuthor = "EmotiQ-App"
        }
        
        // Setup remote change notifications if enabled
        if Config.CoreData.enableRemoteChangeNotifications {
            NotificationCenter.default.addObserver(
                forName: .NSPersistentStoreRemoteChange,
                object: container.persistentStoreCoordinator,
                queue: .main
            ) { _ in
                if Config.isDebugMode {
                    print("🔄 Remote Core Data changes detected")
                }
            }
        }
    }
    
    // MARK: - Save Context
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                if Config.isDebugMode {
                    print("💾 Core Data saved successfully")
                }
            } catch {
                let nsError = error as NSError
                if Config.isDebugMode {
                    print("❌ Core Data save error: \(nsError)")
                }
                
                // In production, handle this more gracefully
                if Config.isDebugMode {
                    fatalError("Unresolved save error \(nsError), \(nsError.userInfo)")
                } else {
                    print("Failed to save Core Data: \(nsError.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - User Management
    func getCurrentUser() -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let users = try container.viewContext.fetch(request)
            return users.first
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch current user: \(error)")
            }
            return nil
        }
    }
    
    func createUserIfNeeded() -> User {
        if let existingUser = getCurrentUser() {
            // Migrate existing user data to weekly model if needed
            migrateUserToWeeklyModel(existingUser)
            return existingUser
        }
        
        let newUser = User(context: container.viewContext)
        newUser.id = UUID()
        newUser.createdAt = Date()
        newUser.subscriptionStatus = SubscriptionStatus.free.rawValue
        newUser.dailyCheckInsUsed = 0
        newUser.lastCheckInDate = nil
        newUser.weeklyCheckInsUsed = 0
        newUser.weekStartDate = Date()
        newUser.trialStartDate = Date()
        
        save()
        
        if Config.isDebugMode {
            print("👤 New user created with ID: \(newUser.id?.uuidString ?? "unknown")")
        }
        
        return newUser
    }
    
    // MARK: - Data Migration
    private func migrateUserToWeeklyModel(_ user: User) {
        // Only migrate if weekly attributes are not set
        guard user.weeklyCheckInsUsed == 0 && user.weekStartDate == nil else {
            return
        }
        
        // Convert existing daily usage to weekly usage
        user.weeklyCheckInsUsed = user.dailyCheckInsUsed
        
        // Set week start date to last check-in date or creation date
        if let lastCheckIn = user.lastCheckInDate {
            user.weekStartDate = lastCheckIn
        } else {
            user.weekStartDate = user.createdAt ?? Date()
        }
        
        // Set trial start date to creation date
        user.trialStartDate = user.createdAt ?? Date()
        
        save()
        
        if Config.isDebugMode {
            print("🔄 Migrated user to weekly model: weeklyCheckInsUsed=\(user.weeklyCheckInsUsed), weekStartDate=\(user.weekStartDate?.description ?? "nil")")
        }
    }
    
    // MARK: - Weekly Usage Reset Logic
    func shouldResetWeeklyUsage(for user: User) -> Bool {
        guard let weekStart = user.weekStartDate else {
            // No week start date, set it now
            user.weekStartDate = Date()
            return false
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Check if 7 days have passed since week start
        let daysSinceWeekStart = calendar.dateComponents([.day], from: weekStart, to: now).day ?? 0
        return daysSinceWeekStart >= 7
    }
    
    func resetWeeklyUsage(for user: User) {
        user.weeklyCheckInsUsed = 0
        user.weekStartDate = Date()
        save()
        
        if Config.isDebugMode {
            print("🔄 Weekly usage reset for user: \(user.id?.uuidString ?? "unknown")")
        }
    }
    
    // MARK: - Weekly Usage Management (New Implementation)
    func canPerformWeeklyCheckIn(for user: User) -> Bool {
        let subscriptionStatus = SubscriptionStatus(rawValue: user.subscriptionStatus ?? "free") ?? .free
        
        // Premium and Pro users have unlimited access
        if subscriptionStatus != .free {
            return true
        }
        
        // Check if we need to reset weekly usage
        if shouldResetWeeklyUsage(for: user) {
            resetWeeklyUsage(for: user)
        }
        
        // Check weekly limit
        return user.weeklyCheckInsUsed < Config.Subscription.freeWeeklyLimit
    }
    
    // MARK: - Daily Usage Management (Legacy - Keep for backward compatibility)
    func canPerformDailyCheckIn(for user: User) -> Bool {
        let subscriptionStatus = SubscriptionStatus(rawValue: user.subscriptionStatus ?? "free") ?? .free
        
        // Premium and Pro users have unlimited access
        if subscriptionStatus != .free {
            return true
        }
        
        // Check if it's a new day
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastCheckIn = user.lastCheckInDate {
            let lastCheckInDay = calendar.startOfDay(for: lastCheckIn)
            if lastCheckInDay < today {
                // Reset daily usage for new day
                user.dailyCheckInsUsed = 0
                save()
            }
        }
        
        // Check daily limit
        return user.dailyCheckInsUsed < Config.Subscription.freeDailyLimit
    }
    
    func incrementWeeklyUsage(for user: User) {
        user.weeklyCheckInsUsed += 1
        user.lastCheckInDate = Date()
        
        // Set week start date if not set
        if user.weekStartDate == nil {
            user.weekStartDate = Date()
        }
        
        save()
        
        if Config.isDebugMode {
            print("📊 Weekly usage incremented: \(user.weeklyCheckInsUsed)/\(Config.Subscription.freeWeeklyLimit)")
        }
    }
    
    func incrementDailyUsage(for user: User) {
        user.dailyCheckInsUsed += 1
        user.lastCheckInDate = Date()
        save()
        
        if Config.isDebugMode {
            print("📊 Daily usage incremented: \(user.dailyCheckInsUsed)/\(Config.Subscription.freeDailyLimit)")
        }
    }
    
    // MARK: - Emotional Data Management
    func saveEmotionalData(_ emotionalData: EmotionalData, for user: User) {
        let entity = EmotionalDataEntity(context: container.viewContext)
        entity.id = emotionalData.id
        entity.timestamp = emotionalData.timestamp
        entity.primaryEmotion = emotionalData.primaryEmotion.rawValue
        entity.confidence = emotionalData.confidence
        entity.intensity = emotionalData.intensity
        entity.user = user
        
        // Encode voice features if available
        if let voiceFeatures = emotionalData.voiceFeatures {
            do {
                let encoder = JSONEncoder()
                entity.voiceFeaturesData = try encoder.encode(voiceFeatures)
            } catch {
                if Config.isDebugMode {
                    print("❌ Failed to encode voice features: \(error)")
                }
            }
        }
        
        save()
        
        if Config.isDebugMode {
            print("💭 Emotional data saved: \(emotionalData.primaryEmotion.displayName) (\(String(format: "%.1f", emotionalData.confidence * 100))% confidence)")
        }
    }
    
    // MARK: - Data Cleanup
    func deleteOldData(olderThan days: Int = 90) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let request: NSFetchRequest<NSFetchRequestResult> = EmotionalDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try container.viewContext.execute(deleteRequest)
            save()
            
            if Config.isDebugMode {
                print("🗑️ Deleted emotional data older than \(days) days")
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to delete old data: \(error)")
            }
        }
    }
    
    func cleanupDuplicateEmotionalData() {
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        
        do {
            let allRecords = try container.viewContext.fetch(request)
            var seenTimestamps: Set<Date> = []
            var duplicatesToDelete: [EmotionalDataEntity] = []
            
            for record in allRecords.sorted(by: { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }) {
                guard let timestamp = record.timestamp else { continue }
                
                // Round to nearest second to handle minor timestamp differences
                let roundedTimestamp = Date(timeIntervalSinceReferenceDate: timestamp.timeIntervalSinceReferenceDate.rounded())
                
                if seenTimestamps.contains(roundedTimestamp) {
                    duplicatesToDelete.append(record)
                } else {
                    seenTimestamps.insert(roundedTimestamp)
                }
            }
            
            // Delete duplicates
            for duplicate in duplicatesToDelete {
                container.viewContext.delete(duplicate)
            }
            
            if !duplicatesToDelete.isEmpty {
                try container.viewContext.save()
                print("🧹 Cleaned up \(duplicatesToDelete.count) duplicate emotional data records")
            }
        } catch {
            print("❌ Failed to cleanup duplicate emotional data: \(error)")
        }
    }

    
    // MARK: - NEW COACHING METHODS (Added for Week 4 features)
    
    // MARK: - Goal Management
    func saveGoal(_ goal: EmotionalGoal, for user: User) {
        let entity = GoalEntity(context: container.viewContext)
        entity.id = goal.id
        entity.title = goal.title
        entity.goalDescription = goal.description
        entity.category = goal.category.rawValue
        entity.targetDate = goal.targetDate
        entity.createdAt = goal.createdAt
        entity.progress = goal.progress
        entity.isCompleted = goal.isCompleted
        entity.completedAt = goal.completedAt
        entity.user = user
        
        // Save milestones
        for milestone in goal.milestones {
            let milestoneEntity = MilestoneEntity(context: container.viewContext)
            milestoneEntity.id = milestone.id
            milestoneEntity.title = milestone.title
            milestoneEntity.milestoneDescription = milestone.description
            milestoneEntity.targetProgress = milestone.targetProgress
            milestoneEntity.isCompleted = milestone.isCompleted
            milestoneEntity.completedAt = milestone.completedAt
            milestoneEntity.goal = entity
        }
        
        save()
        
        if Config.isDebugMode {
            print("🎯 Goal saved: \(goal.title)")
        }
    }
    
    func fetchGoals(for user: User) -> [GoalEntity] {
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GoalEntity.createdAt, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch goals: \(error)")
            }
            return []
        }
    }
    
    func updateGoalProgress(_ goalId: UUID, progress: Double) {
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", goalId as CVarArg)
        request.fetchLimit = 1
        
        do {
            if let goal = try container.viewContext.fetch(request).first {
                goal.progress = progress
                if progress >= 1.0 {
                    goal.isCompleted = true
                    goal.completedAt = Date()
                }
                save()
                
                if Config.isDebugMode {
                    print("📈 Goal progress updated: \(String(format: "%.1f", progress * 100))%")
                }
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to update goal progress: \(error)")
            }
        }
    }
    
    // MARK: - Intervention Management
    func saveInterventionCompletion(_ completion: CompletedIntervention, for user: User) {
        let entity = InterventionCompletionEntity(context: container.viewContext)
        entity.id = completion.id
        entity.interventionId = completion.interventionId
        entity.title = completion.title
        entity.category = completion.category.rawValue
        entity.completedAt = completion.completedAt
        entity.duration = Int32(completion.duration)
        entity.effectiveness = Int16(completion.effectiveness ?? 0)
        entity.notes = completion.notes
        entity.user = user
        
        save()
        
        if Config.isDebugMode {
            print("🧘 Intervention completed: \(completion.title)")
        }
    }
    
    func fetchInterventionCompletions(for user: User, limit: Int = 50) -> [InterventionCompletionEntity] {
        let request: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \InterventionCompletionEntity.completedAt, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch intervention completions: \(error)")
            }
            return []
        }
    }
    
    // MARK: - Coaching Recommendation Management
    func saveCoachingRecommendation(_ recommendation: CoachingRecommendation, for user: User) {
        let entity = CoachingRecommendationEntity(context: container.viewContext)
        entity.id = recommendation.id
        entity.title = recommendation.title
        entity.recommendationDescription = recommendation.description
        entity.category = recommendation.category
        entity.icon = recommendation.icon
        entity.estimatedDuration = recommendation.estimatedDuration
        entity.priority = recommendation.priority.rawValue
        entity.createdAt = recommendation.createdAt
        entity.isCompleted = false
        entity.user = user
        
        save()
        
        if Config.isDebugMode {
            print("💡 Coaching recommendation saved: \(recommendation.title)")
        }
    }
    
    func fetchCoachingRecommendations(for user: User) -> [CoachingRecommendationEntity] {
        let request: NSFetchRequest<CoachingRecommendationEntity> = CoachingRecommendationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CoachingRecommendationEntity.createdAt, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch coaching recommendations: \(error)")
            }
            return []
        }
    }
    
    func markRecommendationCompleted(_ recommendationId: UUID) {
        let request: NSFetchRequest<CoachingRecommendationEntity> = CoachingRecommendationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", recommendationId as CVarArg)
        request.fetchLimit = 1
        
        do {
            if let recommendation = try container.viewContext.fetch(request).first {
                recommendation.isCompleted = true
                recommendation.completedAt = Date()
                save()
                
                if Config.isDebugMode {
                    print("✅ Recommendation marked completed: \(recommendation.title ?? "Unknown")")
                }
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to mark recommendation completed: \(error)")
            }
        }
    }
    
    // MARK: - NEW ELEVENLABS VOICE METHODS (Week 5 features)
    
    // MARK: - Voice Profile Management
    
    func saveVoiceProfile(elevenLabsVoiceId: String, name: String, audioSamplePath: String?, for user: User) {
        // Deactivate existing profiles
        let existingRequest: NSFetchRequest<VoiceProfileEntity> = VoiceProfileEntity.fetchRequest()
        existingRequest.predicate = NSPredicate(format: "user == %@", user)
        
        do {
            let existingProfiles = try container.viewContext.fetch(existingRequest)
            for existingProfile in existingProfiles {
                existingProfile.isActive = false
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to deactivate existing voice profiles: \(error)")
            }
        }
        
        // Create new profile entity
        let entity = VoiceProfileEntity(context: container.viewContext)
        entity.id = UUID()
        entity.elevenLabsVoiceId = elevenLabsVoiceId
        entity.name = name
        entity.createdAt = Date()
        entity.isActive = true
        entity.stability = 0.75
        entity.similarityBoost = 0.75
        entity.style = 0.0
        entity.useSpeakerBoost = true
        entity.audioSamplePath = audioSamplePath
        entity.qualityScore = 0.0
        entity.user = user
        
        save()
        
        if Config.isDebugMode {
            print("🎤 Voice profile saved: \(name)")
        }
    }
    
    func getActiveVoiceProfile(for user: User) -> VoiceProfileEntity? {
        let request: NSFetchRequest<VoiceProfileEntity> = VoiceProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND isActive == YES", user)
        request.fetchLimit = 1
        
        do {
            let entities = try container.viewContext.fetch(request)
            return entities.first
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch active voice profile: \(error)")
            }
            return nil
        }
    }
    
    func getAllVoiceProfiles(for user: User) -> [VoiceProfileEntity] {
        let request: NSFetchRequest<VoiceProfileEntity> = VoiceProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \VoiceProfileEntity.createdAt, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch voice profiles: \(error)")
            }
            return []
        }
    }
    
    func updateVoiceProfileSettings(_ profileId: UUID, stability: Double, similarityBoost: Double, style: Double, useSpeakerBoost: Bool) {
        let request: NSFetchRequest<VoiceProfileEntity> = VoiceProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", profileId as CVarArg)
        request.fetchLimit = 1
        
        do {
            if let profile = try container.viewContext.fetch(request).first {
                profile.stability = stability
                profile.similarityBoost = similarityBoost
                profile.style = style
                profile.useSpeakerBoost = useSpeakerBoost
                save()
                
                if Config.isDebugMode {
                    print("🔧 Voice profile settings updated")
                }
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to update voice profile settings: \(error)")
            }
        }
    }
    
    func deleteVoiceProfile(_ profileId: UUID) {
        let request: NSFetchRequest<VoiceProfileEntity> = VoiceProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", profileId as CVarArg)
        
        do {
            let entities = try container.viewContext.fetch(request)
            for entity in entities {
                container.viewContext.delete(entity)
            }
            save()
            
            if Config.isDebugMode {
                print("🗑️ Voice profile deleted")
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to delete voice profile: \(error)")
            }
        }
    }
    
    // MARK: - Affirmation Management
    func saveAffirmation(text: String, category: String, audioURL: String?, isCustom: Bool, targetEmotion: String?, for user: User) {
        let entity = AffirmationEntity(context: container.viewContext)
        entity.id = UUID()
        entity.text = text
        entity.category = category
        entity.audioURL = audioURL
        entity.createdAt = Date()
        entity.isCustom = isCustom
        entity.effectivenessRating = 0
        entity.playCount = 0
        entity.lastPlayedAt = nil
        entity.isFavorite = false
        entity.duration = 0.0
        entity.targetEmotion = targetEmotion
        entity.user = user
        
        save()
        
        if Config.isDebugMode {
            print("✨ Affirmation saved: \(text.prefix(50))...")
        }
    }
    
    func getAffirmations(for user: User, category: String? = nil) -> [AffirmationEntity] {
        let request: NSFetchRequest<AffirmationEntity> = AffirmationEntity.fetchRequest()
        
        var predicates = [NSPredicate(format: "user == %@", user)]
        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AffirmationEntity.createdAt, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch affirmations: \(error)")
            }
            return []
        }
    }
    
    func getFavoriteAffirmations(for user: User) -> [AffirmationEntity] {
        let request: NSFetchRequest<AffirmationEntity> = AffirmationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND isFavorite == YES", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AffirmationEntity.lastPlayedAt, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch favorite affirmations: \(error)")
            }
            return []
        }
    }
    
    func updateAffirmationPlayCount(_ affirmationId: UUID) {
        let request: NSFetchRequest<AffirmationEntity> = AffirmationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", affirmationId as CVarArg)
        request.fetchLimit = 1
        
        do {
            if let affirmation = try container.viewContext.fetch(request).first {
                affirmation.playCount += 1
                affirmation.lastPlayedAt = Date()
                save()
                
                if Config.isDebugMode {
                    print("▶️ Affirmation play count updated: \(affirmation.playCount)")
                }
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to update affirmation play count: \(error)")
            }
        }
    }
    
    func updateAffirmationRating(_ affirmationId: UUID, rating: Int) {
        let request: NSFetchRequest<AffirmationEntity> = AffirmationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", affirmationId as CVarArg)
        request.fetchLimit = 1
        
        do {
            if let affirmation = try container.viewContext.fetch(request).first {
                affirmation.effectivenessRating = Int16(rating)
                save()
                
                if Config.isDebugMode {
                    print("⭐ Affirmation rating updated: \(rating)/5")
                }
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to update affirmation rating: \(error)")
            }
        }
    }
    
    func toggleAffirmationFavorite(_ affirmationId: UUID) {
        let request: NSFetchRequest<AffirmationEntity> = AffirmationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", affirmationId as CVarArg)
        request.fetchLimit = 1
        
        do {
            if let affirmation = try container.viewContext.fetch(request).first {
                affirmation.isFavorite.toggle()
                save()
                
                if Config.isDebugMode {
                    print("❤️ Affirmation favorite toggled: \(affirmation.isFavorite)")
                }
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to toggle affirmation favorite: \(error)")
            }
        }
    }
    
    func deleteAffirmation(_ affirmationId: UUID) {
        let request: NSFetchRequest<AffirmationEntity> = AffirmationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", affirmationId as CVarArg)
        
        do {
            let entities = try container.viewContext.fetch(request)
            for entity in entities {
                container.viewContext.delete(entity)
            }
            save()
            
            if Config.isDebugMode {
                print("🗑️ Affirmation deleted")
            }
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to delete affirmation: \(error)")
            }
        }
    }
    
    // MARK: - Enhanced Intervention Completion (Voice-Guided Support)
    func saveVoiceGuidedInterventionCompletion(
        interventionType: String,
        interventionTitle: String,
        duration: Double,
        effectivenessRating: Int,
        emotionBefore: String?,
        emotionAfter: String?,
        stepsCompleted: Int,
        totalSteps: Int,
        notes: String?,
        for user: User
    ) {
        let entity = InterventionCompletionEntity(context: container.viewContext)
        entity.id = UUID()
        entity.interventionType = interventionType
        entity.interventionTitle = interventionTitle
        entity.completedAt = Date()
        entity.duration = Int32(duration)
        entity.effectivenessRating = Int16(effectivenessRating)
        entity.emotionBefore = emotionBefore
        entity.emotionAfter = emotionAfter
        entity.wasVoiceGuided = true
        entity.stepsCompleted = Int16(stepsCompleted)
        entity.totalSteps = Int16(totalSteps)
        entity.notes = notes
        entity.user = user
        
        save()
        
        if Config.isDebugMode {
            print("🎤 Voice-guided intervention completed: \(interventionTitle)")
        }
    }
    
    func getVoiceGuidedInterventionCompletions(for user: User, limit: Int = 20) -> [InterventionCompletionEntity] {
        let request: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND wasVoiceGuided == YES", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \InterventionCompletionEntity.completedAt, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch voice-guided intervention completions: \(error)")
            }
            return []
        }
    }
    
    // MARK: - Coaching Session Management (Voice-Enhanced)
    func saveCoachingSession(
        sessionType: String,
        duration: Double,
        completionRate: Double,
        effectivenessRating: Int,
        emotionBefore: String?,
        emotionAfter: String?,
        interventionsCompleted: Int,
        wasVoiceGuided: Bool,
        notes: String?,
        for user: User
    ) {
        let entity = CoachingSessionEntity(context: container.viewContext)
        entity.id = UUID()
        entity.sessionType = sessionType
        entity.startTime = Date().addingTimeInterval(-duration)
        entity.endTime = Date()
        entity.duration = duration
        entity.completionRate = completionRate
        entity.effectivenessRating = Int16(effectivenessRating)
        entity.emotionBefore = emotionBefore
        entity.emotionAfter = emotionAfter
        entity.interventionsCompleted = Int16(interventionsCompleted)
        entity.wasVoiceGuided = wasVoiceGuided
        entity.notes = notes
        entity.user = user
        
        save()
        
        if Config.isDebugMode {
            print("🎯 Coaching session saved: \(sessionType) (\(wasVoiceGuided ? "Voice-Guided" : "Standard"))")
        }
    }
    
    func getCoachingSessions(for user: User, voiceGuidedOnly: Bool = false, limit: Int = 20) -> [CoachingSessionEntity] {
        let request: NSFetchRequest<CoachingSessionEntity> = CoachingSessionEntity.fetchRequest()
        
        var predicates = [NSPredicate(format: "user == %@", user)]
        if voiceGuidedOnly {
            predicates.append(NSPredicate(format: "wasVoiceGuided == YES"))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CoachingSessionEntity.endTime, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            if Config.isDebugMode {
                print("❌ Failed to fetch coaching sessions: \(error)")
            }
            return []
        }
    }
    
}

// MARK: - Entity Conversion Extensions (Enhanced)
extension EmotionalDataEntity {
    func toEmotionalData() -> EmotionalData? {
        guard let id = self.id,
              let emotionTypeString = self.primaryEmotion,
              let emotionType = EmotionType(rawValue: emotionTypeString),
              let timestamp = self.timestamp else {
            return nil
        }
        
        // Decode voice features if available
        var voiceFeatures: VoiceFeatures?
        if let voiceFeaturesData = self.voiceFeaturesData {
            do {
                let decoder = JSONDecoder()
                voiceFeatures = try decoder.decode(VoiceFeatures.self, from: voiceFeaturesData)
            } catch {
                if Config.isDebugMode {
                    print("❌ Failed to decode voice features: \(error)")
                }
            }
        }
        
        return EmotionalData(
            timestamp: timestamp, primaryEmotion: emotionType,
            confidence: self.confidence,
            intensity: self.intensity,
            voiceFeatures: voiceFeatures
        )
    }
}

extension GoalEntity {
    func toEmotionalGoal() -> EmotionalGoal? {
        guard let id = self.id,
              let title = self.title,
              let description = self.goalDescription,
              let categoryString = self.category,
              let category = GoalCategory(rawValue: categoryString),
              let createdAt = self.createdAt else {
            return nil
        }
        
        let milestones = (self.milestones?.allObjects as? [MilestoneEntity])?.compactMap { $0.toGoalMilestone() } ?? []
        
        return EmotionalGoal(
            id: id,
            title: title,
            description: description,
            category: category,
            targetDate: self.targetDate,
            createdAt: createdAt,
            progress: self.progress,
            isCompleted: self.isCompleted,
            completedAt: self.completedAt,
            milestones: milestones
        )
    }
}

extension MilestoneEntity {
    func toGoalMilestone() -> GoalMilestone? {
        guard let id = self.id,
              let title = self.title,
              let description = self.milestoneDescription else {
            return nil
        }
        
        return GoalMilestone(
            title: title,
            description: description,
            targetProgress: self.targetProgress,
            isCompleted: self.isCompleted,
            completedAt: self.completedAt
        )
    }
}

extension InterventionCompletionEntity {
    func toCompletedIntervention() -> CompletedIntervention? {
        guard let id = self.id,
              let interventionId = self.interventionId,
              let title = self.title,
              let categoryString = self.category,
              let category = InterventionCategory(rawValue: categoryString),
              let completedAt = self.completedAt else {
            return nil
        }
        
        return CompletedIntervention(
            id: id,
            interventionId: interventionId,
            title: title,
            category: category,
            completedAt: completedAt,
            duration: Int(self.duration),
            effectiveness: self.effectiveness > 0 ? Int(self.effectiveness) : nil,
            notes: self.notes
        )
    }
}

