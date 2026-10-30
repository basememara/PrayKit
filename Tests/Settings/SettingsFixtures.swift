//
//  SettingsFixtures.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import PrayCore

extension Settings {
    /// Every field moved off its default, so a field missing from a code path shows up as a mismatch.
    static let everyFieldChanged: Settings = {
        var settings = Settings()
        settings.calculationMethod = .turkey
        settings.juristicMethod = .hanafi
        settings.fajrDegrees = 18.5
        settings.maghribDegrees = 4
        settings.ishaDegrees = 17
        settings.elevationRule = .seventhOfTheNight
        settings.adjustmentMinutes = AdjustmentMinutes(rawValue: ["fajr": 2, "isha": -3, "is_fajr_sunrise_relative": 1])
        settings.adjustmentElevation = .twilightAngle
        settings.isGPSEnabled = false
        settings.geofenceRadius = 20_000
        settings.iqamaTimes = IqamaTimes(
            fajr: .minutes(20),
            dhuhr: .time(hour: 13, minutes: 30),
            asr: nil,
            maghrib: .minutes(5),
            isha: nil,
            jumuah: .time(hour: 13, minutes: 0)
        )
        settings.iqamaReminders = IqamaReminders(sound: .chime, minutes: 10, jumuahMinutes: 30, updateInterval: .weekly)
        settings.isIqamaTimerEnabled = false
        settings.isIqamaHidden = true
        settings.enable24hTimeFormat = true
        settings.hijriDayOffset = -1
        settings.autoIncrementHijri = false
        settings.stopwatchMinutes = 15
        settings.snoozeMinutes = 10
        settings.preAdhanMinutes = PreAdhanMinutes(rawValue: ["fajr": 30, "dhuhr": 5])
        settings.duhaReminder = .time(hour: 8, minutes: 15)
        settings.adhanDuaa = .wasilahFadilah
        settings.notificationAdhan = NotificationAdhan(rawValue: ["fajr": .abdulBasit, "isha": .ahmadAlBatal])
        settings.notificationSounds = NotificationSounds(rawValue: ["fajr": .chimes, "maghrib": .silent])
        settings.soundsBeforeMute = NotificationSounds(rawValue: ["maghrib": .beep])
        settings.reminderSounds = ReminderSounds(rawValue: ["asr": .beep, "isha": .off])
        settings.isPlayOnTapEnabled = false
        settings.isPrayerAbbrEnabled = true
        settings.sunriseAfterIsha = true
        settings.appearanceMode = .light
        settings.theme = .aqua
        settings.isPrayerActivityEnabled = true
        settings.matchesAppIcon = true
        return settings
    }()

    /// These settings as another device receives them: the ones each device keeps for itself stay at their defaults.
    var synced: Settings {
        var settings = self
        settings.geofenceRadius = Settings().geofenceRadius
        settings.isPrayerActivityEnabled = Settings().isPrayerActivityEnabled
        settings.matchesAppIcon = Settings().matchesAppIcon
        return settings
    }
}
