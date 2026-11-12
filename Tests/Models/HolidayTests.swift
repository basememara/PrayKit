//
//  HolidayTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-22.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing
import ZamzamCore

struct HolidayTests {
    private let eid = Holiday(id: "eid_fitr", month: 10, day: 1)

    private let holidays = [
        Holiday(id: "new_year", month: 1, day: 1),
        Holiday(id: "ashura", month: 1, day: 10),
        Holiday(id: "isra_miraj", month: 7, day: 27),
        Holiday(id: "ramadan", month: 9, day: 1),
        Holiday(id: "eid_fitr", month: 10, day: 1),
        Holiday(id: "eid_al_adha", month: 12, day: 10)
    ]

    private let calendar = Calendar.current

    /// 22 October 2026 at noon UTC, 11 Jumada I 1448: the same calendar day in every time zone a test runs in.
    private let now = Date(timeIntervalSince1970: 1_792_670_400)

    @Test
    func withoutAnOffsetTheHolidayFallsOnItsUmmAlQuraDay() throws {
        let date = try #require(eid.date(inYear: 1448, offset: 0, timeZone: calendar.timeZone))
        let hijri = Calendar(identifier: .islamicUmmAlQura, timeZone: .current).dateComponents([.year, .month, .day], from: date)

        #expect(hijri.year == 1448)
        #expect(hijri.month == 10)
        #expect(hijri.day == 1)
    }

    /// The app shows the Hijri date of the day `offset` days on, so the holiday is the day it shows 1 Shawwal.
    @Test
    func anOffsetMovesTheHolidayToTheDayThatShowsIt() throws {
        let calendar = Calendar(identifier: .islamicUmmAlQura, timeZone: .current)
        let unshifted = try #require(eid.date(inYear: 1448, offset: 0, timeZone: calendar.timeZone))

        for offset in [-2, -1, 1, 2] {
            let date = try #require(eid.date(inYear: 1448, offset: offset, timeZone: calendar.timeZone))
            let shown = date.hijri(components: [.year, .month, .day], offset: offset, timeZone: calendar.timeZone)

            #expect(calendar.dateComponents([.day], from: unshifted, to: date).day == -offset)
            #expect(shown.month == 10)
            #expect(shown.day == 1)
        }
    }

    @Test(arguments: ["Pacific/Honolulu", "Pacific/Kiritimati"])
    func aHolidayStartsAtMidnightInThePlacesTimeZone(identifier: String) throws {
        let timeZone = try #require(TimeZone(identifier: identifier))
        let place = Calendar(identifier: .gregorian, timeZone: timeZone)
        let next = try #require(holidays.upcoming(after: now, offset: 0, calendar: place).first)

        #expect(next.holiday.id == "isra_miraj")
        #expect(next.date == place.startOfDay(for: next.date))
        #expect(next.date.hijri(offset: 0, timeZone: timeZone).day == 27)
    }

    @Test
    func theHolidaysComeSoonestFirstFromTheNextOne() {
        let upcoming = holidays.upcoming(after: now, offset: 0, calendar: calendar)

        #expect(upcoming.map(\.holiday.id) == ["isra_miraj", "ramadan", "eid_fitr", "eid_al_adha", "new_year", "ashura"])
        #expect(upcoming.map(\.date) == upcoming.map(\.date).sorted())
    }

    /// Isra and Mi'raj, 27 Rajab, falls on 5 January 2027.
    @Test
    func theNextHolidayCountsTheDaysToIt() throws {
        let next = try #require(holidays.upcoming(after: now, offset: 0, calendar: calendar).first)

        #expect(next.daysUntil(from: now, calendar: calendar) == 75)
    }

    /// 5 January 2027 at noon UTC: Isra and Mi'raj itself, which stays first with no days to go.
    @Test
    func aHolidayStaysOnItsOwnDay() throws {
        let onTheDay = Date(timeIntervalSince1970: 1_799_150_400)
        let next = try #require(holidays.upcoming(after: onTheDay, offset: 0, calendar: calendar).first)

        #expect(next.holiday.id == "isra_miraj")
        #expect(next.daysUntil(from: onTheDay, calendar: calendar) == 0)
    }

    @Test
    func anOffsetMovesTheDayButNotItsHijriLabel() throws {
        let plain = try #require(holidays.upcoming(after: now, offset: 0, calendar: calendar).first)
        let ahead = try #require(holidays.upcoming(after: now, offset: 1, calendar: calendar).first)

        #expect(ahead.holiday == plain.holiday)
        #expect(ahead.daysUntil(from: now, calendar: calendar) == plain.daysUntil(from: now, calendar: calendar) - 1)
        #expect(ahead.hijriDay == plain.hijriDay)
    }

    @Test
    func theYearListsThisYearsHolidaysPassedOnesIncluded() {
        let year = holidays.year(holding: now, offset: 0, calendar: calendar)

        #expect(year.map(\.holiday.id) == ["new_year", "ashura", "isra_miraj", "ramadan", "eid_fitr", "eid_al_adha"])
        #expect(year.prefix(2).allSatisfy { $0.date < now })
    }

    /// 20 May 2027 at noon UTC, 14 Dhu'l-Hijjah 1448: every holiday of 1448 has passed.
    @Test
    func onceEveryHolidayHasPassedTheYearIsNextYears() throws {
        let afterEidAlAdha = Date(timeIntervalSince1970: 1_810_814_400)
        let year = holidays.year(holding: afterEidAlAdha, offset: 0, calendar: calendar)
        let first = try #require(year.first)

        #expect(year.count == holidays.count)
        #expect(first.holiday.id == "new_year")
        #expect(first.date > afterEidAlAdha)
    }
}
