//
//  Settings+Timeline.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import ZamzamCore

public extension Settings {
    /// The iqama a timer counts to for a prayer, which the iqama timer setting turns off; see `IqamaTimes.timerIqama`.
    func timerIqama(for prayerTime: PrayerTime, using calendar: Calendar) -> Date? {
        iqamaTimes.timerIqama(for: prayerTime, isTimerEnabled: isIqamaTimerEnabled, using: calendar)
    }

    /// The moments in a prayer's window when its countdown changes: the start, the reminder before it, the
    /// iqama and the stopwatch after it. On a Friday whose khutba the iqama timer counts to, the reminder is counted
    /// back from the khutba instead, and the khutba starts a stopwatch.
    func expandedTimeline(for prayerTime: PrayerTime, using calendar: Calendar) -> [Date] {
        let start = prayerTime.dateInterval.start
        let duration = prayerTime.dateInterval.duration
        let reminderMinutes = preAdhanMinutes[prayerTime.type]
        let iqama = timerIqama(for: prayerTime, using: calendar)
        let khutba = prayerTime.isJumuah(using: calendar) ? iqama : nil

        // The count to the khutba runs from sunrise's adhan, so its warning begins inside it even before Dhuhr's adhan
        let reminder: Date? = if let khutba {
            khutba - .minutes(reminderMinutes)
        } else if duration > Double(reminderMinutes) * 60 {
            start - .minutes(reminderMinutes)
        } else {
            nil
        }

        return [
            start,
            reminderMinutes > 0 ? reminder : nil,
            iqama,
            stopwatchMinutes > 0 && duration > Double(stopwatchMinutes) * 60 ? start + .minutes(stopwatchMinutes) : nil,
            stopwatchMinutes > 0 ? khutba.map { $0 + .minutes(stopwatchMinutes) } : nil
        ]
        .compactMap(\.self)
        .removeDuplicates()
        .sorted()
    }
}
