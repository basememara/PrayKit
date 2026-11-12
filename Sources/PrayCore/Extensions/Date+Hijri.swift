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
    /// The days to add to this instant's calendar date for its Hijri date. With auto-increment, the Hijri day turns at
    /// Maghrib rather than midnight, so it counts from the date of the prayer day holding the instant, a day on once
    /// that day's Maghrib has begun, whichever side of midnight the instant falls.
    func hijriDayOffset(
        for prayerDay: PrayerDay?,
        hijriDayOffset: Int,
        autoIncrementHijri: Bool,
        timeZone: TimeZone
    ) -> Int {
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)

        guard autoIncrementHijri,
              let prayerDay,
              prayerDay.contains(self),
              let daysPastPrayerDay = calendar.dateComponents([.day], from: prayerDay.date, to: calendar.startOfDay(for: self)).day
        else {
            return hijriDayOffset
        }

        let hasMaghribBegun = prayerDay.times[.maghrib].map { self >= $0.dateInterval.start } ?? false
        return hijriDayOffset + (hasMaghribBegun ? 1 : 0) - daysPastPrayerDay
    }
}

/// How a Hijri month is written beside its day.
public enum HijriMonthWidth: Sendable {
    /// Raj.
    case abbreviated
    /// Rajab
    case wide

    var template: String {
        switch self {
        case .abbreviated: "MMM"
        case .wide: "MMMM"
        }
    }
}

public extension Date {
    /// The Hijri day then its month, such as 27 Raj., in every locale; a day-and-month template lets the locale put
    /// the month first. The month is written as it stands alone, which English abbreviates differently inside a
    /// date (Rajb.).
    func hijriDayAndMonth(
        month: HijriMonthWidth = .abbreviated,
        offset: Int = 0,
        timeZone: TimeZone,
        locale: Locale = .current
    ) -> String {
        ["d", month.template]
            .map { hijriString(template: $0, offset: offset, timeZone: timeZone, locale: locale) }
            .joined(separator: " ")
    }
}

public extension Date {
    /// The day a Hijri date falls on as the app shows it, at its midnight in `timeZone`: the app shows the Hijri date
    /// of the day `offset` days on, so each Hijri day comes `offset` days before its Umm al-Qura day.
    init?(hijriYear year: Int, month: Int, day: Int, offset: Int, timeZone: TimeZone) {
        let calendar = Calendar(identifier: .islamicUmmAlQura, timeZone: timeZone)
        guard let date = DateComponents(calendar: calendar, year: year, month: month, day: day).date
            .flatMap({ calendar.date(byAdding: .day, value: -offset, to: $0) }) else { return nil }
        self = date
    }
}

public extension Date {
    /// The white days, the 13th to the 15th of a Hijri month, dated as the app shows them: this month's while they are
    /// still to come or under way, else the next month's. Dhu'l-Hijjah's are passed over for Muharram's, since its
    /// 13th is a day of tashreeq.
    func whiteDays(offset: Int, timeZone: TimeZone) -> [Date] {
        let today = hijri(offset: offset, timeZone: timeZone)
        guard let year = today.year, let month = today.month, let day = today.day else { return [] }
        let next = { (year: Int, month: Int) in month == 12 ? (year + 1, 1) : (year, month + 1) }
        let current = day <= 15 ? (year, month) : next(year, month)
        let (whiteYear, whiteMonth) = current.1 == 12 ? next(current.0, current.1) : current
        return (13...15).compactMap { Date(hijriYear: whiteYear, month: whiteMonth, day: $0, offset: offset, timeZone: timeZone) }
    }
}
