//
//  PrayerDayTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct PrayerDayTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private var day: PrayerDay {
        PrayerDay(date: start, times: PrayerTime.day(from: start), tomorrow: PrayerTime.day(from: start + 24 * 3600))
    }
}

extension PrayerDayTests {
    @Test
    func aMomentBeforeFajrBelongsToTheDayBefore() {
        #expect(!day.contains(start + 3 * 3600))
        #expect(day.current(at: start + 3 * 3600) == nil)
        #expect(day.lastObligatory(at: start + 3 * 3600) == nil)
    }

    @Test
    func afterSunriseTheLastObligatoryIsStillFajr() throws {
        let prayer = try #require(day.lastObligatory(at: start + 8 * 3600))
        #expect(prayer.type == .fajr)
    }

    @Test
    func aPrayerIsUnderWayFromItsFirstSecond() throws {
        let prayer = try #require(day.lastObligatory(at: start + 12 * 3600))
        #expect(prayer.type == .dhuhr)
    }

    @Test
    func afterSunriseTheNextObligatoryIsDhuhr() throws {
        let prayer = try #require(day.nextObligatory(at: start + 6.5 * 3600))
        #expect(prayer.type == .dhuhr)
    }

    @Test
    func afterIshaTheNextObligatoryIsTomorrowsFajr() throws {
        let prayer = try #require(day.nextObligatory(at: start + 21 * 3600))
        #expect(prayer.type == .fajr)
        #expect(prayer.dateInterval.start == start + 29 * 3600)
    }

    @Test
    func ishaIsUnderWayPastMidnightUntilTheNextFajr() throws {
        #expect(day.current(at: start + 25 * 3600)?.type == .isha)
        #expect(day.current(at: start + 29 * 3600 - 1)?.type == .isha)
        #expect(day.current(at: start + 29 * 3600)?.dateInterval.start == start + 29 * 3600)
    }

    @Test
    func anIshaAfterMidnightIsStillThisDaysUntilItBegins() throws {
        // A summer at high latitude: Isha begins at 00:50, after midnight
        let day = PrayerDay(date: start, times: PrayerTime.day(from: start, ishaAt: 24 + 50.0 / 60), tomorrow: PrayerTime.day(from: start + 24 * 3600))
        let twenty = start + (24 + 20.0 / 60) * 3600

        let current = try #require(day.current(at: twenty))
        let next = try #require(day.nextObligatory(at: twenty))

        #expect(day.contains(twenty))
        #expect(current.type == .maghrib)
        #expect(day.lastObligatory(at: twenty)?.type == .maghrib)
        #expect(next.type == .isha)
        #expect(next.dateInterval.start == start + (24 + 50.0 / 60) * 3600)
    }

    @Test
    func aDayStillAnswersForTheDayAfter() {
        #expect(day.current(at: start + 37 * 3600)?.type == .dhuhr)
        #expect(day.current(at: start + 37 * 3600)?.dateInterval.start == start + 36 * 3600)
    }

    @Test
    func aSnoozeMustLandBeforeThePrayerEnds() throws {
        let dhuhr = try #require(day.times[.dhuhr])
        let threeHoursBeforeAsr = dhuhr.dateInterval.end - 3 * 3600

        #expect(dhuhr.acceptsSnooze(of: 3 * 3600 - 1, at: threeHoursBeforeAsr))
        #expect(!dhuhr.acceptsSnooze(of: 3 * 3600, at: threeHoursBeforeAsr))
    }
}
