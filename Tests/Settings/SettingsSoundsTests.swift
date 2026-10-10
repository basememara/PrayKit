//
//  SettingsSoundsTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import PrayCore
import Testing

struct SettingsSoundsTests {
    @Test
    func theDefaultsAreNotDisabled() {
        #expect(!Settings().isPrayerSoundsDisabled)
    }

    @Test(arguments: [Settings(), .everyFieldChanged])
    func disablingTurnsEverySoundOffAndClearsTheIqamaTimes(settings: Settings) {
        var disabled = settings
        disabled.disablePrayerSounds()

        #expect(disabled.isPrayerSoundsDisabled)
        #expect(disabled.iqamaTimes == IqamaTimes())

        Prayer.allCases.forEach { prayer in
            #expect(disabled.notificationSounds[prayer] == .off, "\(prayer)")
            #expect(disabled.reminderSounds[prayer] == .off, "\(prayer)")
        }
    }

    @Test
    func anIqamaTimeKeepsSoundsEnabled() {
        var settings = Settings()
        settings.disablePrayerSounds()
        settings.iqamaTimes = IqamaTimes(fajr: .minutes(20), dhuhr: nil, asr: nil, maghrib: nil, isha: nil, jumuah: nil)

        #expect(!settings.isPrayerSoundsDisabled)
    }
}
