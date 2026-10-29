//
//  PrayerWindowTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-29.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct PrayerWindowTests {
    private let calendar = Calendar(identifier: .gregorian, timeZone: .gmt)

    /// Wednesday 2027-01-13 at 00:00 GMT, so the day after is not a Friday.
    private let start = Date(timeIntervalSince1970: 1_799_798_400)

    private var day: PrayerDay {
        PrayerDay(date: start, times: PrayerTime.day(from: start), tomorrow: PrayerTime.day(from: start + 24 * 3600))
    }

    private func hour(_ value: Double) -> Date { start + value * 3600 }
}

extension PrayerWindowTests {
    @Test
    func theDefaultRemindersCoverSunriseAndThePrayersAfterIt() {
        let windows = Settings().prayerWindows(in: [day], from: hour(0), using: calendar)
        #expect(windows.map(\.prayer) == [.sunrise, .dhuhr, .asr, .maghrib, .isha])
    }

    @Test
    func fajrNeverHasAWindowEvenWithAReminder() {
        var settings = Settings()
        settings.preAdhanMinutes[.fajr] = 15

        let windows = settings.prayerWindows(in: [day], from: hour(0), using: calendar)
        #expect(!windows.map(\.prayer).contains(.fajr))
    }

    @Test
    func aPrayerWithoutAReminderOpensHalfAnHourBefore() throws {
        var settings = Settings()
        settings.preAdhanMinutes[.maghrib] = 0

        let windows = settings.prayerWindows(in: [day], from: hour(0), using: calendar)
        let maghrib = try #require(windows.first { $0.prayer == .maghrib })

        #expect(windows.map(\.prayer) == [.sunrise, .dhuhr, .asr, .maghrib, .isha])
        #expect(maghrib.start == hour(17.5))
    }

    @Test
    func opensFiveMinutesBeforeTheReminderAndClosesAtTheIqama() throws {
        var settings = Settings()
        settings.preAdhanMinutes[.asr] = 25
        settings.iqamaTimes.asr = .minutes(15)

        let windows = settings.prayerWindows(in: [day], from: hour(0), using: calendar)
        let asr = try #require(windows.first { $0.prayer == .asr })

        #expect(asr.start == hour(15))
        #expect(asr.time == hour(15.5))
        #expect(asr.end == hour(15.75))
    }

    @Test
    func sunriseClosesAtSunrise() throws {
        let windows = Settings().prayerWindows(in: [day], from: hour(0), using: calendar)
        let sunrise = try #require(windows.first { $0.prayer == .sunrise })

        #expect(sunrise.start == hour(6.5) - 25 * 60)
        #expect(sunrise.iqama == nil)
        #expect(sunrise.end == hour(6.5))
    }

    @Test
    func withoutAnIqamaClosesAtTheAdhan() throws {
        let windows = Settings().prayerWindows(in: [day], from: hour(0), using: calendar)
        let dhuhr = try #require(windows.first { $0.prayer == .dhuhr })

        #expect(dhuhr.iqama == nil)
        #expect(dhuhr.end == hour(12))
    }

    @Test
    func anIqamaIsLeftOutWhenTheIqamaTimerIsOff() throws {
        var settings = Settings()
        settings.iqamaTimes.asr = .minutes(15)
        settings.isIqamaTimerEnabled = false

        let windows = settings.prayerWindows(in: [day], from: hour(0), using: calendar)
        let asr = try #require(windows.first { $0.prayer == .asr })

        #expect(asr.end == hour(15.5))
    }

    @Test
    func aWindowUnderWayIsKeptUntilItEnds() {
        var settings = Settings()
        settings.iqamaTimes.asr = .minutes(15)

        let windows = settings.prayerWindows(in: [day], from: hour(15.6), using: calendar)
        #expect(windows.map(\.prayer) == [.asr, .maghrib, .isha])

        let afterIqama = settings.prayerWindows(in: [day], from: hour(15.75), using: calendar)
        #expect(afterIqama.map(\.prayer) == [.maghrib, .isha])
    }

    @Test
    func daysJoinInOrder() {
        let tomorrow = PrayerDay(date: start + 24 * 3600, times: PrayerTime.day(from: start + 24 * 3600), tomorrow: PrayerTime.day(from: start + 48 * 3600))
        let windows = Settings().prayerWindows(in: [tomorrow, day], from: hour(20), using: calendar)

        #expect(windows.map(\.prayer) == [.sunrise, .dhuhr, .asr, .maghrib, .isha])
        #expect(windows.first?.time == hour(30.5))
    }

    @Test
    func fridaysDhuhrIsJumuahWithItsOwnIqama() throws {
        // Friday 2027-01-15
        let friday = start + 2 * 24 * 3600
        let day = PrayerDay(date: friday, times: PrayerTime.day(from: friday), tomorrow: PrayerTime.day(from: friday + 24 * 3600))
        var settings = Settings()
        settings.iqamaTimes.dhuhr = .minutes(10)
        settings.iqamaTimes.jumuah = .time(hour: 13, minutes: 0)

        let windows = settings.prayerWindows(in: [day], from: friday, using: calendar)
        let dhuhr = try #require(windows.first { $0.prayer == .dhuhr })

        #expect(dhuhr.isJumuah)
        #expect(dhuhr.iqama == friday + 13 * 3600)
    }
}
