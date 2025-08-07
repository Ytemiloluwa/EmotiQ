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
        let viewContext = result.container.viewContext
        
        // Add sample data for previews
        let sampleUser = User(context: viewContext)
        sampleUser.id = UUID()
        sampleUser.createdAt = Date()
        sampleUser.subscriptionStatus = SubscriptionStatus.free.rawValue
        sampleUser.dailyCheckInsUsed = 1
        sampleUser.lastCheckInDate = Date()
        
        // Add sample emotional data
        let sampleEmotion = EmotionalDataEntity(context: viewContext)
        sampleEmotion.id = UUID()
        sampleEmotion.timestamp = Date()
        sampleEmotion.primaryEmotion = "joy"
        sampleEmotion.confidence = 0.85
        sampleEmotion.intensity = 0.7
        sampleEmotion.user = sampleUser
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
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
                    // CloudKit is automatically enabled with NSPersistentCloudKitContainer
                }
            }
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Handle different types of Core Data errors
                if Config.isDebugMode {
                    print(" Core Data Error: \(error)")
                    print(" Description: \(error.localizedDescription)")
                    print(" User Info: \(error.userInfo)")
                }
                
                if Config.isDebugMode {
                    fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
                } else {
                    // Log error to crash reporting service
                    print("Core Data failed to load: \(error.localizedDescription)")
                }
            } else {
                if Config.isDebugMode {
                    print("Core Data loaded successfully")
                    if Config.CoreData.enableCloudKit {
                        print("CloudKit sync enabled")
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
                    print(" Remote Core Data changes detected")
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
                print("Failed to fetch current user: \(error)")
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
            print(" Daily usage incremented: \(user.dailyCheckInsUsed)/\(Config.Subscription.freeDailyLimit)")
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
            print("Emotional data saved: \(emotionalData.primaryEmotion.displayName) (\(String(format: "%.1f", emotionalData.confidence * 100))% confidence)")
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
                print(" Deleted emotional data older than \(days) days")
            }
        } catch {
            if Config.isDebugMode {
                print(" Failed to delete old data: \(error)")
            }
        }
    }
}

