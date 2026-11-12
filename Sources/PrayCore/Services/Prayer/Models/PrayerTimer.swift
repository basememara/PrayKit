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

public struct PrayerTimer: Equatable, Codable, Sendable {
    public let date: Date
    public let type: Prayer
    public let timerType: TimerType
    public let prayerDay: PrayerDay
    public let countdownDate: Date
    public let timeRange: ClosedRange<Date>
    public let timeRemaining: TimeInterval
    public let timeDuration: TimeInterval
    public let progressRemaining: Double
    public let dangerZone: Double
    public let isDangerZone: Bool
    public let isJumuah: Bool
    /// The place's zone, which its times read in, rather than the device's
    public let timeZone: TimeZone
    /// Whether the face names the prayer Jumuah: Friday's Dhuhr, except while its stopwatch runs before the khutba.
    public let isNamedJumuah: Bool
    /// When the count-up after the adhan stops, while it runs.
    public let stopwatchEnd: Date?
    /// When the day's lists turn to tomorrow's; see `PrayerDay.turnover`.
    public let turnover: Date?
    /// Sample or fallback data that widget views must render redacted, never as real times
    public let isPlaceholder: Bool

    public init(
        date: Date,
        type: Prayer,
        timerType: PrayerTimer.TimerType,
        prayerDay: PrayerDay,
        countdownDate: Date,
        timeRange: ClosedRange<Date>,
        timeRemaining: TimeInterval,
        timeDuration: TimeInterval,
        progressRemaining: Double,
        dangerZone: Double,
        isDangerZone: Bool,
        isJumuah: Bool,
        timeZone: TimeZone,
        isNamedJumuah: Bool = false,
        stopwatchEnd: Date? = nil,
        turnover: Date? = nil,
        isPlaceholder: Bool = false
    ) {
        self.date = date
        self.type = type
        self.timerType = timerType
        self.prayerDay = prayerDay
        self.countdownDate = countdownDate
        self.timeRange = timeRange
        self.timeRemaining = timeRemaining
        self.timeDuration = timeDuration
        self.progressRemaining = progressRemaining
        self.dangerZone = dangerZone
        self.isDangerZone = isDangerZone
        self.isJumuah = isJumuah
        self.timeZone = timeZone
        self.isNamedJumuah = isNamedJumuah
        self.stopwatchEnd = stopwatchEnd
        self.turnover = turnover
        self.isPlaceholder = isPlaceholder
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
        timeZone: TimeZone,
        isPlaceholder: Bool = false
    ) {
        guard let currentPrayer = prayerDay.current(at: date),
              let nextPrayer = prayerDay.next(at: date, sunriseAfterIsha: sunriseAfterIsha)
        else {
            return nil
        }

        let preAdhanMinutes = preAdhanMinutes[nextPrayer.type]
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)

        let currentIqama = isIqamaTimerEnabled ? iqamaTimes[currentPrayer, using: calendar] : nil
        let iqamaTime = currentIqama.flatMap { currentPrayer.dateInterval.start.isIqamaTimer(at: date, iqamaTime: $0) ? $0 : nil }

        // A prayer with an iqama never counts up, even once its iqama has passed
        let isStopwatchTimer = currentIqama == nil
            && currentPrayer.type != .sunrise
            && currentPrayer.dateInterval.start.isStopwatchTimer(at: date, minutes: stopwatchMinutes)

        // Set countdown details
        var timerType = isStopwatchTimer ? TimerType.stopwatch : iqamaTime != nil ? .iqama : .countdown
        var prayerTime = [.stopwatch, .iqama].contains(timerType) ? currentPrayer : nextPrayer
        var countdownDate = timerType == .iqama ? iqamaTime ?? .now : prayerTime.dateInterval.start
        var currentDateInterval = currentPrayer.dateInterval
        var isDhuhrStopwatchOnFriday = false
        var hasPreAdhanZone = true

        // Jumuah is Friday's Dhuhr, judged by that prayer's own date rather than the moment's
        if let dhuhr = [currentPrayer, nextPrayer].first(where: { $0.type == .dhuhr }),
           dhuhr.dateInterval.start.isJumuah(using: calendar),
           let khutbaIqama = iqamaTimes[dhuhr, using: calendar] {
            if isStopwatchTimer, currentPrayer.type == .dhuhr {
                currentDateInterval = DateInterval(start: currentPrayer.dateInterval.start, end: khutbaIqama)
                isDhuhrStopwatchOnFriday = true
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
                  let fajrPrayerTime = (prayerDay.times + prayerDay.tomorrow).first(where: { $0.type == .fajr && $0.dateInterval.start >= currentPrayer.dateInterval.end }),
                  let fajrIqama = iqamaTimes[fajrPrayerTime, using: calendar] {
            prayerTime = fajrPrayerTime
            countdownDate = fajrIqama
            currentDateInterval = DateInterval(start: currentPrayer.dateInterval.start, end: countdownDate)
            timerType = .iqama
        } else if let currentIqama,
                  currentIqama > currentPrayer.dateInterval.start,
                  currentIqama < nextPrayer.dateInterval.start {
            if timerType == .iqama {
                currentDateInterval = DateInterval(start: currentPrayer.dateInterval.start, end: currentIqama)
                hasPreAdhanZone = false
            } else if timerType == .countdown, date >= currentIqama {
                currentDateInterval = DateInterval(start: currentIqama, end: nextPrayer.dateInterval.start)
            }
        }

        let progressRemaining = 1 - currentDateInterval.progress(at: date).value
        let dangerSeconds = hasPreAdhanZone ? Double(preAdhanMinutes * 60) : 0
        let dangerZone = hasPreAdhanZone ? min(1, dangerSeconds / currentDateInterval.duration) : 0
        let isJumuah = prayerTime.isJumuah(using: calendar)

        self.init(
            date: date,
            type: prayerTime.type,
            timerType: timerType,
            prayerDay: prayerDay,
            countdownDate: countdownDate,
            timeRange: min(date, countdownDate)...max(date, countdownDate),
            timeRemaining: countdownDate.timeIntervalSince(date),
            timeDuration: currentDateInterval.duration,
            progressRemaining: progressRemaining,
            dangerZone: dangerZone,
            // By the seconds left: the two ratios round apart at the reminder's own moment
            isDangerZone: timerType != .stopwatch && currentDateInterval.end.timeIntervalSince(date) <= dangerSeconds,
            isJumuah: isJumuah,
            timeZone: timeZone,
            isNamedJumuah: isJumuah && !isDhuhrStopwatchOnFriday,
            stopwatchEnd: timerType == .stopwatch ? countdownDate + .minutes(stopwatchMinutes) : nil,
            turnover: prayerDay.turnover(iqamaTimes: iqamaTimes, isIqamaTimerEnabled: isIqamaTimerEnabled, stopwatchMinutes: stopwatchMinutes, using: calendar),
            isPlaceholder: isPlaceholder
        )
    }
}

public extension PrayerTimer {
    /// A timer from the settings, counting in the place's time zone.
    init?(at date: Date, using prayerDay: PrayerDay?, settings: Settings, timeZone: TimeZone) {
        guard let prayerDay else { return nil }

        self.init(
            at: date,
            using: prayerDay,
            iqamaTimes: settings.iqamaTimes,
            isIqamaTimerEnabled: settings.isIqamaTimerEnabled,
            stopwatchMinutes: settings.stopwatchMinutes,
            preAdhanMinutes: settings.preAdhanMinutes,
            sunriseAfterIsha: settings.sunriseAfterIsha,
            timeZone: timeZone
        )
    }
}

public extension PrayerTimer {
    /// Whether the day's lists have turned to tomorrow's, once its turnover has passed.
    var listsTomorrow: Bool {
        turnover.map { date >= $0 } ?? false
    }

    /// The day a face lists: this one until its turnover, then the next.
    var listedDay: PrayerDay {
        listsTomorrow ? prayerDay.dayAfter(using: Calendar(identifier: .gregorian, timeZone: timeZone)) : prayerDay
    }

    var listedTimes: [PrayerTime] {
        listedDay.times
    }

    /// The listed day's rows at the timer's moment.
    var listed: [ListedPrayer] {
        listedDay.listed(at: date)
    }
}

// MARK: - Types

public extension PrayerTimer {
    enum TimerType: String, Equatable, Codable, Sendable {
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

extension PrayerTimer: TimelineEntry {
    /// Smart Stack relevance: obligatory prayers surface from 15 minutes before until 45 minutes
    /// after they start, sunrise for the 20 minutes before it as the Fajr deadline.
    public var relevance: TimelineEntryRelevance? {
        guard type.isObligation || type == .sunrise else { return nil }

        let windowStart = type == .sunrise ? countdownDate - .minutes(20) : countdownDate - .minutes(15)
        let windowEnd = type == .sunrise ? countdownDate : countdownDate + .minutes(45)
        guard date >= windowStart, date <= windowEnd else { return nil }

        return TimelineEntryRelevance(score: 100, duration: max(0, windowEnd.timeIntervalSince(date)))
    }
}
#endif
