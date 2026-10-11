//
//  AlarmSettings.swift
//  GetTheWorm
//

import Foundation
import SwiftData

/// The single persisted alarm. One wake-up time, one set of active weekdays.
@Model
final class AlarmSettings {
    var hour: Int
    var minute: Int
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday.
    var weekdays: [Int]
    var isEnabled: Bool

    /// The recurring weekly alarm registered with AlarmKit.
    var mainAlarmID: UUID?
    /// One-shot backup alarms forming the relentless chain for the next occurrence.
    var backupAlarmIDs: [UUID]
    /// The occurrence the current backup chain was built for. Lets reconcile
    /// skip an expensive rebuild when the queued chain is still the right one.
    var chainOccurrence: Date?
    /// Last time the user successfully photographed grass.
    var lastVictoryDate: Date?
    /// When the user last changed any alarm setting. Occurrences that began
    /// before this moment don't count — setting your alarm to a time in the
    /// recent past must not ambush you into ringing mode.
    /// Schema-level default keeps migration from older stores lightweight.
    var armedAt: Date = Date.distantPast
    /// Mornings in a row the worm was won. A plain tally: a victory clicks it
    /// up by one, and the counter on the nightstand can be clicked or reset
    /// by hand. Schema-level default so older stores migrate in place.
    var streak: Int = 0

    init(hour: Int = 7, minute: Int = 0, weekdays: [Int] = [2, 3, 4, 5, 6], isEnabled: Bool = false) {
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.mainAlarmID = nil
        self.backupAlarmIDs = []
        self.chainOccurrence = nil
        self.lastVictoryDate = nil
        self.armedAt = .now
        self.streak = 0
    }

    var allAlarmIDs: [UUID] {
        (mainAlarmID.map { [$0] } ?? []) + backupAlarmIDs
    }
}
