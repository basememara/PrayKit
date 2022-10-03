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
        using preferences: Preferences,
        timeZone: TimeZone? = nil,
        template: String = "yyyyMMMMd"
    ) -> String {
        hijriString(
            template: template,
            offSet: preferences.hijriDayOffset(for: prayerDay, at: self),
            timeZone: timeZone ?? preferences.lastTimeZone
        )
    }
}

public extension Preferences {
    func hijriDayOffset(for prayerDay: PrayerDay?, at time: Date) -> Int {
        guard autoIncrementHijri,
              let prayerTime = prayerDay?.current(at: time),
              [.maghrib, .isha].contains(prayerTime.type),
              prayerTime.dateInterval.start.inSameDay(as: time)
        else {
            return hijriDayOffset
        }

        return hijriDayOffset + 1
    }
}
