//
//  IqamaTimesTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-04.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

/// The fixture's day is a Friday in Toronto: Fajr 08:00, Dhuhr 15:00, Asr 18:30, Maghrib 21:00 and Isha 22:30 local,
/// with Isha running to 08:00 the next morning.
struct IqamaTimesTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let calendar: Calendar

    init() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
    }

    private var day: PrayerDay {
        PrayerDay(date: start, times: PrayerTime.day(from: start), tomorrow: PrayerTime.day(from: start + 24 * 3600))
    }
}

extension IqamaTimesTests {
    @Test
    func theNextIqamaIsTheSoonestStillAhead() throws {
        var iqamaTimes = IqamaTimes()
        iqamaTimes.asr = .minutes(30)
        iqamaTimes.maghrib = .minutes(15)

        let beforeAsr = try #require(iqamaTimes.next(in: day, after: start + 13 * 3600, using: calendar) { $0.type.isObligation })
        let afterAsrIqama = try #require(iqamaTimes.next(in: day, after: start + 16.25 * 3600, using: calendar) { $0.type.isObligation })

        #expect(beforeAsr.prayerTime.type == .asr)
        #expect(beforeAsr.date == start + 16 * 3600)
        #expect(afterAsrIqama.prayerTime.type == .maghrib)
        #expect(afterAsrIqama.date == start + 18.25 * 3600)
    }

    @Test
    func aPrayerWithoutAnIqamaHasNoNextOne() {
        var iqamaTimes = IqamaTimes()
        iqamaTimes.asr = .minutes(30)

        #expect(iqamaTimes.next(in: day, after: start + 13 * 3600, using: calendar) { $0.type == .isha } == nil)
    }

    /// On Friday Dhuhr takes the Jumuah iqama, and the next day's Dhuhr its own.
    @Test
    func fridaysDhuhrTakesJumuahAndSaturdaysItsOwn() throws {
        var iqamaTimes = IqamaTimes()
        iqamaTimes.dhuhr = .minutes(15)
        iqamaTimes.jumuah = .minutes(45)

        let friday = try #require(iqamaTimes.next(in: day, after: start + 12.25 * 3600, using: calendar) { $0.type == .dhuhr })
        let saturday = try #require(iqamaTimes.next(in: day, after: start + 13 * 3600, using: calendar) { $0.type == .dhuhr })

        #expect(friday.date == start + 12.75 * 3600)
        #expect(saturday.date == start + 36.25 * 3600)
    }

    @Test
    func anIqamaOutsideItsPrayersTimeFallsNowhere() throws {
        let asr = try #require(day.times[.asr])
        let maghrib = try #require(day.times[.maghrib])

        #expect(IqamaTimes.IqamaType.time(hour: 19, minutes: 0).date(for: asr, using: calendar) == start + 16 * 3600)
        #expect(IqamaTimes.IqamaType.time(hour: 18, minutes: 15).date(for: asr, using: calendar) == nil)
        #expect(IqamaTimes.IqamaType.minutes(20).date(for: maghrib, using: calendar) == start + 18 * 3600 + 1200)
        #expect(IqamaTimes.IqamaType.minutes(120).date(for: maghrib, using: calendar) == nil)
        #expect(IqamaTimes.IqamaType.minutes(0).date(for: maghrib, using: calendar) == nil)
    }

    @Test
    func anIshaIqamaAfterMidnightFallsOnTheNextDay() throws {
        let isha = try #require(day.times[.isha])

        #expect(IqamaTimes.IqamaType.time(hour: 0, minutes: 30).date(for: isha, using: calendar) == start + 21.5 * 3600)
    }

    @Test
    func aDateBecomesItsTimeOfDay() {
        #expect(IqamaTimes.IqamaType(date: start + 15.25 * 3600, using: calendar) == .time(hour: 18, minutes: 15))
    }
}
