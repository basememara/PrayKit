//
//  PrayerTime+Night.swift
//  PrayServices
//
//  Created by Basem Emara on 2026-10-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore

extension PrayerTime {
    /// The middle and the last third of the night, which runs from Maghrib to the Fajr actually used, so the last third
    /// ends where Isha does; none when the night is too short to order them, which leaves the day's prayers whole.
    static func night(from maghrib: Date, to fajr: Date) -> [PrayerTime] {
        let duration = fajr.timeIntervalSince(maghrib)
        let middle = maghrib.addingTimeInterval(duration / 2).roundedMinute
        let lastThird = maghrib.addingTimeInterval(duration * 2 / 3).roundedMinute

        guard middle < lastThird, lastThird < fajr else { return [] }

        return [
            PrayerTime(type: .midnight, dateInterval: DateInterval(start: middle, end: lastThird)),
            PrayerTime(type: .lastThird, dateInterval: DateInterval(start: lastThird, end: fajr))
        ]
    }
}

extension Date {
    /// The nearest whole minute, as the Adhan library rounds; on the instant itself, so a time in the hour that
    /// repeats when clocks go back keeps its own occurrence.
    var roundedMinute: Date {
        Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate / 60).rounded() * 60)
    }
}
