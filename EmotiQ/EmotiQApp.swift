//
//  EmotiQApp.swift
//  EmotiQ
//
//  Created by Temiloluwa on 31-07-2025.
//

import SwiftUI

@main
struct EmotiQApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
