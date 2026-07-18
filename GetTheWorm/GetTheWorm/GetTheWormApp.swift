//
//  GetTheWormApp.swift
//  GetTheWorm
//

import SwiftData
import SwiftUI

@main
struct GetTheWormApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AlarmSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // A store that can't open (failed migration, corruption) must not
            // brick the alarm clock. Losing the single settings object is the
            // lesser evil: wipe and start fresh.
            try? FileManager.default.removeItem(at: modelConfiguration.url)
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
