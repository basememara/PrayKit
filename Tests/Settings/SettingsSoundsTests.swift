//
//  SettingsSoundsTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
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
    func unmutingRestoresTheSoundChosenBeforeMuting() {
        var settings = Settings()
        settings.notificationSounds[.dhuhr] = .chimes

        settings.setMuted(true, for: .dhuhr)
        #expect(settings.isMuted(.dhuhr))
        #expect(settings.notificationSounds[.dhuhr] == .silent)

        settings.setMuted(true, for: .dhuhr)
        settings.setMuted(false, for: .dhuhr)
        #expect(settings.notificationSounds[.dhuhr] == .chimes)
        #expect(settings.soundsBeforeMute[.dhuhr] == nil)
    }

    @Test
    func unmutingWithNothingRememberedPicksTheDefaultSound() {
        var settings = Settings()
        settings.notificationSounds[.dhuhr] = .off

        settings.setMuted(false, for: .dhuhr)
        settings.setMuted(false, for: .sunrise)

        #expect(settings.notificationSounds[.dhuhr] == .adhan)
        #expect(settings.notificationSounds[.sunrise] == .tone)
    }

    @Test
    func unmutingAPrayerThatIsNotMutedKeepsItsSound() {
        var settings = Settings()
        settings.notificationSounds[.asr] = .beep

        settings.setMuted(false, for: .asr)

        #expect(settings.notificationSounds[.asr] == .beep)
    }

    @Test
    func theAdhanPlayedFollowsThePrayerUnderWay() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let hours: [(Prayer, Double)] = [(.fajr, 5), (.sunrise, 6.5), (.dhuhr, 12), (.asr, 15.5), (.maghrib, 18), (.isha, 19.5)]
        let times = hours.enumerated().map { index, entry in
            let end = index + 1 < hours.count ? hours[index + 1].1 : 29
            return PrayerTime(type: entry.0, dateInterval: DateInterval(start: start + entry.1 * 3600, end: start + end * 3600))
        }
        let day = PrayerDay(date: start, times: times, yesterday: [], tomorrow: [])

        var settings = Settings()
        settings.notificationAdhan[.fajr] = .makkah
        settings.notificationAdhan[.sunrise] = .madina
        settings.notificationAdhan[.maghrib] = .cairo

        let fajr = try #require(settings.adhanURL(for: .fajr))
        let sunrise = try #require(settings.adhanURL(for: .sunrise))

        #expect(settings.adhanURL(at: start + 5.5 * 3600, in: day) == fajr)
        #expect(settings.adhanURL(at: start + 9 * 3600, in: day) == sunrise)
        #expect(settings.adhanURL(at: start + 9 * 3600, in: nil) == settings.adhanURL(for: .maghrib))
    }
}
