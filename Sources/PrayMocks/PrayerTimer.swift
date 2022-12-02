//
//  PrayerTimer.swift
//  PrayMocks
//
//  Created by Basem Emara on 2022-11-30.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate
import PrayCore
import ZamzamCore

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

public extension PrayerTimer {
    static func placeholder(from prayerDay: PrayerDay) -> PrayerTimer {
        let date = Date.now

        guard let prayerTimer = PrayerTimer(
            at: date,
            using: prayerDay,
            iqamaTimes: IqamaTimes(),
            isIqamaTimerEnabled: false,
            stopwatchMinutes: 0,
            preAdhanMinutes: PreAdhanMinutes(rawValue: [:]),
            sunriseAfterIsha: false,
            timeZone: .current
        ) else {
            let countdownDate = Date.now + .hours(1)
            return PrayerTimer(
                date: date,
                type: .asr,
                timerType: .countdown,
                prayerDay: prayerDay,
                countdownDate: countdownDate,
                khutbaTime: nil,
                timeRange: date...countdownDate,
                timeRemaining: countdownDate.timeIntervalSince(date),
                timeDuration: DateInterval(start: date, end: countdownDate).duration,
                progressRemaining: 0.5,
                dangerZone: 0.25,
                isDangerZone: false,
                isJumuah: false,
                localizeAt: nil
            )
        }

        return prayerTimer
    }
}
