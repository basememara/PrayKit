//
//  PrayerTimer.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-11-26.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation.NSCalendar
import Foundation.NSDateInterval
import ZamzamCore

public struct PrayerTimer: Equatable, Codable {
    public let date: Date
    public let type: Prayer
    public let timerType: TimerType
    public let prayerDay: PrayerDay
    public let countdownDate: Date
    public let khutbaTime: Date?
    public let timeRange: ClosedRange<Date>
    public let timeRemaining: TimeInterval
    public let timeDuration: TimeInterval
    public let progressRemaining: Double
    public let dangerZone: Double
    public let isDangerZone: Bool
    public let isJumuah: Bool
    public let localizeAt: Date?

    public init(
        date: Date,
        type: Prayer,
        timerType: PrayerTimer.TimerType,
        prayerDay: PrayerDay,
        countdownDate: Date,
        khutbaTime: Date?,
        timeRange: ClosedRange<Date>,
        timeRemaining: TimeInterval,
        timeDuration: TimeInterval,
        progressRemaining: Double,
        dangerZone: Double,
        isDangerZone: Bool,
        isJumuah: Bool,
        localizeAt: Date? = nil
    ) {
        self.date = date
        self.type = type
        self.timerType = timerType
        self.prayerDay = prayerDay
        self.countdownDate = countdownDate
        self.khutbaTime = khutbaTime
        self.timeRange = timeRange
        self.timeRemaining = timeRemaining
        self.timeDuration = timeDuration
        self.progressRemaining = progressRemaining
        self.dangerZone = dangerZone
        self.isDangerZone = isDangerZone
        self.isJumuah = isJumuah
        self.localizeAt = localizeAt
    }
}

public extension PrayerTimer {
    init?(
        at date: Date,
        using prayerDay: PrayerDay,
        iqamaTimes: IqamaTimes,
        isIqamaTimerEnabled: Bool,
        stopwatchMinutes: Int,
        preAdhanMinutes: PreAdhanMinutes,
        sunriseAfterIsha: Bool,
        timeZone: TimeZone
    ) {
        guard let currentPrayer = prayerDay.current(at: date),
              let nextPrayer = prayerDay.next(at: date, sunriseAfterIsha: sunriseAfterIsha)
        else {
            return nil
        }

        let preAdhanMinutes = preAdhanMinutes[currentPrayer.type]
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        // Declare iqama time if applicable
        var iqamaTime: Date?
        if isIqamaTimerEnabled,
           let currentIqama = iqamaTimes[currentPrayer, using: calendar],
           currentPrayer.dateInterval.start.isIqamaTimer(at: date, iqamaTime: currentIqama) {
            iqamaTime = currentIqama
        }

        // Determine stopwatch state
        let isStopwatchTimer: Bool
        switch (
            currentPrayer.dateInterval.start.isStopwatchTimer(at: date, minutes: stopwatchMinutes),
            currentPrayer.type,
            iqamaTime
        ) {
        case (_, .sunrise, _):
            isStopwatchTimer = false
        case (_, .maghrib, .some):
            isStopwatchTimer = false
        case let (value, _, _):
            isStopwatchTimer = value
        }

        // Set countdown details
        var timerType = isStopwatchTimer ? TimerType.stopwatch : iqamaTime != nil ? .iqama : .countdown
        var prayerTime = [.stopwatch, .iqama].contains(timerType) ? currentPrayer : nextPrayer
        var countdownDate = timerType == .iqama ? iqamaTime ?? .now : prayerTime.dateInterval.start
        var currentDateInterval = currentPrayer.dateInterval
        var countdownLocalizeAt: Date? = date

        // Handle jumuah if appliable
        if date.isJumuah(using: calendar),
           [currentPrayer.type, nextPrayer.type].contains(.dhuhr),
           let khutbaIqama = iqamaTimes[currentPrayer.type == .dhuhr ? currentPrayer : nextPrayer, using: calendar]
        {
            if isStopwatchTimer && currentPrayer.type == .dhuhr {
                currentDateInterval = DateInterval(start: currentPrayer.dateInterval.start, end: khutbaIqama)
                countdownLocalizeAt = nil
            } else if khutbaIqama.isStopwatchTimer(at: date, minutes: stopwatchMinutes) {
                currentDateInterval = DateInterval(start: khutbaIqama, end: nextPrayer.dateInterval.start)
                prayerTime = currentPrayer
                countdownDate = khutbaIqama
                timerType = .stopwatch
            } else if prayerTime.type == .asr {
                currentDateInterval = DateInterval(start: khutbaIqama, end: nextPrayer.dateInterval.start)
            } else {
                currentDateInterval = DateInterval(start: currentPrayer.dateInterval.start, end: khutbaIqama)
                countdownDate = khutbaIqama
                timerType = .iqama
            }
        } else if sunriseAfterIsha,
                  currentPrayer.type == .isha,
                  prayerTime.type != .isha,
                  let fajrPrayerTime = prayerDay.times[.fajr],
                  let fajrIqama = iqamaTimes[fajrPrayerTime, using: calendar] {
            prayerTime = fajrPrayerTime
            countdownDate = fajrIqama < currentPrayer.dateInterval.start ? fajrIqama + .days(1, calendar) : fajrIqama
            currentDateInterval = DateInterval(start: currentPrayer.dateInterval.start, end: countdownDate)
            timerType = .iqama
        }

        let progress = currentDateInterval.progress(at: date).value
        let progressRemaining = 1 - progress
        let dangerZone = min(1, Double(max(preAdhanMinutes, 60) * 60) / currentDateInterval.duration) // Pre-adhan zone or less than an hour
        let isJumuah = date.isJumuah(using: calendar) && prayerTime.type == .dhuhr
        let khutbaTime = date.isJumuah(using: calendar) ? prayerDay.times[.dhuhr].map { iqamaTimes[$0, using: calendar] } ?? nil : nil

        self.init(
            date: date,
            type: prayerTime.type,
            timerType: timerType,
            prayerDay: prayerDay,
            countdownDate: countdownDate,
            khutbaTime: khutbaTime,
            timeRange: min(date, countdownDate)...max(date, countdownDate),
            timeRemaining: countdownDate.timeIntervalSince(date),
            timeDuration: currentDateInterval.duration,
            progressRemaining: 1 - progress,
            dangerZone: dangerZone,
            isDangerZone: timerType != .stopwatch ? progressRemaining <= dangerZone : false,
            isJumuah: isJumuah,
            localizeAt: countdownLocalizeAt
        )
    }
}

public extension PrayerTimer {
    init?(at date: Date, using prayerDay: PrayerDay?, preferences: Preferences) {
        guard let prayerDay else { return nil }

        self.init(
            at: date,
            using: prayerDay,
            iqamaTimes: preferences.iqamaTimes,
            isIqamaTimerEnabled: preferences.isIqamaTimerEnabled,
            stopwatchMinutes: preferences.stopwatchMinutes,
            preAdhanMinutes: preferences.preAdhanMinutes,
            sunriseAfterIsha: preferences.sunriseAfterIsha,
            timeZone: preferences.lastTimeZone
        )
    }
}

// MARK: - Types

public extension PrayerTimer {
    enum TimerType: String, Equatable, Codable {
        case countdown
        case stopwatch
        case iqama
    }
}

// MARK: - Helpers

private extension Date {
    /// Determines if the prayer is within the stopwatch timer threshold with a small buffer.
    func isStopwatchTimer(at date: Date, minutes: Int) -> Bool {
        guard minutes > 0 else { return false }
        return date.isBetween(self - 2, self + .minutes(minutes) - 10)
    }

    /// Determines if the prayer is within the iqama timer threshold with a small buffer.
    func isIqamaTimer(at date: Date, iqamaTime: Date) -> Bool {
        guard self < iqamaTime else { return false }
        return date.isBetween(self - 2, iqamaTime - 10)
    }
}

// MARK: - Conformances

#if canImport(WidgetKit)
import WidgetKit

extension PrayerTimer: TimelineEntry {}
#endif
