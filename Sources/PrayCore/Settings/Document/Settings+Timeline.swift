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
    /// The moments in a prayer's window when its countdown changes: the start, the reminder before it, the
    /// iqama and the stopwatch after it.
    func expandedTimeline(for prayerTime: PrayerTime, using calendar: Calendar) -> [Date] {
        Self.expandedTimeline(
            for: prayerTime,
            preAdhanMinutes: preAdhanMinutes,
            iqamaTimes: iqamaTimes,
            isIqamaTimerEnabled: isIqamaTimerEnabled,
            stopwatchMinutes: stopwatchMinutes,
            using: calendar
        )
    }
}

extension Settings {
    static func expandedTimeline(
        for prayerTime: PrayerTime,
        preAdhanMinutes: PreAdhanMinutes,
        iqamaTimes: IqamaTimes,
        isIqamaTimerEnabled: Bool,
        stopwatchMinutes: Int,
        using calendar: Calendar
    ) -> [Date] {
        let start = prayerTime.dateInterval.start
        let duration = prayerTime.dateInterval.duration
        let reminderMinutes = preAdhanMinutes[prayerTime.type]

        return [
            start,
            reminderMinutes > 0 && duration > Double(reminderMinutes) * 60 ? start - .minutes(reminderMinutes) : nil,
            isIqamaTimerEnabled ? iqamaTimes[prayerTime, using: calendar] : nil,
            stopwatchMinutes > 0 && duration > Double(stopwatchMinutes) * 60 ? start + .minutes(stopwatchMinutes) : nil
        ]
        .compactMap { $0 }
        .removeDuplicates()
        .sorted()
    }
}
