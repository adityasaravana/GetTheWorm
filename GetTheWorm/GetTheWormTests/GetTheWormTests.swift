//
//  GetTheWormTests.swift
//  GetTheWormTests
//

import Foundation
import SwiftData
import Testing
import UIKit
import Vision
@testable import GetTheWorm

// MARK: - WormClock

struct WormClockTests {
    // Fixed calendar so results don't depend on the machine running the tests.
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026-07-13 is a Monday.
    func date(_ day: Int, _ hour: Int, _ minute: Int, second: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute, second: second))!
    }

    @Test func nextOccurrenceLaterSameDay() {
        let next = WormClock.nextOccurrence(
            hour: 7, minute: 0, weekdays: [2], after: date(13, 6, 0), calendar: utc)
        #expect(next == date(13, 7, 0))
    }

    @Test func nextOccurrenceSkipsToNextWeekWhenPassed() {
        let next = WormClock.nextOccurrence(
            hour: 7, minute: 0, weekdays: [2], after: date(13, 7, 30), calendar: utc)
        #expect(next == date(20, 7, 0))
    }

    @Test func nextOccurrencePicksNearestWeekday() {
        // Monday 7:30 with Mon+Tue active: Tuesday wins over next Monday.
        let next = WormClock.nextOccurrence(
            hour: 7, minute: 0, weekdays: [2, 3], after: date(13, 7, 30), calendar: utc)
        #expect(next == date(14, 7, 0))
    }

    @Test func previousOccurrenceFindsWindowStart() {
        let start = WormClock.previousOccurrence(
            hour: 7, minute: 0, weekdays: [2, 3], onOrBefore: date(14, 7, 10), calendar: utc)
        #expect(start == date(14, 7, 0))
    }

    @Test func dstTransitionKeepsWallClockTime() {
        // Spring forward in Los Angeles: 2026-03-08 02:00 → 03:00.
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let saturdayNight = la.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 0))!
        let next = WormClock.nextOccurrence(
            hour: 7, minute: 0, weekdays: [1], after: saturdayNight, calendar: la)
        let components = la.dateComponents([.day, .hour, .minute], from: next!)
        #expect(components.day == 8)
        #expect(components.hour == 7)
        #expect(components.minute == 0)
    }

    // MARK: isRinging

    private func ringing(
        now: Date, victory: Date? = nil, enabled: Bool = true,
        weekdays: [Int] = [2], armedAt: Date = .distantPast
    ) -> Bool {
        WormClock.isRinging(
            hour: 7, minute: 0, weekdays: weekdays, isEnabled: enabled,
            lastVictoryDate: victory, armedAt: armedAt, now: now, calendar: utc)
    }

    @Test func ringsInsideWindow() {
        #expect(ringing(now: date(13, 7, 0, second: 5)))
        #expect(ringing(now: date(13, 7, 29)))
    }

    @Test func silentOutsideWindow() {
        #expect(!ringing(now: date(13, 6, 59)))
        #expect(!ringing(now: date(13, 7, 31)))
    }

    @Test func victoryEndsRinging() {
        #expect(!ringing(now: date(13, 7, 10), victory: date(13, 7, 5)))
    }

    @Test func staleVictoryDoesNotHelp() {
        // Last week's grass photo doesn't defeat today's alarm.
        #expect(ringing(now: date(13, 7, 10), victory: date(6, 7, 5)))
    }

    @Test func disabledNeverRings() {
        #expect(!ringing(now: date(13, 7, 10), enabled: false))
        #expect(!ringing(now: date(13, 7, 10), weekdays: []))
    }

    @Test func inactiveWeekdayDoesNotRing() {
        // Tuesday 7:10 with only Monday armed: Monday's window ended long ago.
        #expect(!ringing(now: date(14, 7, 10)))
    }

    @Test func dialingIntoRecentPastDoesNotAmbush() {
        // Setting the alarm to a time 10 minutes ago (settings touched *after*
        // that occurrence began) must not enter ringing mode.
        #expect(!ringing(now: date(13, 7, 10), armedAt: date(13, 7, 9)))
        // But an occurrence that begins after arming rings normally.
        #expect(ringing(now: date(13, 7, 10), armedAt: date(13, 6, 0)))
    }
}

// MARK: - WakeLog

struct WakeLogTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026-07-13 is a Monday.
    func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    let weekdaysOnly = [2, 3, 4, 5, 6]

    // MARK: Which day a victory belongs to

    @Test func victoryFilesUnderOccurrenceDay() {
        let day = WakeLog.day(forVictoryAt: date(13, 7, 12), hour: 7, minute: 0, weekdays: [2], calendar: utc)
        #expect(day == date(13))
    }

    @Test func lateNightAlarmDefeatedAfterMidnightKeepsEveningDay() {
        // Alarm 11:50 PM Monday, grass shown 12:04 AM Tuesday → Monday.
        let day = WakeLog.day(forVictoryAt: date(14, 0, 4), hour: 23, minute: 50, weekdays: [2], calendar: utc)
        #expect(day == date(13))
    }

    @Test func noArmedWeekdaysFallsBackToToday() {
        let day = WakeLog.day(forVictoryAt: date(13, 7, 12), hour: 7, minute: 0, weekdays: [], calendar: utc)
        #expect(day == date(13))
    }

    // MARK: Current streak

    @Test func emptyLogIsZero() {
        #expect(WakeLog.currentStreak(outcomes: [:], weekdays: weekdaysOnly, today: date(15), calendar: utc) == 0)
    }

    @Test func countsConsecutiveArmedDays() {
        let outcomes = [date(13): true, date(14): true, date(15): true]
        #expect(WakeLog.currentStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(15), calendar: utc) == 3)
    }

    @Test func weekendDoesNotBreakStreak() {
        // Thu 9, Fri 10, (Sat 11, Sun 12 off), Mon 13.
        let outcomes = [date(9): true, date(10): true, date(13): true]
        #expect(WakeLog.currentStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(13), calendar: utc) == 3)
    }

    @Test func missingArmedDayBreaksStreak() {
        // Tuesday 14 has no record.
        let outcomes = [date(13): true, date(15): true, date(16): true]
        #expect(WakeLog.currentStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(16), calendar: utc) == 2)
    }

    @Test func explicitMissBreaksStreak() {
        let outcomes = [date(13): true, date(14): false, date(15): true]
        #expect(WakeLog.currentStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(15), calendar: utc) == 1)
    }

    @Test func pendingTodayDoesNotBreakStreak() {
        // It's Wednesday morning before the alarm; Mon + Tue still count.
        let outcomes = [date(13): true, date(14): true]
        #expect(WakeLog.currentStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(15, 6), calendar: utc) == 2)
    }

    @Test func explicitMissTodayBreaksStreak() {
        let outcomes = [date(13): true, date(14): true, date(15): false]
        #expect(WakeLog.currentStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(15), calendar: utc) == 0)
    }

    @Test func wakeUpsOnUnarmedDaysDoNotCount() {
        // Showed grass on Saturday for fun; only weekdays are armed.
        let outcomes = [date(10): true, date(11): true, date(13): true]
        #expect(WakeLog.currentStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(13), calendar: utc) == 2)
    }

    @Test func noWeekdaysArmedIsZero() {
        let outcomes = [date(13): true]
        #expect(WakeLog.currentStreak(outcomes: outcomes, weekdays: [], today: date(13), calendar: utc) == 0)
    }

    // MARK: Longest streak

    @Test func longestStreakSpansGaps() {
        // Run of 3 (Mon–Wed 6–8), miss Thu 9, then run of 2 (Fri 10, Mon 13).
        let outcomes = [
            date(6): true, date(7): true, date(8): true,
            date(9): false,
            date(10): true, date(13): true,
        ]
        #expect(WakeLog.longestStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(13), calendar: utc) == 3)
        #expect(WakeLog.currentStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(13), calendar: utc) == 2)
    }

    @Test func longestStreakIncludesCurrentRun() {
        let outcomes = [date(13): true, date(14): true, date(15): true, date(16): true]
        #expect(WakeLog.longestStreak(outcomes: outcomes, weekdays: weekdaysOnly, today: date(16), calendar: utc) == 4)
    }

    // MARK: Persistence

    @MainActor
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AlarmSettings.self, WakeDay.self, configurations: configuration)
        return ModelContext(container)
    }

    @MainActor
    @Test func recordVictoryInsertsOneRowPerDay() throws {
        let context = try makeContext()
        let settings = AlarmSettings(hour: 7, minute: 0, weekdays: [2])
        context.insert(settings)

        WakeLog.recordVictory(at: date(13, 7, 5), settings: settings, in: context, calendar: utc)
        WakeLog.recordVictory(at: date(13, 7, 20), settings: settings, in: context, calendar: utc)

        let rows = try context.fetch(FetchDescriptor<WakeDay>())
        #expect(rows.count == 1)
        #expect(rows.first?.day == date(13))
        #expect(rows.first?.wokeUp == true)
        #expect(rows.first?.source == .grass)
        #expect(rows.first?.recordedAt == date(13, 7, 20))
    }

    @MainActor
    @Test func manualEditOverridesGrassRecord() throws {
        let context = try makeContext()
        let settings = AlarmSettings(hour: 7, minute: 0, weekdays: [2])
        context.insert(settings)

        WakeLog.recordVictory(at: date(13, 7, 5), settings: settings, in: context, calendar: utc)
        WakeLog.set(day: date(13), wokeUp: false, source: .manual, in: context)

        let record = try #require(WakeLog.record(for: date(13), in: context))
        #expect(record.wokeUp == false)
        #expect(record.source == .manual)
        #expect(WakeLog.outcomes(in: context) == [date(13): false])
    }

    @MainActor
    @Test func backfillSeedsFromLastVictoryOnce() throws {
        let context = try makeContext()
        let settings = AlarmSettings(hour: 7, minute: 0, weekdays: [2])
        settings.lastVictoryDate = date(13, 7, 5)
        context.insert(settings)

        WakeLog.backfillIfNeeded(settings: settings, in: context, calendar: utc)
        WakeLog.backfillIfNeeded(settings: settings, in: context, calendar: utc)

        let rows = try context.fetch(FetchDescriptor<WakeDay>())
        #expect(rows.count == 1)
        #expect(rows.first?.day == date(13))
    }

    @MainActor
    @Test func backfillDoesNothingWithoutVictory() throws {
        let context = try makeContext()
        let settings = AlarmSettings()
        context.insert(settings)

        WakeLog.backfillIfNeeded(settings: settings, in: context, calendar: utc)

        #expect(try context.fetchCount(FetchDescriptor<WakeDay>()) == 0)
    }
}

// MARK: - Display formatting

struct DisplayFormattingTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func time(_ hour: Int, _ minute: Int, second: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: hour, minute: minute, second: second))!
    }

    @Test func midnightIsTwelveAM() {
        let display = ClockRadioView.displayTime(for: time(0, 5), calendar: utc)
        #expect(display.text == "12:05")
        #expect(!display.isPM)
    }

    @Test func noonIsTwelvePM() {
        let display = ClockRadioView.displayTime(for: time(12, 30), calendar: utc)
        #expect(display.text == "12:30")
        #expect(display.isPM)
    }

    @Test func singleDigitHourIsSpacePadded() {
        let display = ClockRadioView.displayTime(for: time(7, 4), calendar: utc)
        #expect(display.text == " 7:04")
    }

    @Test func colonBlinksWithoutChangingText() {
        // The colon must stay in the string (only its brightness changes),
        // or glyph widths shift and the whole display jumps.
        let even = ClockRadioView.displayTime(for: time(7, 4, second: 2), calendar: utc)
        let odd = ClockRadioView.displayTime(for: time(7, 4, second: 3), calendar: utc)
        #expect(even.text == odd.text)
        #expect(even.colonVisible && !odd.colonVisible)
    }

    @Test func alarmTimeFormatsTwelveHour() {
        let midnight = ClockRadioView.alarmTime(AlarmSettings(hour: 0, minute: 5))
        #expect(midnight.text == "12:05")
        #expect(!midnight.isPM)
        let afternoon = ClockRadioView.alarmTime(AlarmSettings(hour: 13, minute: 45))
        #expect(afternoon.text == " 1:45")
        #expect(afternoon.isPM)
    }
}

// MARK: - GrassCheck (runs the real Vision classifier on bundled fixtures)

// Device-only: the Vision classifier cannot execute in the simulator ("failed
// to create espresso context"). The same fixtures + thresholds are verified on
// macOS via tools/classify-fixtures.swift, which shares the classifier family.
#if !targetEnvironment(simulator)
struct GrassCheckTests {
    @Test(arguments: [
        ("fixture-grass-lawn", true),
        ("fixture-grass-blades", true),
        ("fixture-grass-field", true),
        ("fixture-clams", false),
        ("fixture-bedroom", false),
        ("fixture-cat", false),
    ])
    func fixtureVerdicts(name: String, expectedGrass: Bool) async throws {
        let url = try #require(
            Bundle.main.url(forResource: name, withExtension: "jpg"),
            "fixture \(name).jpg missing from app bundle")
        let image = try #require(UIImage(contentsOfFile: url.path)?.cgImage)
        let verdict = await GrassCheck.verify(image)
        #expect(verdict.isGrass == expectedGrass, "\(name): \(verdict.observations)")
    }
}
#endif
