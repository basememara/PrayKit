//
//  PrayerTime+Display.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-02-13.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate

public extension PrayerTime {
    /// Determines if the prayer is within the iqama time threshold with a small buffer.
    func isBeforeIqama(at date: Date, iqamaTime: Date?) -> Bool {
        guard let iqamaTime else { return false }
        return date.isBetween(dateInterval.start - 2, iqamaTime - 10)
    }
}

public extension PrayerTime {
    /// Determines if the prayer time is within the danger zone of running out of time.
    func dangerThreshold(preAdhanMinutes: PreAdhanMinutes) -> Double {
        max(1 - (dateInterval.duration - Double(preAdhanMinutes[type] * 60)) / dateInterval.duration, 0.25)
    }
}
