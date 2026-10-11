//
//  WakeLog.swift
//  GetTheWorm
//
//  Recording wake-ups and counting streaks. The date math is pure and
//  unit-testable; the SwiftData helpers are thin wrappers around it.
//

import Foundation
import SwiftData

enum WakeLog {
    // MARK: Which day a victory belongs to

    /// The calendar day a victory at `now` should be filed under: the local day
    /// of the alarm occurrence whose window it defeated. Falls back to the day
    /// of `now` if no occurrence can be found (e.g. no weekdays armed).
    static func day(
        forVictoryAt now: Date, hour: Int, minute: Int, weekdays: [Int],
        calendar: Calendar = .current
    ) -> Date {
        let start = WormClock.previousOccurrence(
            hour: hour, minute: minute, weekdays: weekdays,
            onOrBefore: now, calendar: calendar)
        return calendar.startOfDay(for: start ?? now)
    }

    // MARK: Streaks

    /// Consecutive wake-ups ending today, counted over armed weekdays only.
    ///
    /// Rules:
    /// - Weekdays the alarm isn't set for are skipped and never break a streak.
    /// - An armed day with no record, or an explicit miss, breaks the streak.
    /// - Today is special: if it's armed but has no record yet, it's pending
    ///   (the alarm may not have rung), so it's skipped rather than counted
    ///   as a miss. An explicit miss today still breaks.
    ///
    /// `outcomes` maps start-of-day → wokeUp. Uses the *current* weekday
    /// schedule for history too; we don't keep a log of schedule changes.
    static func currentStreak(
        outcomes: [Date: Bool], weekdays: [Int], today: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard !weekdays.isEmpty else { return 0 }
        let armed = Set(weekdays)
        var day = calendar.startOfDay(for: today)
        var streak = 0
        var isToday = true

        // Bounded walk: nothing older than the earliest record can extend the
        // streak, so stop once we've passed it.
        let floor = outcomes.keys.min() ?? day

        while day >= floor {
            defer {
                isToday = false
                day = calendar.date(byAdding: .day, value: -1, to: day) ?? floor.addingTimeInterval(-1)
            }
            guard armed.contains(calendar.component(.weekday, from: day)) else { continue }
            switch outcomes[day] {
            case true?:
                streak += 1
            case false?:
                return streak
            case nil:
                if isToday { continue }
                return streak
            }
        }
        return streak
    }

    /// Longest run of wake-ups on armed weekdays anywhere in the record,
    /// counting the current run too.
    static func longestStreak(
        outcomes: [Date: Bool], weekdays: [Int], today: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard !weekdays.isEmpty, let first = outcomes.keys.min() else { return 0 }
        let armed = Set(weekdays)
        let end = calendar.startOfDay(for: today)
        var day = calendar.startOfDay(for: first)
        var best = 0
        var run = 0

        while day <= end {
            if armed.contains(calendar.component(.weekday, from: day)) {
                switch outcomes[day] {
                case true?:
                    run += 1
                    best = max(best, run)
                case false?:
                    run = 0
                case nil:
                    // Today with no record is pending, not a miss.
                    if day != end { run = 0 }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }

    // MARK: SwiftData helpers

    /// File a grass victory under the right day. Idempotent: a second victory
    /// on the same day just refreshes the record.
    static func recordVictory(
        at now: Date = .now, settings: AlarmSettings, in context: ModelContext,
        calendar: Calendar = .current
    ) {
        let day = day(
            forVictoryAt: now, hour: settings.hour, minute: settings.minute,
            weekdays: settings.weekdays, calendar: calendar)
        set(day: day, wokeUp: true, source: .grass, at: now, in: context)
    }

    /// Upsert one day's outcome. This is what the calendar will call when the
    /// user edits a day by hand.
    static func set(
        day: Date, wokeUp: Bool, source: WakeDay.Source, at now: Date = .now,
        in context: ModelContext
    ) {
        if let existing = record(for: day, in: context) {
            existing.wokeUp = wokeUp
            existing.source = source
            existing.recordedAt = now
        } else {
            context.insert(WakeDay(day: day, wokeUp: wokeUp, source: source, recordedAt: now))
        }
    }

    static func record(for day: Date, in context: ModelContext) -> WakeDay? {
        var descriptor = FetchDescriptor<WakeDay>(predicate: #Predicate { $0.day == day })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Every recorded day as start-of-day → wokeUp, ready for the streak math.
    static func outcomes(in context: ModelContext) -> [Date: Bool] {
        let records = (try? context.fetch(FetchDescriptor<WakeDay>())) ?? []
        return Dictionary(records.map { ($0.day, $0.wokeUp) }, uniquingKeysWith: { _, last in last })
    }

    /// Stores created before wake days existed only know the single most
    /// recent victory. Seed one record from it so the log doesn't start empty.
    static func backfillIfNeeded(
        settings: AlarmSettings, in context: ModelContext, calendar: Calendar = .current
    ) {
        guard let victory = settings.lastVictoryDate else { return }
        var descriptor = FetchDescriptor<WakeDay>()
        descriptor.fetchLimit = 1
        let hasAny = ((try? context.fetchCount(descriptor)) ?? 0) > 0
        guard !hasAny else { return }
        recordVictory(at: victory, settings: settings, in: context, calendar: calendar)
    }
}
