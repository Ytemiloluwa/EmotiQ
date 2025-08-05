//
//  EmotiQApp.swift
//  EmotiQ
//
//  Created by Temiloluwa on 31-07-2025.
//

import SwiftUI
import OneSignalFramework

@main
struct EmotiQApp: App {
    // Connect AppDelegate for OneSignal setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Optional: Verbose logging for debugging (remove in production)
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)

        // Replace with your real OneSignal App ID
        OneSignal.initialize("YOUR_ONESIGNAL_APP_ID", withLaunchOptions: launchOptions)

        // Request permission for push notifications
        OneSignal.Notifications.requestPermission({ accepted in
            print("User accepted notifications: \(accepted)")
        }, fallbackToSettings: false)

        return true
    }
}

