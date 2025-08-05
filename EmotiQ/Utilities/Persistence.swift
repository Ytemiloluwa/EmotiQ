//
//  Persistence.swift
//  EmotiQ
//
//  Created by Temiloluwa on 31-07-2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // TODO: Add sample data for previews once Core Data is properly set up
        // let sampleUser = User(context: viewContext)
        // sampleUser.id = UUID()
        // sampleUser.createdAt = Date()
        // sampleUser.subscriptionStatus = "free"
        // sampleUser.dailyCheckInsUsed = 1
        
        // Add sample emotional data
        // let sampleEmotionalData = EmotionalDataEntity(context: viewContext)
        // sampleEmotionalData.id = UUID()
        // sampleEmotionalData.timestamp = Date()
        // sampleEmotionalData.primaryEmotion = "happy"
        // sampleEmotionalData.confidence = 0.85
        // sampleEmotionalData.intensity = 0.7
        // sampleEmotionalData.user = sampleUser
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "EmotiQ")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable CloudKit sync
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

