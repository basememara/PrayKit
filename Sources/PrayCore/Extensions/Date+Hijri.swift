//
//  Date+Hijri.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-03-17.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate
import ZamzamCore

public extension Date {
    func hijriString(
        for prayerDay: PrayerDay?,
        hijriDayOffset: Int,
        autoIncrementHijri: Bool,
        timeZone: TimeZone,
        template: String = "yyyyMMMMd"
    ) -> String {
        hijriString(
            template: template,
            offSet: self.hijriDayOffset(
                for: prayerDay,
                hijriDayOffset: hijriDayOffset,
                autoIncrementHijri: autoIncrementHijri,
                timeZone: timeZone
            ),
            timeZone: timeZone
        )
    }
}

public extension Date {
    /// The days to add to this instant's calendar date for its Hijri date. With auto-increment, the Hijri day turns at
    /// Maghrib rather than midnight, so it counts from the date of the prayer day holding the instant, a day on once
    /// that day's Maghrib has begun, whichever side of midnight the instant falls.
    func hijriDayOffset(
        for prayerDay: PrayerDay?,
        hijriDayOffset: Int,
        autoIncrementHijri: Bool,
        timeZone: TimeZone
    ) -> Int {
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)

        guard autoIncrementHijri,
              let prayerDay,
              prayerDay.contains(self),
              let daysPastPrayerDay = calendar.dateComponents([.day], from: prayerDay.date, to: calendar.startOfDay(for: self)).day
        else {
            return hijriDayOffset
        }

        let hasMaghribBegun = prayerDay.times[.maghrib].map { self >= $0.dateInterval.start } ?? false
        return hijriDayOffset + (hasMaghribBegun ? 1 : 0) - daysPastPrayerDay
    }
}
