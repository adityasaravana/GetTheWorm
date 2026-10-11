//
//  WormStore.swift
//  GetTheWorm
//
//  One shared SwiftData container, reachable from the app UI and from App
//  Intents that run while the UI isn't up (the stop-button respawn).
//

import Foundation
import SwiftData

enum WormStore {
    static let container: ModelContainer = {
        let schema = Schema([
            AlarmSettings.self,
            WakeDay.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A store that can't open (failed migration, corruption) must not
            // brick the alarm clock. Losing the single settings object is the
            // lesser evil: wipe and start fresh.
            try? FileManager.default.removeItem(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()
}
