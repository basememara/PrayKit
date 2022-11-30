//
//  PrayerTimer.swift
//  PrayMocks
//
//  Created by Basem Emara on 2022-11-30.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate
import PrayCore

public extension PrayerTimer {
    static func mock(
        at date: Date? = nil,
        prayerDay: PrayerDay = .mock(),
        iqamaTimes: IqamaTimes? = nil,
        isIqamaTimerEnabled: Bool = true,
        stopwatchMinutes: Int = 5,
        preAdhanMinutes: PreAdhanMinutes = PreAdhanMinutes(rawValue: [:]),
        sunriseAfterIsha: Bool = false
    ) -> PrayerTimer? {
        PrayerTimer(
            at: date ?? prayerDay.date,
            using: prayerDay,
            iqamaTimes: iqamaTimes ?? IqamaTimes(
                fajr: .minutes(26),
                dhuhr: .minutes(26),
                asr: .minutes(26),
                maghrib: .minutes(26),
                isha: .minutes(26),
                jumuah: .time(hour: 13, minutes: 30)
            ),
            isIqamaTimerEnabled: isIqamaTimerEnabled,
            stopwatchMinutes: stopwatchMinutes,
            preAdhanMinutes: preAdhanMinutes,
            sunriseAfterIsha: sunriseAfterIsha,
            timeZone: .current
        )
    }
}
