//
//  DateHijriTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-09-17.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import PrayMocks
import Testing
import ZamzamCore

struct DateHijriTests {
    /// The Islamic day turns over at maghrib, but only until the location's own midnight, so the
    /// same-day check must use the prayer time zone rather than whatever the host machine is set to.
    @Test
    func autoIncrementFollowsTheLocationDay() throws {
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let noon = try #require(Date(year: 2022, month: 3, day: 16, hour: 12, timeZone: timeZone))
        let prayerDay = PrayerDay.mock(at: noon, calendar: calendar)

        let afterMaghrib = try #require(Date(year: 2022, month: 3, day: 16, hour: 21, timeZone: timeZone))
        let beforeMidnight = try #require(Date(year: 2022, month: 3, day: 16, hour: 23, minute: 59, timeZone: timeZone))
        let afterMidnight = try #require(Date(year: 2022, month: 3, day: 17, hour: 0, minute: 30, timeZone: timeZone))
        let beforeMaghrib = try #require(Date(year: 2022, month: 3, day: 16, hour: 18, timeZone: timeZone))

        #expect(afterMaghrib.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: true, timeZone: timeZone) == 3)
        #expect(beforeMidnight.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: true, timeZone: timeZone) == 3)
        #expect(afterMidnight.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: true, timeZone: timeZone) == 2)
        #expect(beforeMaghrib.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: true, timeZone: timeZone) == 2)
        #expect(afterMaghrib.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: false, timeZone: timeZone) == 2)
    }
}
