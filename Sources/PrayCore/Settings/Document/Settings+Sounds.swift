//
//  Settings+Sounds.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation.NSURL

public extension Settings {
    /// Whether every prayer sound and reminder is off and no iqama time is set, so nothing is scheduled.
    var isPrayerSoundsDisabled: Bool {
        notificationSounds.rawValue.allSatisfy { $0.value == .off }
            && reminderSounds.rawValue.allSatisfy { $0.value == .off }
            && iqamaTimes.isEmpty
    }

    mutating func disablePrayerSounds() {
        Prayer.allCases.forEach {
            notificationSounds[$0] = .off
            reminderSounds[$0] = .off
        }

        iqamaTimes = IqamaTimes()
    }

    /// Whether a prayer's notification makes no sound: silent, off, or never set.
    func isMuted(_ prayer: Prayer) -> Bool {
        notificationSounds[prayer].map { [.silent, .off].contains($0) } ?? true
    }

    /// Mutes a prayer to silent, or unmutes it to the adhan for an obligatory prayer and a tone for the rest.
    mutating func setMuted(_ isMuted: Bool, for prayer: Prayer) {
        notificationSounds[prayer] = isMuted ? .silent : prayer.isObligation ? .adhan : .tone
    }

    /// The adhan the user chose for a prayer, in the length that prayer uses; Al-Aqsa when none is chosen.
    func adhanURL(for prayer: Prayer) -> URL? {
        (notificationAdhan[prayer] ?? .alAqsa).fileURL(for: prayer == .fajr ? .fajr : .long)
    }

    /// The adhan of the prayer under way at `date`: Sunrise's once Fajr ends, and Maghrib's without a day to go by.
    func adhanURL(at date: Date, in day: PrayerDay?) -> URL? {
        adhanURL(for: day?.current(at: date)?.type ?? .maghrib)
    }
}
