//
//  NotificationHistoryManager.swift
//  EmotiQ
//
//  Created by Temiloluwa on 09-09-2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class NotificationHistoryManager: ObservableObject {
    static let shared = NotificationHistoryManager()
    
    @Published var notifications: [NotificationHistoryItem] = []
    @Published var unreadCount: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let notificationsKey = "notification_history"
    private let maxHistoryItems = 100
    
    private init() {
        loadNotifications()
        updateUnreadCount()
    }
    
    // MARK: - Public Methods
    
    func addNotification(_ notification: NotificationHistoryItem) {
        notifications.insert(notification, at: 0)
        
        if notifications.count > maxHistoryItems {
            notifications = Array(notifications.prefix(maxHistoryItems))
        }
        
        updateUnreadCount()
        saveNotifications()
    }
    
    func markAsRead(_ notificationId: String) {
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index] = notifications[index].markAsRead()
            updateUnreadCount()
            saveNotifications()
        }
    }
    
    func markAllAsRead() {
        notifications = notifications.map { $0.markAsRead() }
        updateUnreadCount()
        saveNotifications()
    }
    
    func deleteNotification(_ notificationId: String) {
        notifications.removeAll { $0.id == notificationId }
        updateUnreadCount()
        saveNotifications()
    }
    
    func clearAllNotifications() {
        notifications.removeAll()
        updateUnreadCount()
        saveNotifications()
    }
    
    func getUnreadNotifications() -> [NotificationHistoryItem] {
        return notifications.filter { !$0.isRead }
    }
    
    func getNotificationsByType(_ type: NotificationHistoryType) -> [NotificationHistoryItem] {
        return notifications.filter { $0.type == type }
    }
    
    func getNotificationsFromLastWeek() -> [NotificationHistoryItem] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return notifications.filter { $0.receivedAt >= weekAgo }
    }
    
    // MARK: - Helper Methods for OneSignal Integration
    
    func addEmotionNotification(
        title: String,
        body: String,
        emotion: EmotionType,
        intervention: OneSignaInterventionType? = nil,
        priority: NotificationPriority = .medium,
        customData: [String: String]? = nil
    ) {
        let notification = NotificationHistoryItem(
            title: title,
            body: body,
            type: .emotionTriggered,
            emotion: emotion,
            intervention: intervention,
            customData: customData,
            priority: priority
        )
        addNotification(notification)
    }
    
    func addDailyCheckInNotification(
        title: String,
        body: String,
        customData: [String: String]? = nil
    ) {
        let notification = NotificationHistoryItem(
            title: title,
            body: body,
            type: .dailyCheckIn,
            customData: customData
        )
        addNotification(notification)
    }
    
    func addAchievementNotification(
        title: String,
        body: String,
        customData: [String: String]? = nil
    ) {
        let notification = NotificationHistoryItem(
            title: title,
            body: body,
            type: .achievement,
            customData: customData,
            priority: .high
        )
        addNotification(notification)
    }
    
    func addWelcomeNotification() {
        let notification = NotificationHistoryItem(
            title: "Welcome to EmotiQ! 🎉",
            body: "Start your emotional wellness journey today. Tap to explore the app!",
            type: .welcome,
            priority: .high
        )
        addNotification(notification)
    }
    
    func addPredictiveNotification(
        title: String,
        body: String,
        emotion: EmotionType,
        intervention: OneSignaInterventionType,
        customData: [String: String]? = nil
    ) {
        let notification = NotificationHistoryItem(
            title: title,
            body: body,
            type: .predictiveIntervention,
            emotion: emotion,
            intervention: intervention,
            customData: customData,
            priority: .high
        )
        addNotification(notification)
    }
    
    // MARK: - Private Methods
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    private func saveNotifications() {
        do {
            let data = try JSONEncoder().encode(notifications)
            userDefaults.set(data, forKey: notificationsKey)
        } catch {
         
        }
    }
    
    private func loadNotifications() {
        guard let data = userDefaults.data(forKey: notificationsKey) else {
            return
        }
        
        do {
            notifications = try JSONDecoder().decode([NotificationHistoryItem].self, from: data)
        } catch {
        
            notifications = []
        }
    }
    
    // MARK: - Analytics
    
    func getNotificationStats() -> NotificationStats {
        let total = notifications.count
        let unread = unreadCount
        let thisWeek = getNotificationsFromLastWeek().count
        let byType = Dictionary(grouping: notifications, by: { $0.type })
            .mapValues { $0.count }
        
        return NotificationStats(
            total: total,
            unread: unread,
            thisWeek: thisWeek,
            byType: byType
        )
    }
    
}

struct NotificationStats {
    let total: Int
    let unread: Int
    let thisWeek: Int
    let byType: [NotificationHistoryType: Int]
}
