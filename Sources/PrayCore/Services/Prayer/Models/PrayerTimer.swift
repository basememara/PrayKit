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

public struct PrayerTimer: Equatable, Sendable {
    public let date: Date
    public let prayerDay: PrayerDay
    /// The place's zone, which its times read in, rather than the device's
    public let timeZone: TimeZone
    /// When the day's lists turn to tomorrow's; see `PrayerDay.turnover`.
    public let turnover: Date?
    /// Sample or fallback data that widget views must render redacted, never as real times
    public let isPlaceholder: Bool
    /// What it counts to or up from at its moment; the rest of what a face reads follows from it and the moment.
    private let phase: Phase
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
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)

        guard let phase = Phase.decided(
            at: date,
            in: prayerDay,
            iqamaTimes: iqamaTimes,
            isIqamaTimerEnabled: isIqamaTimerEnabled,
            stopwatchMinutes: stopwatchMinutes,
            preAdhanMinutes: preAdhanMinutes,
            sunriseAfterIsha: sunriseAfterIsha,
            using: calendar
        ) else {
            return nil
        }

        self.init(
            date: date,
            prayerDay: prayerDay,
            timeZone: timeZone,
            turnover: prayerDay.turnover(iqamaTimes: iqamaTimes, isIqamaTimerEnabled: isIqamaTimerEnabled, stopwatchMinutes: stopwatchMinutes, using: calendar),
            isPlaceholder: isPlaceholder,
            phase: phase
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

// MARK: - What a face reads

public extension PrayerTimer {
    /// The prayer counted to, or counted up from.
    var type: Prayer { phase.prayerTime.type }

    var timerType: TimerType {
        switch phase.kind {
        case .countdown:
            .countdown
        case .iqama:
            .iqama
        case .countUp:
            .stopwatch
        }
    }

    /// The adhan, iqama or khutba counted to, or the one counted up from.
    var countdownDate: Date { phase.target }
    var timeRemaining: TimeInterval { countdownDate.timeIntervalSince(date) }
    var timeDuration: TimeInterval { phase.span.duration }
    var progressRemaining: Double { 1 - phase.span.progress(at: date).value }

    /// The share of the span its reminder covers.
    var dangerZone: Double { min(1, phase.warningSeconds / phase.span.duration) }

    // By the seconds left: the two ratios round apart at the reminder's own moment
    var isDangerZone: Bool { timerType != .stopwatch && phase.span.end.timeIntervalSince(date) <= phase.warningSeconds }

    var isJumuah: Bool { phase.prayerTime.isJumuah(using: Calendar(identifier: .gregorian, timeZone: timeZone)) }

    /// When the count-up after the adhan stops, while it runs.
    var stopwatchEnd: Date? {
        if case let .countUp(end) = phase.kind { end } else { nil }
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

// MARK: - Phase

private extension PrayerTimer {
    /// What a timer counts to or up from at a moment: the one decision its initializer makes.
    struct Phase: Equatable, Sendable {
        let prayerTime: PrayerTime
        let kind: Kind
        let target: Date
        /// The stretch of time the progress runs over.
        let span: DateInterval
        /// The reminder before the span ends; the count to a prayer's own iqama has none.
        let warningSeconds: Double

        enum Kind: Equatable, Sendable {
            case countdown
            case iqama
            case countUp(end: Date)
        }
    }
}

private extension PrayerTimer.Phase {
    /// The phase at a moment, or `nil` when the day has no prayer under way then or none to come. Its cases are
    /// tried in this order and the first that holds wins, so a Friday's khutba outranks Fajr's iqama after Isha,
    /// which outranks the prayer's own iqama.
    static func decided(
        at date: Date,
        in prayerDay: PrayerDay,
        iqamaTimes: IqamaTimes,
        isIqamaTimerEnabled: Bool,
        stopwatchMinutes: Int,
        preAdhanMinutes: PreAdhanMinutes,
        sunriseAfterIsha: Bool,
        using calendar: Calendar
    ) -> Self? {
        guard let current = prayerDay.current(at: date),
              let next = prayerDay.next(at: date, sunriseAfterIsha: sunriseAfterIsha)
        else {
            return nil
        }

        let adhan = current.dateInterval.start
        let nextAdhan = next.dateInterval.start
        // A warning is as long as the reminder of the prayer counted to: the next prayer's before its adhan, which a
        // count-up carries too, and Dhuhr's before the khutba
        func reminderSeconds(of prayerTime: PrayerTime) -> Double {
            Double(preAdhanMinutes[prayerTime.type] * 60)
        }

        func timerIqama(for prayerTime: PrayerTime) -> Date? {
            iqamaTimes.timerIqama(for: prayerTime, isTimerEnabled: isIqamaTimerEnabled, using: calendar)
        }

        let warningSeconds = reminderSeconds(of: next)
        let currentIqama = timerIqama(for: current)
        let iqama = currentIqama.flatMap { adhan.isIqamaTimer(at: date, iqamaTime: $0) ? $0 : nil }
        // A prayer with an iqama never counts up, even once its iqama has passed
        let countsUp = currentIqama == nil && current.type != .sunrise && adhan.isStopwatchTimer(at: date, minutes: stopwatchMinutes)

        func countUp(from start: Date) -> Kind {
            .countUp(end: start + .minutes(stopwatchMinutes))
        }

        // An ordinary moment, over the prayer under way: up from its adhan, down to its iqama, or down to the next adhan.
        // The cases below keep it, change its span, or replace it
        let ordinary = switch (countsUp, iqama) {
        case (true, _):
            Self(prayerTime: current, kind: countUp(from: adhan), target: adhan, span: current.dateInterval, warningSeconds: warningSeconds)
        case let (false, iqama?):
            Self(prayerTime: current, kind: .iqama, target: iqama, span: current.dateInterval, warningSeconds: warningSeconds)
        case (false, nil):
            Self(prayerTime: next, kind: .countdown, target: nextAdhan, span: current.dateInterval, warningSeconds: warningSeconds)
        }

        // 1. A Friday with a khutba set and the iqama timer on; with it off, Friday runs as any other day. Jumuah is
        // Friday's Dhuhr, judged by that prayer's own date rather than the moment's
        if let dhuhr = [current, next].first(where: { $0.type == .dhuhr }),
           dhuhr.dateInterval.start.isJumuah(using: calendar),
           let khutba = timerIqama(for: dhuhr) {
            // Up from the khutba, over the khutba to the next adhan
            if khutba.isStopwatchTimer(at: date, minutes: stopwatchMinutes) {
                let afterKhutba = DateInterval(start: khutba, end: nextAdhan)
                return Self(prayerTime: current, kind: countUp(from: khutba), target: khutba, span: afterKhutba, warningSeconds: warningSeconds)
            }

            // Down to Asr, over the khutba to Asr
            if ordinary.prayerTime.type == .asr {
                return ordinary.over(DateInterval(start: khutba, end: nextAdhan))
            }

            // Down to the khutba, over the morning's sunrise or Dhuhr's adhan to the khutba
            let untilKhutba = DateInterval(start: adhan, end: khutba)
            return Self(prayerTime: ordinary.prayerTime, kind: .iqama, target: khutba, span: untilKhutba, warningSeconds: reminderSeconds(of: dhuhr))
        }

        // 2. After Isha with Sunrise after Isha on: down to Fajr's iqama where one is set and the iqama timer is on,
        // rather than to sunrise
        if sunriseAfterIsha,
           current.type == .isha,
           ordinary.prayerTime.type != .isha,
           let fajr = (prayerDay.times + prayerDay.tomorrow).first(where: { $0.type == .fajr && $0.dateInterval.start >= current.dateInterval.end }),
           let fajrIqama = timerIqama(for: fajr) {
            return Self(prayerTime: fajr, kind: .iqama, target: fajrIqama, span: DateInterval(start: adhan, end: fajrIqama), warningSeconds: warningSeconds)
        }

        // 3. A prayer whose iqama falls inside its own time runs over two spans: its adhan to the iqama, with no
        // reminder, then the iqama to the next adhan
        guard let currentIqama, currentIqama > adhan, currentIqama < nextAdhan else { return ordinary }

        return switch ordinary.kind {
        case .iqama:
            ordinary.over(DateInterval(start: adhan, end: currentIqama), warningSeconds: 0)
        case .countdown where date >= currentIqama:
            ordinary.over(DateInterval(start: currentIqama, end: nextAdhan))
        default:
            ordinary
        }
    }

    /// The same count over another span, with its own reminder unless another is given.
    func over(_ span: DateInterval, warningSeconds: Double? = nil) -> Self {
        Self(prayerTime: prayerTime, kind: kind, target: target, span: span, warningSeconds: warningSeconds ?? self.warningSeconds)
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
