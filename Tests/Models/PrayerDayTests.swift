//
//  PrayerDayTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import Testing
import PrayCore

struct PrayerDayTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private var day: PrayerDay {
        PrayerDay(date: start, times: times(from: 0), yesterday: times(from: -24 * 3600), tomorrow: times(from: 24 * 3600))
    }

    private func times(from offset: TimeInterval) -> [PrayerTime] {
        [(Prayer.fajr, 5.0), (.sunrise, 6.5), (.dhuhr, 12.0), (.asr, 15.5), (.maghrib, 18.0), (.isha, 19.5)]
            .map { prayer, hour in
                PrayerTime(type: prayer, dateInterval: DateInterval(start: start + offset + hour * 3600, duration: 3600))
            }
    }
}

extension PrayerDayTests {
    @Test
    func beforeFajrTheLastObligatoryIsYesterdaysIsha() throws {
        let prayer = try #require(day.lastObligatory(at: start + 3 * 3600))
        #expect(prayer.type == .isha)
        #expect(prayer.dateInterval.start < start)
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
        #expect(prayer.dateInterval.start > start + 24 * 3600)
    }

    @Test
    func yesterdaysIshaAfterMidnightIsNextUntilItBegins() throws {
        // A high-latitude summer: yesterday's Isha begins at 00:50 today
        let lateIsha = PrayerTime(type: .isha, dateInterval: DateInterval(start: start + 50 * 60, duration: 3600))
        let day = PrayerDay(date: start, times: times(from: 0), yesterday: times(from: -24 * 3600).dropLast() + [lateIsha], tomorrow: [])

        let last = try #require(day.lastObligatory(at: start + 20 * 60))
        let next = try #require(day.nextObligatory(at: start + 20 * 60))

        #expect(last.type == .maghrib)
        #expect(next == lateIsha)
    }

    @Test
    func aSnoozeMustLandBeforeThePrayerEnds() throws {
        let dhuhr = try #require(day.times[.dhuhr])
        let halfway = dhuhr.dateInterval.start + 1800

        #expect(dhuhr.acceptsSnooze(of: 1700, at: halfway))
        #expect(!dhuhr.acceptsSnooze(of: 1800, at: halfway))
    }
}
