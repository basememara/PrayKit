//
//  TimerIqamaTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

/// The iqama a timer counts to follows the iqama timer: the prayer's own while it is on, none while it is off.
struct TimerIqamaTests {
    private let fixture = PrayTestFixture()
}

extension TimerIqamaTests {
    @Test(arguments: DayFixture.all)
    func aMinutesIqamaCountsOnlyWhileTheTimerIsOn(place: DayFixture) async throws {
        let calendar = try place.calendar()
        let prayers = try await day(of: place).times.filter(\.type.isObligation)
        let iqama = IqamaTimes.IqamaType.minutes(5)
        let iqamaTimes = IqamaTimes(fajr: iqama, dhuhr: iqama, asr: iqama, maghrib: iqama, isha: iqama, jumuah: iqama)

        #expect(prayers.map(\.type) == [.fajr, .dhuhr, .asr, .maghrib, .isha])
        #expect(prayers.map { iqamaTimes.timerIqama(for: $0, isTimerEnabled: true, using: calendar) } == prayers.map { $0.dateInterval.start + 300 })
        #expect(prayers.compactMap { iqamaTimes.timerIqama(for: $0, isTimerEnabled: false, using: calendar) }.isEmpty)
    }

    /// Asr holds half past the hour in each of these places.
    @Test(arguments: zip(["Toronto in winter", "San Francisco in June", "Kuala Lumpur"], [15, 18, 17]))
    func aTimeOfDayIqamaCountsOnlyWhileTheTimerIsOn(name: String, hour: Int) async throws {
        let place = try #require(DayFixture.all.first { $0.name == name })
        let calendar = try place.calendar()
        let asr = try #require(try await day(of: place).times[.asr])
        let halfPast = try place.date(place.year, place.month, place.day, hour, 30)
        var iqamaTimes = IqamaTimes()
        iqamaTimes.asr = .time(hour: hour, minutes: 30)

        #expect(iqamaTimes.timerIqama(for: asr, isTimerEnabled: true, using: calendar) == halfPast)
        #expect(iqamaTimes.timerIqama(for: asr, isTimerEnabled: false, using: calendar) == nil)
    }

    @Test(arguments: DayFixture.all)
    func aTimeWithoutAnIqamaHasNoneEitherWay(place: DayFixture) async throws {
        let calendar = try place.calendar()
        let times = try await day(of: place).times
        var iqamaTimes = IqamaTimes()
        iqamaTimes.asr = .minutes(5)

        let counted = [true, false].flatMap { isTimerEnabled in
            times.filter { iqamaTimes.timerIqama(for: $0, isTimerEnabled: isTimerEnabled, using: calendar) != nil }
        }

        #expect(times.contains { !$0.type.isObligation })
        #expect(counted.map(\.type) == [.asr])
    }

    /// San Francisco's fixture day is a Friday, so its Dhuhr counts to the khutba and the next day's to its own iqama.
    @Test
    func fridaysDhuhrCountsToTheKhutbaAndOnlyWhenOneIsSet() async throws {
        let place = try #require(DayFixture.all.first { $0.name == "San Francisco in June" })
        let calendar = try place.calendar()
        let day = try await day(of: place)
        let friday = try #require(day.times[.dhuhr])
        let saturday = try #require(day.tomorrow[.dhuhr])
        var iqamaTimes = IqamaTimes()
        iqamaTimes.dhuhr = .minutes(15)

        try #require(friday.isJumuah(using: calendar))
        #expect(iqamaTimes.timerIqama(for: friday, isTimerEnabled: true, using: calendar) == nil)
        #expect(iqamaTimes.timerIqama(for: saturday, isTimerEnabled: true, using: calendar) == saturday.dateInterval.start + 15 * 60)

        iqamaTimes.jumuah = .minutes(45)

        #expect(iqamaTimes.timerIqama(for: friday, isTimerEnabled: true, using: calendar) == friday.dateInterval.start + 45 * 60)
        #expect(iqamaTimes.timerIqama(for: friday, isTimerEnabled: false, using: calendar) == nil)
        #expect(iqamaTimes.timerIqama(for: saturday, isTimerEnabled: false, using: calendar) == nil)
    }

    @Test
    func theSettingsFollowTheirIqamaTimerSwitch() async throws {
        let place = try #require(DayFixture.all.first { $0.name == "Kuala Lumpur" })
        let calendar = try place.calendar()
        let maghrib = try #require(try await day(of: place).times[.maghrib])
        var settings = Settings()
        settings.iqamaTimes.maghrib = .minutes(10)

        #expect(settings.timerIqama(for: maghrib, using: calendar) == maghrib.dateInterval.start + 10 * 60)

        settings.isIqamaTimerEnabled = false

        #expect(settings.timerIqama(for: maghrib, using: calendar) == nil)
    }
}

// MARK: - Helpers

private extension TimerIqamaTests {
    func day(of place: DayFixture) async throws -> PrayerDay {
        try #require(try await place.days(1, using: fixture.prayerManager).first)
    }
}
