//
//  CoachingService.swift
//  EmotiQ
//
//  Created by Temiloluwa on 18-08-2025.
//

import Foundation
import Combine
import CoreData

// MARK: - Coaching Service
@MainActor
class CoachingService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CoachingService()
    
    // MARK: - Published Properties
    @Published var currentRecommendations: [CoachingRecommendation] = []
    @Published var userGoals: [EmotionalGoal] = []
    @Published var completedInterventions: [CompletedIntervention] = []
    @Published var progressMetrics: ProgressMetrics = ProgressMetrics()
    
    // MARK: - Private Properties
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        loadUserData()
        setupDataObservers()
    }
    
    // MARK: - Public Methods
    
    /// Generates personalized coaching recommendations based on recent emotions
    func generateRecommendations(for emotions: [EmotionAnalysisResult]) async -> [CoachingRecommendation] {
        
        
        // Analyze emotion patterns
        let emotionPattern = analyzeEmotionPattern(emotions)
        
        // Generate recommendations based on patterns
        var recommendations: [CoachingRecommendation] = []
        
        // Primary emotion-based recommendations
        if let primaryEmotion = emotionPattern.dominantEmotion {
            recommendations.append(contentsOf: getRecommendationsFor(emotion: primaryEmotion))
        }
        
        // Stress level recommendations
        if emotionPattern.stressLevel > 0.7 {
            recommendations.append(contentsOf: getStressManagementRecommendations())
        }
        
        // Mood stability recommendations
        if emotionPattern.moodVariability > 0.6 {
            recommendations.append(contentsOf: getMoodStabilityRecommendations())
        }
        
        // Energy level recommendations
        if emotionPattern.energyLevel < 0.4 {
            recommendations.append(contentsOf: getEnergyBoostRecommendations())
        }
        
        // Limit to top 5 recommendations
        let finalRecommendations = Array(recommendations.prefix(5))
        
        // Update published property
        currentRecommendations = finalRecommendations
        
        return finalRecommendations
    }
    
    /// Creates a new emotional goal for the user
    func createGoal(_ goal: EmotionalGoal) async {
       
        
        // Save to Core Data
        let context = persistenceController.container.viewContext
        
        // Get current user
        guard let currentUser = persistenceController.getCurrentUser() else {
         
            return
        }
        
        let goalEntity = GoalEntity(context: context)
        goalEntity.id = goal.id
        goalEntity.title = goal.title
        goalEntity.goalDescription = goal.description
        goalEntity.category = goal.category.rawValue
        goalEntity.targetDate = goal.targetDate
        goalEntity.isCompleted = goal.isCompleted
        goalEntity.createdAt = goal.createdAt
        goalEntity.progress = goal.progress
        goalEntity.isTemplate = goal.isTemplate
        goalEntity.user = currentUser // Set the user relationship
        
        // Create and save milestone entities
        for milestone in goal.milestones {
            let milestoneEntity = MilestoneEntity(context: context)
            milestoneEntity.id = milestone.id
            milestoneEntity.title = milestone.title
            milestoneEntity.milestoneDescription = milestone.description
            milestoneEntity.targetProgress = milestone.targetProgress
            milestoneEntity.isCompleted = milestone.isCompleted
            milestoneEntity.completedAt = milestone.completedAt
            milestoneEntity.goal = goalEntity // Set the relationship to the goal
        }
        
        do {
            try context.save()
            userGoals.append(goal)
           
        } catch {
           
        }
    }
    
    /// Deletes a goal
    func deleteGoal(_ goalId: UUID) async {
        
        // Remove from memory
        userGoals.removeAll { $0.id == goalId }
        
        // Remove from Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", goalId as CVarArg)
        
        do {
            let goals = try context.fetch(request)
            for goalEntity in goals {
                context.delete(goalEntity)
            }
            try context.save()
            
        } catch {
           
        }
    }
    
    /// Marks a milestone as complete
    func markMilestoneComplete(_ goalId: UUID, milestoneId: UUID) async {
      
        
        // Update in memory
        if let goalIndex = userGoals.firstIndex(where: { $0.id == goalId }),
           let milestoneIndex = userGoals[goalIndex].milestones.firstIndex(where: { $0.id == milestoneId }) {
            userGoals[goalIndex].milestones[milestoneIndex].isCompleted = true
            userGoals[goalIndex].milestones[milestoneIndex].completedAt = Date()
        }
        
        // Update in Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<MilestoneEntity> = MilestoneEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", milestoneId as CVarArg)
        
        do {
            let milestones = try context.fetch(request)
            if let milestoneEntity = milestones.first {
                milestoneEntity.isCompleted = true
                milestoneEntity.completedAt = Date()
                try context.save()
                
                
                // Post notification for milestone completion
                NotificationCenter.default.post(name: .milestoneCompleted, object: milestoneEntity)
            }
        } catch {
         
        }
    }
    
    /// Adds a new milestone to a goal
    func addMilestone(_ goalId: UUID, title: String, description: String, targetProgress: Double) async {
    
        
        let newMilestone = GoalMilestone(
            title: title,
            description: description,
            targetProgress: targetProgress
        )
        
        // Add to memory
        if let goalIndex = userGoals.firstIndex(where: { $0.id == goalId }) {
            userGoals[goalIndex].milestones.append(newMilestone)
        }
        
        // Add to Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", goalId as CVarArg)
        
        do {
            let goals = try context.fetch(request)
            if let goalEntity = goals.first {
                let milestoneEntity = MilestoneEntity(context: context)
                milestoneEntity.id = newMilestone.id
                milestoneEntity.title = newMilestone.title
                milestoneEntity.milestoneDescription = newMilestone.description
                milestoneEntity.targetProgress = newMilestone.targetProgress
                milestoneEntity.isCompleted = newMilestone.isCompleted
                milestoneEntity.completedAt = newMilestone.completedAt
                milestoneEntity.goal = goalEntity
                
                try context.save()
            
            }
        } catch {
         
        }
    }
    
    /// Updates progress for a specific goal
    func updateGoalProgress(_ goalId: UUID, progress: Double) async {
     
        
        // Update in memory
        if let index = userGoals.firstIndex(where: { $0.id == goalId }) {
            userGoals[index].progress = progress
            
            // Check if goal is completed
            if progress >= 1.0 {
                userGoals[index].isCompleted = true
                userGoals[index].completedAt = Date()
            }
        }
        
        // Update in Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", goalId as CVarArg)
        
        do {
            let goals = try context.fetch(request)
            if let goalEntity = goals.first {
                goalEntity.progress = progress
                goalEntity.isCompleted = progress >= 1.0
                if progress >= 1.0 {
                    goalEntity.completedAt = Date()
                    
                    // Post notification when goal is completed
                    NotificationCenter.default.post(name: .goalCompleted, object: goalEntity)
                }
                try context.save()
                
                // Update progress metrics
                updateProgressMetrics()
            }
        } catch {
         
        }
    }
    
    /// Records completion of an intervention
    func recordInterventionCompletion(_ intervention: QuickIntervention) async {
        
        
        let completion = CompletedIntervention(
            id: UUID(),
            interventionId: intervention.id,
            title: intervention.title,
            category: intervention.category,
            completedAt: Date(),
            duration: intervention.estimatedDuration,
            effectiveness: nil // Can be rated later
        )
        
        completedInterventions.append(completion)
        
        // Save to Core Data
        let context = persistenceController.container.viewContext
        let entity = InterventionCompletionEntity(context: context)
        entity.id = completion.id
        entity.interventionId = completion.interventionId
        entity.title = completion.title
        entity.category = completion.category.rawValue
        entity.completedAt = completion.completedAt
        entity.duration = Int32(completion.duration)
        
        do {
            try context.save()
            updateProgressMetrics()
        } catch {
           
        }
    }
    
    /// Gets personalized greeting based on time and recent emotions
    func getPersonalizedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        
        switch hour {
        case 5..<12:
            timeGreeting = "Good morning"
        case 12..<17:
            timeGreeting = "Good afternoon"
        case 17..<22:
            timeGreeting = "Good evening"
        default:
            timeGreeting = "Hello"
        }
        
        // Add personalization based on recent emotions
        if let lastEmotion = getRecentEmotions().first {
            switch lastEmotion.primaryEmotion {
            case .joy:
                return "\(timeGreeting)! You're radiating positive energy today ✨"
            case .sadness:
                return "\(timeGreeting). I'm here to support you through this 💙"
            case .anger:
                return "\(timeGreeting). Let's work on finding your inner calm 🧘‍♀️"
            case .fear:
                return "\(timeGreeting). You're braver than you believe 💪"
            case .surprise:
                return "\(timeGreeting)! Life is full of wonderful surprises 🌟"
            case .disgust:
                return "\(timeGreeting). Let's focus on what brings you joy 🌸"
            case .neutral:
                return "\(timeGreeting). Ready to explore your emotional landscape? 🗺️"
            }
        }
        
        return "\(timeGreeting)! Ready for some emotional growth today? 🌱"
    }
    
    /// Gets motivational message based on user progress
    func getMotivationalMessage() -> String {
        let completionRate = calculateWeeklyCompletionRate()
        
        if completionRate >= 0.8 {
            return "You're crushing your emotional wellness goals! Keep up the amazing work! 🏆"
        } else if completionRate >= 0.6 {
            return "Great progress this week! You're building strong emotional habits 📈"
        } else if completionRate >= 0.4 {
            return "Every small step counts. You're on the right path to emotional growth 🌱"
        } else {
            return "Today is a fresh start. Let's take one step towards emotional wellness 🌅"
        }
    }
    
    // MARK: - Private Methods
    
    private func loadUserData() {
        loadGoals()
        loadCompletedInterventions()
        updateProgressMetrics()
    }
    
    private func setupDataObservers() {
        // Observe emotion analysis results to generate new recommendations
        NotificationCenter.default.publisher(for: .emotionAnalysisCompleted)
            .sink { [weak self] notification in
                if let result = notification.object as? EmotionAnalysisResult {
                    Task {
                        await self?.generateRecommendations(for: [result])
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func loadGoals() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GoalEntity.createdAt, ascending: false)]
        
        do {
            let goalEntities = try context.fetch(request)
            
            userGoals = goalEntities.compactMap { entity -> EmotionalGoal? in
                guard let id = entity.id,
                      let title = entity.title,
                      let description = entity.goalDescription,
                      let categoryString = entity.category,
                      let category = GoalCategory(rawValue: categoryString),
                      let createdAt = entity.createdAt else {
                    return nil
                }
                
                // Load milestones for this goal
                let milestoneEntities = (entity.milestones?.allObjects as? [MilestoneEntity]) ?? []
                
                let milestones = milestoneEntities.compactMap { milestoneEntity -> GoalMilestone? in
                    guard let milestoneId = milestoneEntity.id,
                          let milestoneTitle = milestoneEntity.title else {
                        return nil
                    }
                    
                    return GoalMilestone(
                        id: milestoneId,
                        title: milestoneTitle,
                        description: milestoneEntity.milestoneDescription ?? "",
                        targetProgress: milestoneEntity.targetProgress,
                        isCompleted: milestoneEntity.isCompleted,
                        completedAt: milestoneEntity.completedAt
                    )
                }
                
                return EmotionalGoal(
                    id: id,
                    title: title,
                    description: description,
                    category: category,
                    targetDate: entity.targetDate,
                    createdAt: createdAt,
                    progress: entity.progress,
                    isCompleted: entity.isCompleted,
                    completedAt: entity.completedAt,
                    milestones: milestones, isTemplate: entity.isTemplate
                )
            }
        } catch {
            
        }
    }
    
    private func loadCompletedInterventions() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<InterventionCompletionEntity> = InterventionCompletionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \InterventionCompletionEntity.completedAt, ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            completedInterventions = entities.compactMap { entity in
                guard let id = entity.id,
                      let interventionId = entity.interventionId,
                      let title = entity.title,
                      let categoryString = entity.category,
                      let category = InterventionCategory(rawValue: categoryString),
                      let completedAt = entity.completedAt else {
                    return nil
                }
                
                return CompletedIntervention(
                    id: id,
                    interventionId: interventionId,
                    title: title,
                    category: category,
                    completedAt: completedAt,
                    duration: Int(entity.duration),
                    effectiveness: nil
                )
            }
        } catch {
           
        }
    }
    
    private func analyzeEmotionPattern(_ emotions: [EmotionAnalysisResult]) -> EmotionPattern {
        guard !emotions.isEmpty else {
            return EmotionPattern()
        }
        
        // Calculate dominant emotion
        let emotionCounts = Dictionary(grouping: emotions, by: { $0.primaryEmotion })
            .mapValues { $0.count }
        let dominantEmotion = emotionCounts.max(by: { $0.value < $1.value })?.key
        
        // Calculate stress level (based on negative emotions)
        let negativeEmotions: Set<EmotionCategory?> = [.anger, .fear, .sadness, .disgust]
        let negativeCount = emotions.filter { negativeEmotions.contains($0.primaryEmotion) }.count
        let stressLevel = Double(negativeCount) / Double(emotions.count)
        
        // Calculate mood variability
        let uniqueEmotions = Set(emotions.map { $0.primaryEmotion }).count
        let moodVariability = Double(uniqueEmotions) / 7.0 // 7 total emotion types
        
        // Calculate energy level (based on positive emotions and confidence)
        let positiveEmotions: Set<EmotionCategory?> = [.joy, .surprise]
        let positiveCount = emotions.filter { positiveEmotions.contains($0.primaryEmotion) }.count
        let avgConfidence = emotions.map { $0.confidence }.reduce(0, +) / Double(emotions.count)
        let energyLevel = (Double(positiveCount) / Double(emotions.count) + avgConfidence) / 2.0
        
        return EmotionPattern(
            dominantEmotion: EmotionType(rawValue: dominantEmotion?.rawValue ?? ""),
            stressLevel: stressLevel,
            moodVariability: moodVariability,
            energyLevel: energyLevel
        )
    }
    
    private func getRecommendationsFor(emotion: EmotionType) -> [CoachingRecommendation] {
        switch emotion {
        case .joy:
            return [
                CoachingRecommendation(
                    title: "Amplify Your Joy",
                    description: "Practice gratitude to extend this positive feeling. Write down 3 things you're grateful for today.",
                    category: "Positive Psychology",
                    icon: "heart.fill",
                    color: .yellow,
                    estimatedDuration: "5 minutes",
                    priority: .medium
                )
            ]
            
        case .sadness:
            return [
                CoachingRecommendation(
                    title: "Gentle Self-Compassion",
                    description: "It's okay to feel sad. Practice self-compassion with a loving-kindness meditation.",
                    category: "Emotional Support",
                    icon: "heart.circle",
                    color: .blue,
                    estimatedDuration: "10 minutes",
                    priority: .high
                ),
                CoachingRecommendation(
                    title: "Connect with Others",
                    description: "Reach out to a trusted friend or family member. Social connection can help lift your spirits.",
                    category: "Social Support",
                    icon: "person.2.fill",
                    color: .purple,
                    estimatedDuration: "15 minutes",
                    priority: .medium
                )
            ]
            
        case .anger:
            return [
                CoachingRecommendation(
                    title: "Cool Down Breathing",
                    description: "Use the 4-7-8 breathing technique to calm your nervous system and reduce anger intensity.",
                    category: "Anger Management",
                    icon: "lungs.fill",
                    color: .red,
                    estimatedDuration: "5 minutes",
                    priority: .high
                ),
                CoachingRecommendation(
                    title: "Physical Release",
                    description: "Channel your anger energy into physical activity. Try a quick walk or some jumping jacks.",
                    category: "Physical Wellness",
                    icon: "figure.walk",
                    color: .orange,
                    estimatedDuration: "10 minutes",
                    priority: .medium
                )
            ]
            
        case .fear:
            return [
                CoachingRecommendation(
                    title: "Grounding Exercise",
                    description: "Use the 5-4-3-2-1 technique: Notice 5 things you see, 4 you hear, 3 you touch, 2 you smell, 1 you taste.",
                    category: "Anxiety Management",
                    icon: "leaf.fill",
                    color: .green,
                    estimatedDuration: "5 minutes",
                    priority: .high
                ),
                CoachingRecommendation(
                    title: "Courage Building",
                    description: "Remind yourself of past challenges you've overcome. You're stronger than you think.",
                    category: "Confidence Building",
                    icon: "shield.fill",
                    color: .blue,
                    estimatedDuration: "10 minutes",
                    priority: .medium
                )
            ]
            
        case .surprise:
            return [
                CoachingRecommendation(
                    title: "Embrace the Unexpected",
                    description: "Reflect on this surprise. What can you learn from unexpected moments?",
                    category: "Mindfulness",
                    icon: "sparkles",
                    color: .orange,
                    estimatedDuration: "5 minutes",
                    priority: .low
                )
            ]
            
        case .disgust:
            return [
                CoachingRecommendation(
                    title: "Shift Your Focus",
                    description: "When feeling disgusted, redirect attention to something beautiful or meaningful to you.",
                    category: "Cognitive Reframing",
                    icon: "arrow.triangle.2.circlepath",
                    color: .green,
                    estimatedDuration: "5 minutes",
                    priority: .medium
                )
            ]
            
        case .neutral:
            return [
                CoachingRecommendation(
                    title: "Emotional Check-In",
                    description: "Take a moment to explore what you're feeling beneath the surface. Sometimes neutral is a mask.",
                    category: "Self-Awareness",
                    icon: "magnifyingglass",
                    color: .gray,
                    estimatedDuration: "10 minutes",
                    priority: .medium
                )
            ]
        }
    }
    
    private func getStressManagementRecommendations() -> [CoachingRecommendation] {
        return [
            CoachingRecommendation(
                title: "Progressive Muscle Relaxation",
                description: "Systematically tense and release muscle groups to reduce physical stress and tension.",
                category: "Stress Management",
                icon: "figure.mind.and.body",
                color: .purple,
                estimatedDuration: "15 minutes",
                priority: .high
            ),
            CoachingRecommendation(
                title: "Stress Audit",
                description: "Identify your top 3 stress triggers and brainstorm one coping strategy for each.",
                category: "Self-Awareness",
                icon: "list.clipboard",
                color: .blue,
                estimatedDuration: "10 minutes",
                priority: .medium
            )
        ]
    }
    
    private func getMoodStabilityRecommendations() -> [CoachingRecommendation] {
        return [
            CoachingRecommendation(
                title: "Mood Tracking",
                description: "Start tracking your mood patterns to identify triggers and create more emotional stability.",
                category: "Self-Monitoring",
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                estimatedDuration: "5 minutes",
                priority: .medium
            )
        ]
    }
    
    private func getEnergyBoostRecommendations() -> [CoachingRecommendation] {
        return [
            CoachingRecommendation(
                title: "Energy Boost Meditation",
                description: "A short energizing meditation to help you feel more alert and motivated.",
                category: "Energy Management",
                icon: "bolt.fill",
                color: .yellow,
                estimatedDuration: "8 minutes",
                priority: .medium
            )
        ]
    }
    
    private func getRecentEmotions() -> [EmotionAnalysisResult] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<EmotionalDataEntity> = EmotionalDataEntity.fetchRequest()
        
        // Get emotions from the last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "timestamp >= %@", thirtyDaysAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EmotionalDataEntity.timestamp, ascending: false)]
        
        do {
            let emotionEntities = try context.fetch(request)
            return emotionEntities
                .filter { entity in
                    guard let emotionType = EmotionType(rawValue: entity.primaryEmotion ?? ""),
                          let timestamp = entity.timestamp else {
                        return false
                    }
                    return true
                }
                .map { entity in
                    let emotionType = EmotionType(rawValue: entity.primaryEmotion ?? "")!
                    let timestamp = entity.timestamp!
                    
                    // Convert to EmotionCategory (since EmotionAnalysisResult uses EmotionCategory)
                    let emotionCategory = EmotionCategory(rawValue: emotionType.rawValue) ?? .neutral
                    
                    return EmotionAnalysisResult(
                        timestamp: timestamp,
                        primaryEmotion: emotionCategory,
                        subEmotion: .contentment, // Default sub-emotion
                        intensity: .medium, // Default intensity
                        confidence: entity.confidence,
                        emotionScores: [emotionCategory: entity.confidence],
                        subEmotionScores: [:],
                        audioQuality: .good, // Default quality
                        sessionDuration: 30.0 // Default duration
                    )
                }
        } catch {
          
            return []
        }
    }
    
    private func updateProgressMetrics() {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentInterventions = completedInterventions.filter { $0.completedAt >= weekAgo }
        
        progressMetrics = ProgressMetrics(
            emotionalAwarenessProgress: calculateEmotionalAwarenessProgress(),
            stressManagementProgress: calculateStressManagementProgress(recentInterventions),
            mindfulnessProgress: calculateMindfulnessProgress(recentInterventions),
            goalAchievementProgress: calculateGoalAchievementProgress()
        )
    }
    
    private func calculateWeeklyCompletionRate() -> Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentInterventions = completedInterventions.filter { $0.completedAt >= weekAgo }
        
        // Assume 7 recommended interventions per week
        return min(Double(recentInterventions.count) / 7.0, 1.0)
    }
    
    private func calculateEmotionalAwarenessProgress() -> Double {
        // Based on frequency of emotion check-ins
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentEmotions = getRecentEmotions().filter { $0.timestamp >= weekAgo }
        
        // Target: 1 check-in per day
        return min(Double(recentEmotions.count) / 7.0, 1.0)
    }
    
    private func calculateStressManagementProgress(_ interventions: [CompletedIntervention]) -> Double {
        let stressInterventions = interventions.filter { $0.category == .stressManagement }
        return min(Double(stressInterventions.count) / 3.0, 1.0) // Target: 3 per week
    }
    
    private func calculateMindfulnessProgress(_ interventions: [CompletedIntervention]) -> Double {
        let mindfulnessInterventions = interventions.filter { $0.category == .mindfulness }
        return min(Double(mindfulnessInterventions.count) / 5.0, 1.0) // Target: 5 per week
    }
    
    private func calculateGoalAchievementProgress() -> Double {
        guard !userGoals.isEmpty else { return 0.0 }
        
        let completedGoals = userGoals.filter { $0.isCompleted }.count
        let totalGoals = userGoals.count
        
        // Calculate based on completed goals and average progress of active goals
        let completionRate = Double(completedGoals) / Double(totalGoals)
        let activeGoals = userGoals.filter { !$0.isCompleted }
        
        if activeGoals.isEmpty {
            return completionRate
        } else {
            let averageProgress = activeGoals.map { $0.progress }.reduce(0, +) / Double(activeGoals.count)
            return (completionRate + averageProgress) / 2.0
        }
    }
}

// MARK: - Supporting Types

struct EmotionPattern {
    let dominantEmotion: EmotionType?
    let stressLevel: Double
    let moodVariability: Double
    let energyLevel: Double
    
    init(dominantEmotion: EmotionType? = nil, stressLevel: Double = 0, moodVariability: Double = 0, energyLevel: Double = 0.5) {
        self.dominantEmotion = dominantEmotion
        self.stressLevel = stressLevel
        self.moodVariability = moodVariability
        self.energyLevel = energyLevel
    }
}

struct ProgressMetrics {
    let emotionalAwarenessProgress: Double
    let stressManagementProgress: Double
    let mindfulnessProgress: Double
    let goalAchievementProgress: Double
    
    init(emotionalAwarenessProgress: Double = 0, stressManagementProgress: Double = 0, mindfulnessProgress: Double = 0, goalAchievementProgress: Double = 0) {
        self.emotionalAwarenessProgress = emotionalAwarenessProgress
        self.stressManagementProgress = stressManagementProgress
        self.mindfulnessProgress = mindfulnessProgress
        self.goalAchievementProgress = goalAchievementProgress
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let emotionAnalysisCompleted = Notification.Name("emotionAnalysisCompleted")
    static let goalCompleted = Notification.Name("goalCompleted")
    static let milestoneCompleted = Notification.Name("milestoneCompleted")
}

