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
    /// ends where Isha does; `nil` when the night is too short to order them.
    static func night(from maghrib: Date, to fajr: Date, using calendar: Calendar) -> [PrayerTime]? {
        let duration = fajr.timeIntervalSince(maghrib)
        let middle = maghrib.addingTimeInterval(duration / 2).roundedMinute(using: calendar)
        let lastThird = maghrib.addingTimeInterval(duration * 2 / 3).roundedMinute(using: calendar)

        guard middle < lastThird, lastThird < fajr else { return nil }

        return [
            PrayerTime(type: .midnight, dateInterval: DateInterval(start: middle, end: lastThird)),
            PrayerTime(type: .lastThird, dateInterval: DateInterval(start: lastThird, end: fajr))
        ]
    }
}

extension Date {
    /// The nearest whole minute, as the Adhan library rounds.
    func roundedMinute(using calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        components.minute = Int(minute + round(second / 60))
        components.second = 0
        return calendar.date(from: components) ?? self
    }
}
