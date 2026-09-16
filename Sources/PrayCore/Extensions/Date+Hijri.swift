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
    func hijriDayOffset(
        for prayerDay: PrayerDay?,
        hijriDayOffset: Int,
        autoIncrementHijri: Bool,
        timeZone: TimeZone
    ) -> Int {
        // The day boundary belongs to the prayer location, not the device's current calendar
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)

        guard autoIncrementHijri,
              let prayerTime = prayerDay?.current(at: self),
              [.maghrib, .isha].contains(prayerTime.type),
              prayerTime.dateInterval.start.inSameDay(as: self, using: calendar)
        else {
            return hijriDayOffset
        }

        return hijriDayOffset + 1
    }
}
