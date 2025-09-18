//
//  EmotiQApp.swift
//  EmotiQ
//
//  Created by Temiloluwa on 31-07-2025.
//

import SwiftUI
import OneSignalFramework
import RevenueCat

// MARK: - Notification Extensions
extension Notification.Name {
    static let navigateToVoiceAnalysis = Notification.Name("navigateToVoiceAnalysis")
    static let navigateToMainApp = Notification.Name("navigateToMainApp")
    static let navigateToInsights = Notification.Name("navigateToInsights")
}

@main
struct EmotiQApp: App {
    // Connect AppDelegate for OneSignal setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared
    let subscriptionService = SubscriptionService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(subscriptionService)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh daily usage when app becomes active
                    subscriptionService.refreshDailyUsage()
                    
                    // Force sync OneSignal permission status when app becomes active
                    OneSignalService.shared.forceSyncPermissionStatus()
                }
                .onReceive(NotificationCenter.default.publisher(for: .navigateToMainApp)) { _ in
                    // App is already in foreground, no navigation needed
                    // But we can trigger any specific actions if needed
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {


        RevenueCatService.shared.configure()


        // Use centralized OneSignal configuration
        OneSignal.initialize(Config.oneSignalAppID, withLaunchOptions: launchOptions)
        
        // Clean up duplicate emotional data on app launch
        PersistenceController.shared.cleanupDuplicateEmotionalData()
        
        // Clean up old data (keep only last 30 days for performance)
        PersistenceController.shared.deleteOldData(olderThan: 30)

        return true
    }
    
    // MARK: - URL Scheme Handling for Deep Linking
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return handleDeepLink(url: url)
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            return handleDeepLink(url: url)
        }
        return false
    }
    
    private func handleDeepLink(url: URL) -> Bool {
        guard url.scheme == "emotiq" else { return false }
        
        switch url.host {
        case "voice-analysis":
            // Navigate to voice analysis
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("navigateToVoiceAnalysis"),
                    object: nil,
                    userInfo: ["source": "deep_link"]
                )
            }
            return true
            
        case "dashboard":
            // Navigate to dashboard
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("navigateToMainApp"),
                    object: nil,
                    userInfo: ["source": "deep_link"]
                )
            }
            return true
            
        case "welcome":
            // Handle welcome deep link
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("navigateToMainApp"),
                    object: nil,
                    userInfo: ["source": "welcome_deep_link"]
                )
            }
            return true
            
        default:
            return false
        }
    }
}

