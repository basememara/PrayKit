//
//  WhiteDaysTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-08.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing
import ZamzamCore

struct WhiteDaysTests {
    private let timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .current

    /// The Hijri year, month and day each white day falls on, as the app shows it.
    private func hijriDays(_ dates: [Date], offset: Int = 0) -> [[Int]] {
        dates.map { date in
            let components = date.hijri(offSet: offset, timeZone: timeZone)
            return [components.year ?? 0, components.month ?? 0, components.day ?? 0]
        }
    }

    private func date(hijriYear year: Int, month: Int, day: Int, offset: Int = 0) throws -> Date {
        try #require(Date(hijriYear: year, month: month, day: day, offset: offset)).addingTimeInterval(12 * 3600)
    }

    @Test
    func beforeTheThirteenthTheyAreThisMonths() throws {
        let days = try date(hijriYear: 1448, month: 5, day: 4).whiteDays(offset: 0, timeZone: timeZone)
        #expect(hijriDays(days) == [[1448, 5, 13], [1448, 5, 14], [1448, 5, 15]])
    }

    @Test
    func duringThemTheyAreStillThisMonths() throws {
        let days = try date(hijriYear: 1448, month: 5, day: 15).whiteDays(offset: 0, timeZone: timeZone)
        #expect(hijriDays(days) == [[1448, 5, 13], [1448, 5, 14], [1448, 5, 15]])
    }

    @Test
    func afterTheFifteenthTheyAreNextMonths() throws {
        let days = try date(hijriYear: 1448, month: 5, day: 26).whiteDays(offset: 0, timeZone: timeZone)
        #expect(hijriDays(days) == [[1448, 6, 13], [1448, 6, 14], [1448, 6, 15]])
    }

    @Test
    func dhulHijjahIsPassedOverForMuharram() throws {
        let fromDhulQadah = try date(hijriYear: 1447, month: 11, day: 20).whiteDays(offset: 0, timeZone: timeZone)
        let fromDhulHijjah = try date(hijriYear: 1447, month: 12, day: 2).whiteDays(offset: 0, timeZone: timeZone)
        #expect(hijriDays(fromDhulQadah) == [[1448, 1, 13], [1448, 1, 14], [1448, 1, 15]])
        #expect(hijriDays(fromDhulHijjah) == [[1448, 1, 13], [1448, 1, 14], [1448, 1, 15]])
    }

    @Test
    func theUsersOffsetMovesThem() throws {
        let days = try date(hijriYear: 1448, month: 5, day: 4, offset: 1).whiteDays(offset: 1, timeZone: timeZone)
        #expect(hijriDays(days, offset: 1) == [[1448, 5, 13], [1448, 5, 14], [1448, 5, 15]])
    }
}
