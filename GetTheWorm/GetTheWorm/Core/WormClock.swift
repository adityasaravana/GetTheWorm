//
//  WormClock.swift
//  GetTheWorm
//
//  Pure date math for the alarm chain. No AlarmKit, fully unit-testable.
//

import Foundation

enum WormClock {
    /// One-shot backup alarms scheduled after the main alarm, one per minute.
    /// The OS may cap us lower (AlarmError.maximumLimitReached); we take what we can get.
    static let backupCount = 29
    /// Seconds between chain alarms.
    static let spacing: TimeInterval = 60
    /// The chain covers this window; ringing state lasts exactly as long.
    static let windowDuration: TimeInterval = 30 * 60

    /// Next date strictly after `date` matching hour/minute on any active weekday.
    static func nextOccurrence(
        hour: Int, minute: Int, weekdays: [Int],
        after date: Date, calendar: Calendar = .current
    ) -> Date? {
        occurrence(hour: hour, minute: minute, weekdays: weekdays,
                   from: date, direction: .forward, calendar: calendar)
    }

    /// Most recent occurrence at or before `date` (the start of the current
    /// ringing window, if `date` falls inside one).
    static func previousOccurrence(
        hour: Int, minute: Int, weekdays: [Int],
        onOrBefore date: Date, calendar: Calendar = .current
    ) -> Date? {
        occurrence(hour: hour, minute: minute, weekdays: weekdays,
                   from: date, direction: .backward, calendar: calendar)
    }

    private static func occurrence(
        hour: Int, minute: Int, weekdays: [Int],
        from date: Date, direction: Calendar.SearchDirection, calendar: Calendar
    ) -> Date? {
        let candidates = weekdays.compactMap { weekday -> Date? in
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = weekday
            return calendar.nextDate(
                after: date, matching: components,
                matchingPolicy: .nextTime, direction: direction)
        }
        return direction == .forward ? candidates.min() : candidates.max()
    }

    /// The app is in wake-up mode: inside the 30-minute window of an occurrence
    /// that hasn't been defeated by a grass photo yet. Deliberately independent
    /// of live alarm state — stopping every alarm from the lock screen doesn't
    /// get you out of this.
    static func isRinging(
        hour: Int, minute: Int, weekdays: [Int], isEnabled: Bool,
        lastVictoryDate: Date?, now: Date, calendar: Calendar = .current
    ) -> Bool {
        guard isEnabled, !weekdays.isEmpty else { return false }
        guard let start = previousOccurrence(
            hour: hour, minute: minute, weekdays: weekdays,
            onOrBefore: now, calendar: calendar) else { return false }
        guard now < start.addingTimeInterval(windowDuration) else { return false }
        if let victory = lastVictoryDate, victory >= start { return false }
        return true
    }
}
