//
//  PrayerScheduleTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import PrayServices
import Testing
import ZamzamCore

/// The timeline built from a `Settings` value matches the one built from `Preferences` holding the same values.
struct PrayerScheduleTests {
    private let fixture = PrayTestFixture()

    @Test(arguments: [
        PrayerManager.Expanded.none,
        .intervals(0),
        .intervals(5),
        .hourly,
        .finalHour
    ])
    func settingsBuildTheSameTimelineAsPreferences(expanded: PrayerManager.Expanded) async throws {
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let date = try #require(DateFormatter(dateFormat: "yyyy/MM/dd HH:mm", timeZone: timeZone).date(from: "2022/02/25 06:00"))
        let place = Place(coordinates: Coordinates(latitude: 43.651070, longitude: -79.347015), timeZone: timeZone, regionName: nil, fixedAt: nil)

        var settings = Settings()
        settings.calculationMethod = .northAmerica
        settings.preAdhanMinutes = PreAdhanMinutes(rawValue: ["fajr": 34, "sunrise": 27, "dhuhr": 14, "asr": 16, "maghrib": 22, "isha": 9])
        settings.iqamaTimes = IqamaTimes(
            fajr: .time(hour: 6, minutes: 31),
            dhuhr: .minutes(12),
            asr: .time(hour: 16, minutes: 38),
            maghrib: .minutes(8),
            isha: nil,
            jumuah: .time(hour: 13, minutes: 30)
        )
        settings.stopwatchMinutes = 18
        settings.sunriseAfterIsha = true
        settings.write(to: fixture.preferences)
        fixture.preferences.set(manualAddress: place.coordinates, timeZone: timeZone, regionName: nil)
        fixture.preferences.calculationMethod = .northAmerica

        let fromPreferences = try await fixture.prayerManager.fetch(
            from: date,
            expanded: expanded,
            limit: 40,
            with: try #require(PrayerAPI.Request(from: fixture.preferences))
        )

        let fromSettings = try await fixture.prayerManager.fetch(
            from: date,
            expanded: expanded,
            limit: 40,
            with: try #require(PrayerAPI.Request(settings: settings, place: place)),
            settings: settings,
            timeZone: timeZone
        )

        #expect(!fromSettings.isEmpty)
        #expect(fromSettings == fromPreferences)
    }

    @Test
    func aRequestNeedsAPlace() {
        #expect(PrayerAPI.Request(settings: Settings(), place: nil) == nil)
    }
}
