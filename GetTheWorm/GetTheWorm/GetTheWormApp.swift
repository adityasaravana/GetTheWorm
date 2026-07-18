//
//  GetTheWormApp.swift
//  GetTheWorm
//

import SwiftData
import SwiftUI

@main
struct GetTheWormApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(WormStore.container)
    }
}
