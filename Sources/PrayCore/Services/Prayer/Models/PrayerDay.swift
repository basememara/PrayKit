//
//  PrayerDay.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-14.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate
import Foundation.NSTimeZone
import ZamzamCore

/// A prayer day runs from its Fajr to the next Fajr: its prayers follow one another with no gap and Isha ends where
/// the next day's Fajr begins, so midnight is not a boundary and every moment belongs to exactly one day. `tomorrow`
/// carries the day after, which a countdown past Isha needs.
public struct PrayerDay: Equatable, Codable, Sendable {
    /// The start of the calendar day the prayers were calculated for, in the place's time zone.
    public let date: Date
    public let times: [PrayerTime]
    public let tomorrow: [PrayerTime]

    public init(date: Date, times: [PrayerTime], tomorrow: [PrayerTime]) {
        self.date = date
        self.times = times
        self.tomorrow = tomorrow
    }
}

public extension PrayerDay {
    /// Where the day's times were borrowed from, when it can't be calculated at the place near the polar circles.
    var borrowed: PolarResolution? { times.lazy.compactMap(\.borrowed).first }

    /// Whether the instant falls in this prayer day, which runs from its Fajr until its Isha ends at the next Fajr.
    func contains(_ instant: Date) -> Bool {
        guard let fajr = times[.fajr], let isha = times[.isha] else { return false }
        return fajr.dateInterval.start <= instant && instant < isha.dateInterval.end
    }

    /// The next time of a prayer: one under way or still to come, or for sunrise, one still to come.
    func upcoming(_ prayer: Prayer, at time: Date) -> PrayerTime? {
        (times + tomorrow).first {
            $0.type == prayer && (prayer == .sunrise ? $0.dateInterval.start > time : $0.dateInterval.end > time)
        }
    }
}

// A day answers from its Fajr through the day after, never for a moment before its Fajr: that moment belongs to the
// day before, which `PrayerManager.fetch(at:)` returns.
public extension PrayerDay {
    /// The essential prayer under way, Isha until the next Fajr.
    func current(at time: Date = .now) -> PrayerTime? {
        (times + tomorrow).first { time.isBetween($0.dateInterval.start, $0.dateInterval.end) && $0.type.isEssential }
    }

    func next(at time: Date = .now, sunriseAfterIsha: Bool = false) -> PrayerTime? {
        (times + tomorrow).first { $0.dateInterval.start > time && $0.type.isEssential && (sunriseAfterIsha ? $0.type != .fajr : true) }
    }

    /// Where a prayer stands at a moment. Only the prayer under way is current, and only while this day holds the
    /// moment, so a day shown after its Isha has ended picks out none.
    func stage(of prayerTime: PrayerTime, at time: Date) -> PrayerStage {
        guard prayerTime.dateInterval.start <= time else { return .upcoming }
        return contains(time) && current(at: time) == prayerTime ? .current : .passed
    }

    /// The obligatory prayer whose time began most recently, which between sunrise and Dhuhr is still Fajr.
    func lastObligatory(at time: Date) -> PrayerTime? {
        (times + tomorrow).last { $0.type.isObligation && $0.dateInterval.start <= time }
    }

    /// The next obligatory prayer to begin, which after Isha is tomorrow's Fajr.
    func nextObligatory(at time: Date) -> PrayerTime? {
        (times + tomorrow).first { $0.type.isObligation && $0.dateInterval.start > time }
    }
}

// MARK: - Turnover

// Screens list a day's prayers until its turnover, then the next day's. The prayer day still runs to the next Fajr for
// everything that answers "now": the countdown, the prayer under way, Siri and the notifications.
public extension PrayerDay {
    /// When screens stop listing this day and list the next: 12 AM, or later when tonight's Isha hasn't begun or its
    /// iqama or count-up hasn't ended by then, and the next Fajr at the latest. `nil` for a day without an Isha.
    func turnover(settings: Settings, using calendar: Calendar) -> Date? {
        turnover(
            iqamaTimes: settings.iqamaTimes,
            isIqamaTimerEnabled: settings.isIqamaTimerEnabled,
            stopwatchMinutes: settings.stopwatchMinutes,
            using: calendar
        )
    }

    /// Whether screens list the next day at a moment, once this day's turnover has passed.
    func listsTomorrow(at time: Date, settings: Settings, using calendar: Calendar) -> Bool {
        turnover(settings: settings, using: calendar).map { time >= $0 } ?? false
    }

    /// The day screens list at a moment: this one until its turnover, then the next.
    func listedDay(at time: Date, settings: Settings, using calendar: Calendar) -> PrayerDay {
        listsTomorrow(at: time, settings: settings, using: calendar) ? dayAfter(using: calendar) : self
    }
}

extension PrayerDay {
    func turnover(iqamaTimes: IqamaTimes, isIqamaTimerEnabled: Bool, stopwatchMinutes: Int, using calendar: Calendar) -> Date? {
        guard let isha = times[.isha] else { return nil }
        // The same window a timer shows: an iqama when one is set, otherwise the count-up
        let iqama = isIqamaTimerEnabled ? iqamaTimes[isha, using: calendar] : nil
        let ishaWindowEnd = iqama ?? isha.dateInterval.start + .minutes(max(stopwatchMinutes, 0))
        return min(max(date.tomorrow(using: calendar), ishaWindowEnd), isha.dateInterval.end)
    }

    /// The next day from `tomorrow`, listed only until its own Fajr, before which nothing in it is under way.
    func dayAfter(using calendar: Calendar) -> PrayerDay {
        PrayerDay(date: date.tomorrow(using: calendar), times: tomorrow, tomorrow: [])
    }
}

public extension PrayerTime {
    /// The time a list shows for this prayer: on a Friday, by its own date, Dhuhr shows the khutba when one is set.
    func listedStart(iqamaTimes: IqamaTimes, using calendar: Calendar) -> Date {
        guard isJumuah(using: calendar) else { return dateInterval.start }
        return iqamaTimes[self, using: calendar] ?? dateInterval.start
    }

    /// Whether a reminder `interval` from `date` still lands inside this prayer's time.
    func acceptsSnooze(of interval: TimeInterval, at date: Date) -> Bool {
        date + interval < dateInterval.end
    }
}

public enum PrayerStage: Equatable, Sendable {
    case passed
    case current
    case upcoming
}
