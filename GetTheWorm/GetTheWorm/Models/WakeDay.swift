//
//  WakeDay.swift
//  GetTheWorm
//

import Foundation
import SwiftData

/// One calendar day's wake-up outcome. The source of truth for streaks and
/// the (future) paper calendar.
///
/// Keyed by the local start of the day the alarm *occurrence* belonged to,
/// not the moment the photo was taken — an 11:50 PM alarm defeated at
/// 12:04 AM still counts for the evening it rang.
@Model
final class WakeDay {
    enum Source: String {
        /// Earned the honest way: grass photographed inside the ringing window.
        case grass
        /// Set by hand on the calendar.
        case manual
    }

    /// Start of day in the calendar that was current when it was recorded.
    @Attribute(.unique) var day: Date
    var wokeUp: Bool
    /// Stored as the raw string so adding cases later never needs a migration.
    var sourceRaw: String
    var recordedAt: Date

    var source: Source {
        get { Source(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(day: Date, wokeUp: Bool, source: Source, recordedAt: Date = .now) {
        self.day = day
        self.wokeUp = wokeUp
        self.sourceRaw = source.rawValue
        self.recordedAt = recordedAt
    }
}
