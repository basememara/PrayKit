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

    @Test
    func withoutAnOffsetTheHolidayFallsOnItsUmmAlQuraDay() throws {
        let date = try #require(eid.date(inYear: 1448, offset: 0))
        let hijri = Date.islamicCalendar.dateComponents([.year, .month, .day], from: date)

        #expect(hijri.year == 1448)
        #expect(hijri.month == 10)
        #expect(hijri.day == 1)
    }

    /// The app shows the Hijri date of the day `offset` days on, so the holiday is the day it shows 1 Shawwal.
    @Test
    func anOffsetMovesTheHolidayToTheDayThatShowsIt() throws {
        let calendar = Date.islamicCalendar
        let unshifted = try #require(eid.date(inYear: 1448, offset: 0))

        for offset in [-2, -1, 1, 2] {
            let date = try #require(eid.date(inYear: 1448, offset: offset))
            let shown = date.hijri(components: [.year, .month, .day], offSet: offset)

            #expect(calendar.dateComponents([.day], from: unshifted, to: date).day == -offset)
            #expect(shown.month == 10)
            #expect(shown.day == 1)
        }
    }
}
