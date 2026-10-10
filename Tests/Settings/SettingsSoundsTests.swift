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

    @Test
    func fajrPlaysItsOwnAdhanLength() {
        var settings = Settings()
        settings.notificationAdhan[.fajr] = .makkah
        settings.notificationAdhan[.dhuhr] = .makkah

        #expect(settings.adhanURL(for: .fajr)?.lastPathComponent == "makkah-fajr.mp3")
        #expect(settings.adhanURL(for: .dhuhr)?.lastPathComponent == "makkah.mp3")
    }

    @Test
    func mutingSilencesAndUnmutingRestoresTheDefaultSound() {
        var settings = Settings()

        settings.setMuted(true, for: .dhuhr)
        #expect(settings.isMuted(.dhuhr))
        #expect(settings.notificationSounds[.dhuhr] == .silent)

        settings.setMuted(false, for: .dhuhr)
        settings.setMuted(false, for: .sunrise)
        #expect(settings.notificationSounds[.dhuhr] == .adhan)
        #expect(settings.notificationSounds[.sunrise] == .tone)
        #expect(!settings.isMuted(.sunrise))
    }
}
