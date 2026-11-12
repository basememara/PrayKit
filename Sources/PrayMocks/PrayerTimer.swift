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
        at date: Date = .now,
        prayerDay: PrayerDay = .mock(),
        iqamaTimes: IqamaTimes? = nil,
        isIqamaTimerEnabled: Bool = true,
        stopwatchMinutes: Int = 5,
        preAdhanMinutes: PreAdhanMinutes = PreAdhanMinutes(rawValue: [:]),
        sunriseAfterIsha: Bool = false
    ) -> PrayerTimer? {
        PrayerTimer(
            at: date,
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

        // A day with nothing under way at this moment has no timer, so a sample hour around it stands in
        guard let prayerTimer = placeholder(at: date, using: prayerDay, preAdhanMinutes: PreAdhanMinutes(rawValue: [:]))
            ?? placeholder(at: date, using: .sampleHour(around: date), preAdhanMinutes: PreAdhanMinutes(rawValue: [Prayer.asr.rawValue: 30]))
        else {
            preconditionFailure("The sample hour has a prayer under way and one to come at its own moment, so it has a timer")
        }

        return prayerTimer
    }
}

private extension PrayerTimer {
    static func placeholder(at date: Date, using prayerDay: PrayerDay, preAdhanMinutes: PreAdhanMinutes) -> PrayerTimer? {
        PrayerTimer(
            at: date,
            using: prayerDay,
            iqamaTimes: IqamaTimes(),
            isIqamaTimerEnabled: false,
            stopwatchMinutes: 0,
            preAdhanMinutes: preAdhanMinutes,
            sunriseAfterIsha: false,
            timeZone: .current,
            isPlaceholder: true
        )
    }
}

private extension PrayerDay {
    /// Dhuhr half over at the moment and Asr an hour after it, with a reminder zone a quarter of Dhuhr long.
    static func sampleHour(around date: Date) -> PrayerDay {
        PrayerDay(
            date: date.startOfDay(using: .current),
            times: [
                PrayerTime(type: .dhuhr, dateInterval: DateInterval(start: date - .hours(1), end: date + .hours(1))),
                PrayerTime(type: .asr, dateInterval: DateInterval(start: date + .hours(1), end: date + .hours(2)))
            ],
            tomorrow: []
        )
    }
}
