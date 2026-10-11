//
//  AlarmScheduler.swift
//  GetTheWorm
//
//  AlarmKit integration. The strategy: one recurring weekly alarm (the backbone,
//  always survives) plus a chain of one-shot backups a minute apart for the next
//  occurrence. Stopping any of them from the lock screen is futile — the rest of
//  the chain is already queued with the OS. Only a grass photo cancels the chain.
//

import ActivityKit
import AlarmKit
import AppIntents
import Foundation
import SwiftData
import SwiftUI
import os

/// AlarmKit requires a metadata type; we have nothing to attach.
struct WormMetadata: AlarmMetadata {}

/// Secondary alert button: launches the app into the ringing screen.
struct ShowGrassIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Show Grass"
    static let openAppWhenRun = true
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult { .result() }
}

/// The listener: runs in our process whenever someone presses Stop on any of
/// our alarms. Unless the worm has been won, stopping an alarm just schedules
/// the next one a few seconds out. The pre-scheduled backbone chain still
/// exists for people who never press Stop at all — iOS gives us no code
/// execution for an ignored alarm.
struct StopRespawnIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Alarm"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let log = Logger(subsystem: "com.adityasaravana.GetTheWorm", category: "respawn")
        let context = ModelContext(WormStore.container)
        guard let settings = try? context.fetch(FetchDescriptor<AlarmSettings>()).first else {
            return .result()
        }
        let ringing = WormClock.isRinging(
            hour: settings.hour, minute: settings.minute,
            weekdays: settings.weekdays, isEnabled: settings.isEnabled,
            lastVictoryDate: settings.lastVictoryDate,
            armedAt: settings.armedAt, now: .now)
        guard ringing else {
            log.info("stop pressed outside an active window, no respawn")
            return .result()
        }
        let id = UUID()
        let fireDate = Date.now.addingTimeInterval(WormClock.respawnDelay)
        do {
            _ = try await AlarmManager.shared.schedule(
                id: id, configuration: wormAlarmConfiguration(schedule: .fixed(fireDate)))
            settings.backupAlarmIDs.append(id)
            try? context.save()
            log.info("stop pressed, respawned alarm \(id) for \(fireDate)")
        } catch {
            log.error("respawn failed: \(error)")
        }
        return .result()
    }
}

/// Shared alarm configuration, used by the scheduler and the respawn intent.
func wormAlarmConfiguration(schedule: Alarm.Schedule) -> AlarmManager.AlarmConfiguration<WormMetadata> {
    let alert = AlarmPresentation.Alert(
        title: "Wake up!",
        stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
        secondaryButton: AlarmButton(text: "Show Grass", textColor: .green, systemImageName: "camera.fill"),
        secondaryButtonBehavior: .custom)
    let attributes = AlarmAttributes<WormMetadata>(
        presentation: AlarmPresentation(alert: alert),
        tintColor: WormTheme.ledRed)
    return .alarm(
        schedule: schedule,
        attributes: attributes,
        stopIntent: StopRespawnIntent(),
        secondaryIntent: ShowGrassIntent(),
        sound: .default)
}

@MainActor
@Observable
final class AlarmScheduler {
    private let manager = AlarmManager.shared
    private let log = Logger(subsystem: "com.adityasaravana.GetTheWorm", category: "scheduler")

    var authorizationDenied = false

    // MARK: Authorization

    func requestAuthorizationIfNeeded() async -> Bool {
        switch manager.authorizationState {
        case .authorized:
            return true
        case .denied:
            authorizationDenied = true
            return false
        case .notDetermined:
            let state = try? await manager.requestAuthorization()
            log.info("authorization requested, result: \(String(describing: state))")
            authorizationDenied = state != .authorized
            return state == .authorized
        @unknown default:
            return false
        }
    }

    // MARK: Arming

    /// Tear down and rebuild everything from current settings.
    func rearm(_ settings: AlarmSettings) async {
        cancelAll(settings)
        guard settings.isEnabled, !settings.weekdays.isEmpty else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let localeWeekdays = settings.weekdays.compactMap(Locale.Weekday.init(calendarWeekday:))
        let schedule = Alarm.Schedule.relative(.init(
            time: .init(hour: settings.hour, minute: settings.minute),
            repeats: .weekly(localeWeekdays)))
        let mainID = UUID()
        do {
            _ = try await manager.schedule(id: mainID, configuration: wormAlarmConfiguration(schedule: schedule))
            settings.mainAlarmID = mainID
            log.info("main weekly alarm scheduled: \(mainID) at \(settings.hour):\(settings.minute)")
        } catch {
            log.error("failed to schedule main alarm: \(error)")
            return
        }
        await scheduleBackups(settings)
    }

    func disarm(_ settings: AlarmSettings) {
        cancelAll(settings)
    }

    /// Queue the one-shot chain for the next occurrence. Stops early if the OS
    /// alarm limit is reached — a shorter chain is still a chain.
    private func scheduleBackups(_ settings: AlarmSettings) async {
        guard let next = WormClock.nextOccurrence(
            hour: settings.hour, minute: settings.minute,
            weekdays: settings.weekdays, after: .now) else { return }

        let started = Date.now
        var ids: [UUID] = []
        for k in 1...WormClock.backupCount {
            let fireDate = next.addingTimeInterval(Double(k) * WormClock.spacing)
            let id = UUID()
            do {
                _ = try await manager.schedule(id: id, configuration: wormAlarmConfiguration(schedule: .fixed(fireDate)))
                ids.append(id)
            } catch {
                log.warning("backup chain stopped at \(ids.count)/\(WormClock.backupCount): \(error)")
                break
            }
        }
        settings.backupAlarmIDs = ids
        settings.chainOccurrence = next
        log.info("backup chain scheduled: \(ids.count) alarms starting \(next.addingTimeInterval(WormClock.spacing)), took \(String(format: "%.1f", Date.now.timeIntervalSince(started)))s")
    }

    // MARK: Victory

    /// The user photographed grass: silence everything, then queue the next
    /// occurrence's chain while we have the chance.
    func victory(_ settings: AlarmSettings) async {
        let now = Date.now
        settings.lastVictoryDate = now
        if let context = settings.modelContext {
            WakeLog.recordVictory(at: now, settings: settings, in: context)
        }
        for id in settings.backupAlarmIDs {
            try? manager.cancel(id: id)
        }
        settings.backupAlarmIDs = []
        if let mainID = settings.mainAlarmID {
            // Stops today's alert; the weekly alarm stays scheduled for next time.
            try? manager.stop(id: mainID)
        }
        await scheduleBackups(settings)
    }

    // MARK: Reconciliation

    /// Called whenever the app comes to the foreground. Prunes fired/stale
    /// backups and keeps the chain topped up for the next occurrence — but never
    /// touches an actively-ringing chain.
    func reconcile(_ settings: AlarmSettings) async {
        guard settings.isEnabled else { return }

        let live = (try? manager.alarms) ?? []
        let liveIDs = Set(live.map(\.id))

        guard let mainID = settings.mainAlarmID, liveIDs.contains(mainID) else {
            await rearm(settings)
            return
        }

        let ringing = WormClock.isRinging(
            hour: settings.hour, minute: settings.minute,
            weekdays: settings.weekdays, isEnabled: settings.isEnabled,
            lastVictoryDate: settings.lastVictoryDate,
            armedAt: settings.armedAt, now: .now)
        guard !ringing else { return }

        // Outside the window: silence any stale alerting alarms.
        for alarm in live where alarm.state == .alerting {
            try? manager.stop(id: alarm.id)
        }

        // Rebuilding ~180 alarms takes a while, so skip it when the queued
        // chain is intact and still aimed at the right occurrence.
        let next = WormClock.nextOccurrence(
            hour: settings.hour, minute: settings.minute,
            weekdays: settings.weekdays, after: .now)
        let chainIntact = !settings.backupAlarmIDs.isEmpty
            && settings.chainOccurrence == next
            && settings.backupAlarmIDs.allSatisfy(liveIDs.contains)
        guard !chainIntact else { return }

        for id in settings.backupAlarmIDs {
            try? manager.cancel(id: id)
        }
        settings.backupAlarmIDs = []
        await scheduleBackups(settings)
    }

    // MARK: Helpers

    private func cancelAll(_ settings: AlarmSettings) {
        for id in settings.allAlarmIDs {
            try? manager.cancel(id: id)
        }
        settings.mainAlarmID = nil
        settings.backupAlarmIDs = []
    }
}

extension Locale.Weekday {
    /// Calendar weekday number (1 = Sunday … 7 = Saturday) to Locale.Weekday.
    init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
