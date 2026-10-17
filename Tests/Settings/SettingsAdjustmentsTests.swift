//
//  SettingsAdjustmentsTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import PrayCore
import Testing

struct SettingsAdjustmentsTests {
    @Test
    func anAdjustmentIsSaved() throws {
        var settings = Settings()
        settings.editAdjustments { $0[.asr] = 5 }

        let adjustments = try #require(settings.adjustmentMinutes)
        #expect(adjustments[.asr] == 5)
    }

    @Test
    func adjustmentsBackToZeroSaveNone() {
        var settings = Settings()
        settings.editAdjustments { $0[.fajr] = -10 }
        settings.editAdjustments { $0[.fajr] = 0 }

        #expect(settings.adjustmentMinutes == nil)
    }

    @Test
    func aRelativeChoiceStaysBeforeAnyMinutesAreSet() throws {
        var settings = Settings()
        settings.editAdjustments { $0.isFajrSunriseRelative = true }

        let adjustments = try #require(settings.adjustmentMinutes)
        #expect(adjustments.isFajrSunriseRelative)
        #expect(adjustments[.fajr] == 0)

        settings.editAdjustments { $0.isFajrSunriseRelative = false }
        #expect(settings.adjustmentMinutes == nil)
    }

    @Test
    func countingFajrFromSunriseMovesItBeforeSunrise() {
        var settings = Settings()
        settings.adjustments[.fajr] = 10
        settings.adjustments.isFajrSunriseRelative = true

        #expect(settings.adjustments[.fajr] == -10)
        #expect(settings.adjustments.range(for: .fajr) == -300...0)
    }

    @Test
    func countingIshaFromMaghribMovesItAfterMaghrib() {
        var settings = Settings()
        settings.adjustments[.isha] = -15
        settings.adjustments.isIshaMaghribRelative = true

        #expect(settings.adjustments[.isha] == 15)
        #expect(settings.adjustments.range(for: .isha) == 0...300)
    }

    @Test
    func otherPrayersMoveUpToTwoHoursEitherWay() {
        let adjustments = Settings().adjustments

        #expect(adjustments.range(for: .fajr) == -120...120)
        #expect(adjustments.range(for: .asr) == -120...120)
    }

    @Test
    func editingThroughTheBindableAccessorFollowsTheSaveRule() throws {
        var settings = Settings()
        settings.adjustments[.dhuhr] = 3
        #expect(try #require(settings.adjustmentMinutes)[.dhuhr] == 3)

        settings.adjustments[.dhuhr] = 0
        #expect(settings.adjustmentMinutes == nil)
    }

    @Test
    func iqamaTimesAreReadAndWrittenByPrayer() {
        var times = IqamaTimes()
        times[.asr] = .minutes(10)
        times[.sunrise] = .minutes(5)

        #expect(times.asr == .minutes(10))
        #expect(times[.asr] == .minutes(10))
        #expect(times[.sunrise] == nil)
    }
}
