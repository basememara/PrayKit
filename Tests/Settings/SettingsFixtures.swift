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
        settings.reminderSounds = ReminderSounds(rawValue: ["asr": .beep, "isha": .off])
        settings.isPlayOnTapEnabled = false
        settings.isPrayerAbbrEnabled = true
        settings.sunriseAfterIsha = true
        settings.appearanceMode = .light
        settings.theme = .aqua
        return settings
    }()

    /// The settings as `Preferences` reads them, field by field.
    init(preferences: Preferences) {
        self.init()
        calculationMethod = preferences.calculationMethod
        juristicMethod = preferences.juristicMethod
        fajrDegrees = preferences.fajrDegrees
        maghribDegrees = preferences.maghribDegrees
        ishaDegrees = preferences.ishaDegrees
        elevationRule = preferences.elevationRule
        adjustmentMinutes = preferences.adjustmentMinutes
        adjustmentElevation = preferences.adjustmentElevation
        isGPSEnabled = preferences.isGPSEnabled
        geofenceRadius = preferences.geofenceRadius
        iqamaTimes = preferences.iqamaTimes
        iqamaReminders = preferences.iqamaReminders
        isIqamaTimerEnabled = preferences.isIqamaTimerEnabled
        isIqamaHidden = preferences.isIqamaHidden
        enable24hTimeFormat = preferences.enable24hTimeFormat
        hijriDayOffset = preferences.hijriDayOffset
        autoIncrementHijri = preferences.autoIncrementHijri
        stopwatchMinutes = preferences.stopwatchMinutes
        snoozeMinutes = preferences.snoozeMinutes
        preAdhanMinutes = preferences.preAdhanMinutes
        duhaReminder = preferences.duhaReminder
        adhanDuaa = preferences.adhanDuaa
        notificationAdhan = preferences.notificationAdhan
        notificationSounds = preferences.notificationSounds
        reminderSounds = preferences.reminderSounds
        isPlayOnTapEnabled = preferences.isPlayOnTapEnabled
        isPrayerAbbrEnabled = preferences.isPrayerAbbrEnabled
        sunriseAfterIsha = preferences.sunriseAfterIsha
        appearanceMode = preferences.appearanceMode
        theme = preferences.theme
    }

    /// Writes every field through `Preferences`, the way the app does today.
    func write(to preferences: Preferences) {
        preferences.calculationMethod = calculationMethod
        preferences.juristicMethod = juristicMethod
        preferences.fajrDegrees = fajrDegrees
        preferences.maghribDegrees = maghribDegrees
        preferences.ishaDegrees = ishaDegrees
        preferences.elevationRule = elevationRule
        preferences.adjustmentMinutes = adjustmentMinutes
        preferences.adjustmentElevation = adjustmentElevation
        preferences.isGPSEnabled = isGPSEnabled
        preferences.geofenceRadius = geofenceRadius
        preferences.iqamaTimes = iqamaTimes
        preferences.iqamaReminders = iqamaReminders
        preferences.isIqamaTimerEnabled = isIqamaTimerEnabled
        preferences.isIqamaHidden = isIqamaHidden
        preferences.enable24hTimeFormat = enable24hTimeFormat
        preferences.hijriDayOffset = hijriDayOffset
        preferences.autoIncrementHijri = autoIncrementHijri
        preferences.stopwatchMinutes = stopwatchMinutes
        preferences.snoozeMinutes = snoozeMinutes
        preferences.preAdhanMinutes = preAdhanMinutes
        preferences.duhaReminder = duhaReminder
        preferences.adhanDuaa = adhanDuaa
        preferences.notificationAdhan = notificationAdhan
        preferences.notificationSounds = notificationSounds
        preferences.reminderSounds = reminderSounds
        preferences.isPlayOnTapEnabled = isPlayOnTapEnabled
        preferences.isPrayerAbbrEnabled = isPrayerAbbrEnabled
        preferences.sunriseAfterIsha = sunriseAfterIsha
        preferences.appearanceMode = appearanceMode
        preferences.theme = theme
    }
}
