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
                        print(" CloudKit sync enabled")
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
            return existingUser
        }
        
        let newUser = User(context: container.viewContext)
        newUser.id = UUID()
        newUser.createdAt = Date()
        newUser.subscriptionStatus = SubscriptionStatus.free.rawValue
        newUser.dailyCheckInsUsed = 0
        newUser.lastCheckInDate = nil
        
        save()
        
        if Config.isDebugMode {
            print("👤 New user created with ID: \(newUser.id?.uuidString ?? "unknown")")
        }
        
        return newUser
    }
    
    // MARK: - Daily Usage Management
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

