// CardWiseApp.swift
// CardWise
//
// Main app entry point

import SwiftUI
import SwiftData

@main
struct CardWiseApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Transaction.self,
                Card.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }

        // Register notification categories
        NotificationService.shared.registerCategories()

        // Load card database
        _ = CardDatabase.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
