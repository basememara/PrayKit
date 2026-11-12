//
//  SettingsHijriTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing
import ZamzamCore

struct SettingsHijriTests {
    private let fixture = PrayTestFixture()
}

extension SettingsHijriTests {
    /// With auto-increment the date is a day on from the plain offset's on one side of Maghrib and not the other.
    @Test(arguments: DayFixture.all)
    func theSweepCrossesTheMaghribTurn(place: DayFixture) async throws {
        let timeZone = try place.request().timeZone
        let day = try #require(try await place.days(1, using: fixture.prayerManager).first)
        let maghrib = try #require(day.times[.maghrib]).dateInterval.start
        let locale = Locale(identifier: "en_US")
        let turns = { (moment: Date) in
            Self.settings(offset: 0, autoIncrement: true).hijriString(at: moment, in: day, timeZone: timeZone, locale: locale)
                != Self.settings(offset: 0, autoIncrement: false).hijriString(at: moment, in: day, timeZone: timeZone, locale: locale)
        }

        #expect(turns(maghrib - 1) != turns(maghrib))
    }
}

// MARK: - Helpers

private extension SettingsHijriTests {
    static func settings(offset: Int, autoIncrement: Bool) -> Settings {
        var settings = Settings()
        settings.hijriDayOffset = offset
        settings.autoIncrementHijri = autoIncrement
        return settings
    }
}
