//
//  SettingsSoundsTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import PrayCore
import Testing

/// Silencing prayers through `Settings` matches silencing them through `Preferences` holding the same values.
struct SettingsSoundsTests {
    private let fixture = PrayTestFixture()

    @Test(arguments: [Settings(), .everyFieldChanged])
    func disablingSoundsMatchesPreferences(settings: Settings) {
        settings.write(to: fixture.preferences)
        #expect(settings.isPrayerSoundsDisabled == fixture.preferences.isPrayerSoundsDisabled)

        var disabled = settings
        disabled.disablePrayerSounds()
        fixture.preferences.disablePrayerSounds()

        #expect(disabled.isPrayerSoundsDisabled)
        #expect(disabled.notificationSounds == fixture.preferences.notificationSounds)
        #expect(disabled.reminderSounds == fixture.preferences.reminderSounds)
        #expect(disabled.iqamaTimes == fixture.preferences.iqamaTimes)
    }

    @Test
    func anIqamaTimeKeepsSoundsEnabled() {
        var settings = Settings()
        settings.disablePrayerSounds()
        settings.iqamaTimes = IqamaTimes(fajr: .minutes(20), dhuhr: nil, asr: nil, maghrib: nil, isha: nil, jumuah: nil)

        #expect(!settings.isPrayerSoundsDisabled)
    }
}
