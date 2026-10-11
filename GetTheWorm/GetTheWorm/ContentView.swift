//
//  ContentView.swift
//  GetTheWorm
//
//  Routing: clock radio by default, ringing screen while a wake-up window is
//  active and undefeated, victory screen right after showing grass.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allSettings: [AlarmSettings]

    @State private var scheduler = AlarmScheduler()
    @State private var showVictory = false

    var body: some View {
        Group {
            if let settings = allSettings.first {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let ringing = WormClock.isRinging(
                        hour: settings.hour, minute: settings.minute,
                        weekdays: settings.weekdays, isEnabled: settings.isEnabled,
                        lastVictoryDate: settings.lastVictoryDate,
                        armedAt: settings.armedAt, now: timeline.date)
                    if showVictory {
                        VictoryView { showVictory = false }
                    } else if ringing {
                        RingingView(settings: settings, scheduler: scheduler) {
                            showVictory = true
                        }
                    } else {
                        ClockRadioView(settings: settings, scheduler: scheduler)
                    }
                }
            } else {
                WormTheme.room.ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            CloudBackup.start()
            if allSettings.isEmpty {
                // Fresh install: start from whatever iCloud already has cached,
                // falling back to defaults.
                let settings = AlarmSettings()
                CloudBackup.restore(into: settings)
                modelContext.insert(settings)
                await scheduler.reconcile(settings)
            }
        }
        .task {
            // iCloud values that land after launch — typically the initial sync
            // right after a reinstall. Only taken while this install has
            // nothing of its own yet.
            for await _ in CloudBackup.externalChanges {
                guard !CloudBackup.hasSeeded, let settings = allSettings.first else { continue }
                if CloudBackup.restore(into: settings) {
                    await scheduler.reconcile(settings)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard let settings = allSettings.first else { return }
            if phase == .active {
                Task { await scheduler.reconcile(settings) }
            } else {
                CloudBackup.save(settings)
            }
        }
    }
}
