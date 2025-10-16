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
                    storeDescription.shouldMigrateStoreAutomatically = true
                    storeDescription.shouldInferMappingModelAutomatically = true
                    storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                    storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                    
                    // CloudKit configuration
                    //storeDescription.setOption(true as NSNumber, forKey: NSPersistentCloudKitContainerOptionsKey)
                }
            }
            // Ensure migration is enabled even if cloudkit is disabled.
            if !Config.CoreData.enableCloudKit {
                container.persistentStoreDescriptions.forEach { storeDescription in
                    storeDescription.shouldMigrateStoreAutomatically = true
                    storeDescription.shouldInferMappingModelAutomatically = true
                }
            }
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let _ = error as NSError? {
                // Handle different types of Core Data errors
                
                // In production, you might want to handle this more gracefully
                // For now, we'll crash in debug but handle gracefully in production
//                if Config.isDebugMode {
//                    fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
//                } else {
//                    // Log error to crash reporting service
//
//                }
            } else {

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

            }
        }
    }
    
    // MARK: - Save Context
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()

            } catch {
                let _ = error as NSError

                
                // In production, handle this more gracefully
//                if Config.isDebugMode {
//                    fatalError("Unresolved save error \(nsError), \(nsError.userInfo)")
//                } else {
//                    
//                }
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
        
    }
    
    func incrementDailyUsage(for user: User) {
        user.dailyCheckInsUsed += 1
        user.lastCheckInDate = Date()
        save()
        
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

            }
        }
        updateUserStatsOnCheckIn(user, checkInDate: emotionalData.timestamp)
        updateWeeklyCheckInsCount(for: user)
        
        save()
    
    }
    
    private func updateUserStatsOnCheckIn(_ user: User, checkInDate: Date) {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: checkInDate)
            let last = user.lastCheckInDate.map { calendar.startOfDay(for: $0) }
            
            if let last = last {
                if calendar.isDate(last, inSameDayAs: today) {
                    // Same day: keep streak unchanged
                } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), calendar.isDate(last, inSameDayAs: yesterday) {
                    user.currentStreak = Int32(max(Int(user.currentStreak) + 1, 1))
                } else {
                    user.currentStreak = 1
                }
            } else {
                user.currentStreak = 1
            }
            
            user.totalCheckIns = Int32(max(Int(user.totalCheckIns) + 1, 1))
            user.lastCheckInDate = checkInDate
        }
        
        // MARK: - Derived Stats Recalculation (idempotent)
        func recalculateUserStats(for user: User) {
            let context = container.viewContext
            let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
            request.predicate = NSPredicate(format: "user == %@", user)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: false)]
            
            do {
                let emotionalData = try context.fetch(request)
                user.totalCheckIns = Int32(emotionalData.count)
                user.lastCheckInDate = emotionalData.first?.timestamp
                user.currentStreak = Int32(calculateCurrentStreak(from: emotionalData))
                updateWeeklyCheckInsCount(for: user)
                save()
            } catch {

            }
        }
        
        func updateWeeklyCheckInsCount(for user: User) {
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            
            let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
            request.predicate = NSPredicate(format: "user == %@ AND timestamp >= %@", user, weekAgo as NSDate)
            
            do {
                let weeklyData = try container.viewContext.fetch(request)
                user.weeklyCheckInsCount = Int32(weeklyData.count)
                
            } catch {

            }
        }
    
    private func calculateCurrentStreak(from emotionalData: [EmotionalDataEntity]) -> Int {
        let calendar = Calendar.current
        // Build a set of unique check-in days
        let days: Set<Date> = Set(emotionalData.compactMap { entity in
            guard let timestamp = entity.timestamp else { return nil }
            return calendar.startOfDay(for: timestamp)
        })
        // No data -> no streak
        guard let mostRecentDay = days.max() else { return 0 }
        // Count consecutive days ending at the most recent check-in day
        var streak = 0
        var cursor = mostRecentDay
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
    
    // MARK: - Intervention Streak Backfill
    func backfillInterventionStreaksIfNeeded() {
        let flagKey = "intervention_streak_backfill_v1"
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: flagKey) { return }
        let context = container.viewContext
        let cal = Calendar.current
        do {
            let fetch: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
            let all = try context.fetch(fetch)
            guard !all.isEmpty else { defaults.set(true, forKey: flagKey); return }
            // Group by interventionTitle (fallback to title)
            var titleToDates: [String: [Date]] = [:]
            for item in all {
                let title = item.interventionTitle ?? item.title ?? ""
                guard !title.isEmpty, let d = item.completedAt else { continue }
                titleToDates[title, default: []].append(d)
            }
            let now = Date()
            for (title, dates) in titleToDates {
                // Compute streak from dates
                let days: Set<Date> = Set(dates.map { cal.startOfDay(for: $0) })
                guard let mostRecent = days.max() else { continue }
                var cursor = cal.startOfDay(for: now)
                if !days.contains(cursor) { cursor = mostRecent }
                var streak = 0
                while days.contains(cursor) {
                    streak += 1
                    guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
                    cursor = prev
                }
                // Upsert InterventionStreakEntity
                let req: NSFetchRequest<InterventionStreakEntity> = InterventionStreakEntity.fetchRequest()
                req.predicate = NSPredicate(format: "interventionTitle == %@", title)
                req.fetchLimit = 1
                let existing = try context.fetch(req).first
                let record = existing ?? InterventionStreakEntity(context: context)
                if existing == nil { record.interventionTitle = title }
                record.currentStreak = Int32(streak)
                record.lastActiveDay = mostRecent
                record.updatedAt = Date()
            }
            try context.save()
            defaults.set(true, forKey: flagKey)

        } catch {
     
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
            
        } catch {

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
            
            }
        } catch {
           
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
        
    }
    
    func fetchGoals(for user: User) -> [GoalEntity] {
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GoalEntity.createdAt, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
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
                
            }
        } catch {

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
        
    }
    
    func fetchInterventionCompletions(for user: User, limit: Int = 50) -> [InterventionCompletionEntity] {
        let request: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \InterventionCompletionEntity.completedAt, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try container.viewContext.fetch(request)
        } catch {

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
        
    }
    
    func fetchCoachingRecommendations(for user: User) -> [CoachingRecommendationEntity] {
        let request: NSFetchRequest<CoachingRecommendationEntity> = CoachingRecommendationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CoachingRecommendationEntity.createdAt, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {

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
                
            }
        } catch {

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
        
    }
    
    func getActiveVoiceProfile(for user: User) -> VoiceProfileEntity? {
        let request: NSFetchRequest<VoiceProfileEntity> = VoiceProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND isActive == YES", user)
        request.fetchLimit = 1
        
        do {
            let entities = try container.viewContext.fetch(request)
            return entities.first
        } catch {
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
                
            }
        } catch {

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
            
        } catch {

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
                
            }
        } catch {

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
                
            }
        } catch {

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
                
            }
        } catch {

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
            

        } catch {

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
        
    }
    
    func getVoiceGuidedInterventionCompletions(for user: User, limit: Int = 20) -> [InterventionCompletionEntity] {
        let request: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND wasVoiceGuided == YES", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \InterventionCompletionEntity.completedAt, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
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

