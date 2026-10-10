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

    /// The adhan the user chose for a prayer, in the length that prayer uses; Al-Aqsa when none is chosen.
    func adhanURL(for prayer: Prayer) -> URL? {
        (notificationAdhan[prayer] ?? .alAqsa).fileURL(for: prayer == .fajr ? .fajr : .long)
    }
}
