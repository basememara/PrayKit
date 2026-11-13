//
//  PrayerTimetableSource.swift
//  PrayServices
//
//  Created by Basem Emara on 2026-11-13.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore

/// An authority's published timetable: what one table covers, how to ask for it and how its response reads.
///
/// `PrayerServiceTimetable` does the rest for every source: where a table is kept, when the API is asked, and how a
/// printed day becomes prayer times.
protocol PrayerTimetableSource: Sendable {
    /// Names the source's folder: `london`.
    var id: String { get }

    /// What one table covers.
    var period: TimetablePeriod { get }

    /// The part of the timetable a place reads, which names a folder inside the source's. `nil`, the default, when
    /// one table serves every place.
    func zone(for request: PrayerAPI.Request) -> String?

    /// Asks the API for a table. A key the API needs goes on this request and nowhere else.
    func urlRequest(for table: PrayerTimetable) -> URLRequest

    /// The days in a table's response. A table not yet published reads as no days, and a day that can't be read is
    /// left out.
    func days(from data: Data) throws -> [TimetableDate: TimetableDay]
}

extension PrayerTimetableSource {
    func zone(for request: PrayerAPI.Request) -> String? { nil }
}

// MARK: - Types

/// One published table: the first day it covers, and its zone when the source has them.
struct PrayerTimetable: Hashable, Sendable {
    let start: TimetableDate
    let zone: String?
}

enum TimetablePeriod: Sendable {
    case year
    case month
    /// Monday to Sunday.
    case week
}

/// A calendar day as a timetable prints it, with no time zone of its own.
struct TimetableDate: Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int
}

/// A time of day as a timetable prints it.
struct TimetableClock: Equatable, Sendable {
    let hour: Int
    let minute: Int
}

/// A day as the authority prints it: clock times read in the place's time zone.
struct TimetableDay: Sendable {
    let fajr: TimetableClock
    let sunrise: TimetableClock
    let dhuhr: TimetableClock
    let asr: TimetableClock
    /// Asr by the Hanafi rule, where the authority prints one.
    let asrHanafi: TimetableClock?
    let maghrib: TimetableClock
    let isha: TimetableClock
}

// MARK: - Helpers

extension TimetablePeriod {
    var component: Calendar.Component {
        switch self {
        case .year: .year
        case .month: .month
        case .week: .weekOfYear
        }
    }

    /// The file name of the table that starts on a day: `2027`, `2027-03`, or `2027-03-08` for a week.
    func name(startingOn start: TimetableDate) -> String {
        switch self {
        case .year: String(format: "%04d", start.year)
        case .month: String(format: "%04d-%02d", start.year, start.month)
        case .week: String(format: "%04d-%02d-%02d", start.year, start.month, start.day)
        }
    }
}

extension TimetableDate {
    init(_ date: Date, using calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }

    /// Reads `yyyy-MM-dd`.
    init?(_ text: some StringProtocol) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 3, let year = parts[0], let month = parts[1], let day = parts[2] else { return nil }
        self.init(year: year, month: month, day: day)
    }
}

extension TimetableClock {
    /// Reads `HH:mm` on the 24-hour clock.
    init?(_ text: some StringProtocol) {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false).map { Int($0) }

        guard parts.count == 2,
              let hour = parts[0], (0..<24).contains(hour),
              let minute = parts[1], (0..<60).contains(minute)
        else {
            return nil
        }

        self.init(hour: hour, minute: minute)
    }

    /// The moment the clock shows on a day, in the calendar's time zone.
    func date(on day: TimetableDate, using calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))
    }
}
