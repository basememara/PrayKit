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
    func aRelativeChoiceSavedWithoutMinutesReadsAsTheEngineUsesIt() {
        // Saved before relative minutes were kept at least one away, or by an older version: the engine uses the angle
        var settings = Settings()
        settings.adjustmentMinutes = AdjustmentMinutes(rawValue: ["is_fajr_sunrise_relative": 1, "is_isha_maghrib_relative": 1])

        #expect(!settings.adjustments.isFajrSunriseRelative)
        #expect(!settings.adjustments.isIshaMaghribRelative)

        settings.editAdjustments { $0[.asr] = 0 }
        #expect(settings.adjustmentMinutes == nil)
    }

    @Test
    func aRelativeChoiceSavedWithMinutesStaysRelativeWhicheverSideTheyFall() {
        // Prayer times must not move for anyone: the engine has always taken any non-zero minutes as relative
        let adjustments = AdjustmentMinutes(rawValue: ["fajr": 2, "is_fajr_sunrise_relative": 1, "isha": -5, "is_isha_maghrib_relative": 1])

        #expect(adjustments.isFajrSunriseRelative)
        #expect(adjustments.isIshaMaghribRelative)
    }

    @Test
    func adjustmentsBackToZeroSaveNone() {
        var settings = Settings()
        settings.editAdjustments { $0[.fajr] = -10 }
        settings.editAdjustments { $0[.fajr] = 0 }

        #expect(settings.adjustmentMinutes == nil)
    }

    /// Zero minutes from sunrise would leave fajr on its angle, so counting from sunrise starts a minute before it.
    @Test
    func countingFajrFromSunriseStartsAMinuteBeforeIt() throws {
        var settings = Settings()
        settings.editAdjustments { $0.isFajrSunriseRelative = true }

        let adjustments = try #require(settings.adjustmentMinutes)
        #expect(adjustments.isFajrSunriseRelative)
        #expect(adjustments[.fajr] == -1)
    }

    @Test
    func countingIshaFromMaghribStartsAMinuteAfterIt() throws {
        var settings = Settings()
        settings.editAdjustments { $0.isIshaMaghribRelative = true }

        let adjustments = try #require(settings.adjustmentMinutes)
        #expect(adjustments.isIshaMaghribRelative)
        #expect(adjustments[.isha] == 1)
    }

    @Test
    func turningRelativeOffAgainLeavesNoAdjustment() {
        var settings = Settings()
        settings.editAdjustments { $0.isFajrSunriseRelative = true }
        settings.editAdjustments { $0.isFajrSunriseRelative = false }

        #expect(settings.adjustmentMinutes == nil)
    }

    @Test
    func turningRelativeOffReturnsThePrayerToItsMethod() {
        var settings = Settings()
        settings.adjustments[.isha] = 90
        settings.adjustments.isIshaMaghribRelative = true
        settings.adjustments.isIshaMaghribRelative = false

        #expect(settings.adjustments[.isha] == 0)
    }

    @Test
    func turningRelativeOffWhenItIsOffKeepsTheMinutes() {
        var settings = Settings()
        settings.adjustments[.fajr] = 5
        settings.adjustments.isFajrSunriseRelative = false

        #expect(settings.adjustments[.fajr] == 5)
    }

    @Test
    func countingFajrFromSunriseMovesItBeforeSunrise() {
        var settings = Settings()
        settings.adjustments[.fajr] = 10
        settings.adjustments.isFajrSunriseRelative = true

        #expect(settings.adjustments[.fajr] == -10)
        #expect(settings.adjustments.range(for: .fajr) == -300...(-1))
    }

    @Test
    func countingIshaFromMaghribMovesItAfterMaghrib() {
        var settings = Settings()
        settings.adjustments[.isha] = -15
        settings.adjustments.isIshaMaghribRelative = true

        #expect(settings.adjustments[.isha] == 15)
        #expect(settings.adjustments.range(for: .isha) == 1...300)
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
