//
//  PrayerDay.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-14.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate
import Foundation.NSTimeZone

public struct PrayerDay: Equatable, Codable, Sendable {
    public let date: Date
    public let times: [PrayerTime]
    public let yesterday: [PrayerTime]
    public let tomorrow: [PrayerTime]

    public init(
        date: Date,
        times: [PrayerTime],
        yesterday: [PrayerTime],
        tomorrow: [PrayerTime]
    ) {
        self.date = date
        self.times = times
        self.yesterday = yesterday
        self.tomorrow = tomorrow
    }
}

public extension PrayerDay {
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

public extension PrayerDay {
    func current(at time: Date = .now) -> PrayerTime? {
        times.first { time.isBetween($0.dateInterval.start, $0.dateInterval.end) && $0.type.isEssential }
            ?? yesterday[.isha]
    }

    func next(at time: Date = .now, sunriseAfterIsha: Bool = false) -> PrayerTime? {
        let predicate: (PrayerTime) -> Bool = { $0.dateInterval.start > time && $0.type.isEssential && (sunriseAfterIsha ? $0.type != .fajr : true) }
        return times.first(where: predicate) ?? tomorrow.first(where: predicate)
    }

    /// The obligatory prayer whose time began most recently, which before Fajr is yesterday's Isha once it has begun.
    func lastObligatory(at time: Date) -> PrayerTime? {
        (yesterday + times)
            .filter { $0.type.isObligation && $0.dateInterval.start <= time }
            .max { $0.dateInterval.start < $1.dateInterval.start }
    }

    /// The next obligatory prayer to begin: after Isha, tomorrow's Fajr; after midnight, yesterday's Isha if it
    /// hasn't begun, as at high latitudes in summer.
    func nextObligatory(at time: Date) -> PrayerTime? {
        (yesterday + times + tomorrow)
            .filter { $0.type.isObligation && $0.dateInterval.start > time }
            .min { $0.dateInterval.start < $1.dateInterval.start }
    }
}

public extension PrayerTime {
    /// The time a list shows for this prayer: on a Friday, by its own date, Dhuhr shows the khutba when one is set.
    func listedStart(iqamaTimes: IqamaTimes, using calendar: Calendar) -> Date {
        guard type == .dhuhr, dateInterval.start.isJumuah(using: calendar) else { return dateInterval.start }
        return iqamaTimes[self, using: calendar] ?? dateInterval.start
    }

    /// Whether a reminder `interval` from `date` still lands inside this prayer's time.
    func acceptsSnooze(of interval: TimeInterval, at date: Date) -> Bool {
        date + interval < dateInterval.end
    }
}
