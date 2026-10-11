//
//  CloudBackup.swift
//  GetTheWorm
//
//  Mirrors the handful of settings worth keeping — wake-up time, weekdays,
//  on/off, streak — into iCloud key-value storage so they outlive the app
//  being deleted. AlarmKit IDs and chain state stay local: those alarms die
//  with the install anyway, and reconcile rebuilds them from the settings.
//

import Foundation

enum CloudBackup {
    private static let store = NSUbiquitousKeyValueStore.default

    private enum Key {
        static let hour = "alarm.hour"
        static let minute = "alarm.minute"
        static let weekdays = "alarm.weekdays"
        static let isEnabled = "alarm.isEnabled"
        static let streak = "streak"
        static let savedAt = "savedAt"
    }

    /// Local-only marker (dies with the install, which is the point): set once
    /// this install has taken or written cloud values, so a change arriving
    /// later from iCloud doesn't stomp on settings the user has since edited.
    private static let seededKey = "CloudBackup.seeded"
    static var hasSeeded: Bool {
        get { UserDefaults.standard.bool(forKey: seededKey) }
        set { UserDefaults.standard.set(newValue, forKey: seededKey) }
    }

    /// Kick off the pull from iCloud. On the first launch after a reinstall the
    /// values usually aren't here yet; `externalChanges` fires when they land.
    static func start() {
        store.synchronize()
    }

    static var hasBackup: Bool {
        store.object(forKey: Key.savedAt) != nil
    }

    /// Write the current settings to iCloud. Writes made before the initial
    /// sync completes are discarded by the system, so this can't clobber a
    /// backup that simply hasn't downloaded yet.
    static func save(_ settings: AlarmSettings) {
        store.set(Int64(settings.hour), forKey: Key.hour)
        store.set(Int64(settings.minute), forKey: Key.minute)
        store.set(settings.weekdays.map(Int64.init), forKey: Key.weekdays)
        store.set(settings.isEnabled, forKey: Key.isEnabled)
        store.set(Int64(settings.streak), forKey: Key.streak)
        store.set(Date.now, forKey: Key.savedAt)
        store.synchronize()
        hasSeeded = true
    }

    /// Overwrite `settings` with the cloud snapshot. Returns false (and leaves
    /// `settings` untouched) when there is nothing in iCloud.
    @discardableResult
    static func restore(into settings: AlarmSettings) -> Bool {
        guard hasBackup else { return false }
        let hour = Int(store.longLong(forKey: Key.hour))
        let minute = Int(store.longLong(forKey: Key.minute))
        if (0..<24).contains(hour) { settings.hour = hour }
        if (0..<60).contains(minute) { settings.minute = minute }
        if let raw = store.array(forKey: Key.weekdays) as? [NSNumber] {
            settings.weekdays = raw.map(\.intValue).filter { (1...7).contains($0) }
        }
        settings.isEnabled = store.bool(forKey: Key.isEnabled)
        settings.streak = min(max(Int(store.longLong(forKey: Key.streak)), 0), TallyCounter.maximum)
        // A restored alarm counts as freshly dialed: a window that opened
        // before this moment must not ambush the user into ringing mode.
        settings.armedAt = .now
        hasSeeded = true
        return true
    }

    /// Fires when iCloud delivers values: the initial sync after a reinstall,
    /// or a write from another device.
    static var externalChanges: NotificationCenter.Notifications {
        // No `object:` filter: the store isn't Sendable, and only the default
        // store posts this notification anyway.
        NotificationCenter.default.notifications(
            named: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
    }
}
