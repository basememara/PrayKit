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
        PrayerDay(date: start, times: times(from: 0), tomorrow: times(from: 24 * 3600))
    }

    /// Each prayer runs until the next begins and Isha until the next day's Fajr, 29 hours after the day's start.
    private func times(from offset: TimeInterval, ishaAt ishaHour: Double = 19.5) -> [PrayerTime] {
        let hours: [(Prayer, Double)] = [(.fajr, 5), (.sunrise, 6.5), (.dhuhr, 12), (.asr, 15.5), (.maghrib, 18), (.isha, ishaHour)]
        return hours.enumerated().map { index, entry in
            let end = index + 1 < hours.count ? hours[index + 1].1 : 29
            return PrayerTime(type: entry.0, dateInterval: DateInterval(start: start + offset + entry.1 * 3600, end: start + offset + end * 3600))
        }
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
        let day = PrayerDay(date: start, times: times(from: 0, ishaAt: 24 + 50.0 / 60), tomorrow: times(from: 24 * 3600))
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
