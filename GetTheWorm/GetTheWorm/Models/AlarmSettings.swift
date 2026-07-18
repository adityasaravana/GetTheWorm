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
    /// Last time the user successfully photographed grass.
    var lastVictoryDate: Date?

    init(hour: Int = 7, minute: Int = 0, weekdays: [Int] = [2, 3, 4, 5, 6], isEnabled: Bool = false) {
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.mainAlarmID = nil
        self.backupAlarmIDs = []
        self.lastVictoryDate = nil
    }

    var allAlarmIDs: [UUID] {
        (mainAlarmID.map { [$0] } ?? []) + backupAlarmIDs
    }
}
