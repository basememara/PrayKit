//
//  Holiday.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-03-17.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import ZamzamCore

public struct Holiday: Identifiable, Equatable, Sendable {
    public let id: String
    public let month: Int
    public let day: Int

    public init(
        id: String,
        month: Int,
        day: Int
    ) {
        self.id = id
        self.month = month
        self.day = day
    }
}

public extension Holiday {
    static let all: [Holiday] = [
        Holiday(id: "new_year", month: 1, day: 1),
        Holiday(id: "ashura", month: 1, day: 10),
        Holiday(id: "isra_miraj", month: 7, day: 27),
        Holiday(id: "ramadan", month: 9, day: 1),
        Holiday(id: "eid_fitr", month: 10, day: 1),
        Holiday(id: "hajj", month: 12, day: 8),
        Holiday(id: "arafah", month: 12, day: 9),
        Holiday(id: "eid_al_adha", month: 12, day: 10)
    ]
}

public extension Holiday {
    /// The day the holiday falls on in a Hijri year, as dated with the user's Hijri day offset.
    func date(inYear year: Int, offset: Int, timeZone: TimeZone) -> Date? {
        Date(hijriYear: year, month: month, day: day, offset: offset, timeZone: timeZone)
    }

    /// The holiday in a Hijri year, dated with the user's offset and labelled by its own Hijri day.
    func occurrence(inYear year: Int, offset: Int, timeZone: TimeZone) -> Occurrence? {
        // The offset moves the day it falls on, but the Hijri date it names stays its own
        guard let day = date(inYear: year, offset: offset, timeZone: timeZone),
              let hijriDay = date(inYear: year, offset: 0, timeZone: timeZone)
        else { return nil }
        return Occurrence(holiday: self, date: day, hijriDay: hijriDay)
    }

    struct Occurrence: Equatable, Sendable {
        public let holiday: Holiday
        /// The day it falls on, with the user's Hijri day offset.
        public let date: Date
        /// A day whose Hijri date is the holiday's own, for its label.
        public let hijriDay: Date
    }
}

public extension Holiday.Occurrence {
    /// Whole days from the day holding `now` to the holiday's, 0 on the holiday itself.
    func daysUntil(from now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }
}

public extension [Holiday] {
    /// Each holiday's next occurrence, soonest first. A holiday is still this year's on its own day, though its
    /// midnight has passed; `calendar` sets the zone the day turns in.
    func upcoming(after date: Date, offset: Int, calendar: Calendar) -> [Holiday.Occurrence] {
        let today = calendar.startOfDay(for: date)
        guard let year = date.hijri(offset: offset, timeZone: calendar.timeZone).year else { return [] }

        return compactMap { holiday in
            guard let thisYear = holiday.occurrence(inYear: year, offset: offset, timeZone: calendar.timeZone) else { return nil }
            return thisYear.date < today ? holiday.occurrence(inYear: year + 1, offset: offset, timeZone: calendar.timeZone) : thisYear
        }
        .sorted { $0.date < $1.date }
    }

    /// The Hijri year's holidays in order, or once every one has passed, next year's.
    func year(holding date: Date, offset: Int, calendar: Calendar) -> [Holiday.Occurrence] {
        let today = calendar.startOfDay(for: date)
        guard let year = date.hijri(offset: offset, timeZone: calendar.timeZone).year else { return [] }
        let occurrences = { (year: Int) in
            compactMap { $0.occurrence(inYear: year, offset: offset, timeZone: calendar.timeZone) }.sorted { $0.date < $1.date }
        }
        let thisYear = occurrences(year)

        return thisYear.allSatisfy { $0.date < today } ? occurrences(year + 1) : thisYear
    }
}
