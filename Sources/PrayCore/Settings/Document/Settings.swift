//
//  Settings.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

/// The choices a user makes in the app, as one value. A `nil` field is a choice too, such as Duha turned off.
public struct Settings: Codable, Equatable, Sendable {
    // Calculation
    public var calculationMethod: CalculationMethod = .moonsightingCommittee
    public var juristicMethod: Madhab = .standard
    public var fajrDegrees: Double = 0
    public var maghribDegrees: Double = 0
    public var ishaDegrees: Double = 0
    public var elevationRule: ElevationRule?

    // Adjustments
    public var adjustmentMinutes: AdjustmentMinutes?
    public var adjustmentElevation: ElevationRule?

    // Location
    public var isGPSEnabled = true
    public var geofenceRadius: Double = 75_000

    // Iqama
    public var iqamaTimes = IqamaTimes()
    public var iqamaReminders = IqamaReminders(sound: .iqama, minutes: 20, jumuahMinutes: 60, updateInterval: .off)
    public var isIqamaTimerEnabled = true
    public var isIqamaHidden = false

    // Time
    public var enable24hTimeFormat = false
    public var hijriDayOffset = 0
    public var autoIncrementHijri = true
    public var stopwatchMinutes = 0

    // Notification
    public var snoozeMinutes = 30
    public var preAdhanMinutes = PreAdhanMinutes(
        rawValue: [
            Prayer.fajr.rawValue: 0,
            Prayer.sunrise.rawValue: 20,
            Prayer.dhuhr.rawValue: 20,
            Prayer.asr.rawValue: 20,
            Prayer.maghrib.rawValue: 20,
            Prayer.isha.rawValue: 20
        ]
    )
    public var duhaReminder: DuhaType?
    public var adhanDuaa: AdhanDuaa = .off

    // Sound
    public var notificationAdhan = NotificationAdhan(
        rawValue: [
            Prayer.fajr.rawValue: .alAqsa,
            Prayer.sunrise.rawValue: .alAqsa,
            Prayer.dhuhr.rawValue: .alAqsa,
            Prayer.asr.rawValue: .alAqsa,
            Prayer.maghrib.rawValue: .alAqsa,
            Prayer.isha.rawValue: .alAqsa
        ]
    )
    public var notificationSounds = NotificationSounds(
        rawValue: [
            Prayer.fajr.rawValue: .adhan,
            Prayer.sunrise.rawValue: .silent,
            Prayer.dhuhr.rawValue: .adhan,
            Prayer.asr.rawValue: .adhan,
            Prayer.maghrib.rawValue: .adhan,
            Prayer.isha.rawValue: .adhan,
            Prayer.midnight.rawValue: .off,
            Prayer.lastThird.rawValue: .off
        ]
    )
    /// The sound each muted prayer had, so unmuting brings it back.
    public var soundsBeforeMute = NotificationSounds(rawValue: [:])
    public var reminderSounds = ReminderSounds(
        rawValue: [
            Prayer.fajr.rawValue: .default,
            Prayer.sunrise.rawValue: .default,
            Prayer.dhuhr.rawValue: .default,
            Prayer.asr.rawValue: .default,
            Prayer.maghrib.rawValue: .default,
            Prayer.isha.rawValue: .default,
            Prayer.midnight.rawValue: .off,
            Prayer.lastThird.rawValue: .off
        ]
    )
    public var isPlayOnTapEnabled = true

    // Display
    public var isPrayerAbbrEnabled = false
    public var sunriseAfterIsha = false
    public var appearanceMode: AppearanceMode = .dark
    public var theme: AppTheme = .default

    // Device
    public var isPrayerActivityEnabled = false
    public var matchesAppIcon = false

    public init() {}
}

/// A setting's stable name: its key in the defaults suite and its field name on the wire.
public enum SettingKey: String, CaseIterable, Sendable {
    case calculationMethod
    case juristicMethod
    case fajrDegrees
    case maghribDegrees
    case ishaDegrees
    case elevationRule = "elavationMethod"
    case adjustmentMinutes
    case adjustmentElevation
    case isGPSEnabled
    case geofenceRadius
    case iqamaTimes
    case iqamaReminders
    case isIqamaTimerEnabled
    case isIqamaHidden
    case enable24hTimeFormat
    case hijriDayOffset
    case autoIncrementHijri
    case stopwatchMinutes
    case snoozeMinutes
    case preAdhanMinutes
    case duhaReminder
    case adhanDuaa
    case notificationAdhan
    case notificationSounds
    case soundsBeforeMute
    case reminderSounds
    case isPlayOnTapEnabled
    case isPrayerAbbrEnabled
    case sunriseAfterIsha
    case appearanceMode
    case theme
    case isPrayerActivityEnabled
    case matchesAppIcon
}

public extension SettingKey {
    /// Whether the setting follows the user to their other devices, as its row in the field table says.
    var isSynced: Bool {
        Settings.fields.contains { $0.key == self && $0.isSynced }
    }

    /// The defaults key holding the setting's revision, next to its value.
    var revisionKey: String {
        "\(rawValue)At"
    }
}
