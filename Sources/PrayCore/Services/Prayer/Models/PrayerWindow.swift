//
//  PrayerWindow.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-29.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import ZamzamCore

/// The stretch a Live Activity covers: from shortly before a prayer until its iqama, or until the prayer's time itself
/// when it has none, as for sunrise.
public struct PrayerWindow: Hashable, Codable, Sendable {
    public let prayer: Prayer
    public let isJumuah: Bool
    public let start: Date
    public let time: Date
    public let iqama: Date?

    public init(prayer: Prayer, isJumuah: Bool, start: Date, time: Date, iqama: Date?) {
        self.prayer = prayer
        self.isJumuah = isJumuah
        self.start = start
        self.time = time
        self.iqama = iqama
    }
}

public extension PrayerWindow {
    var end: Date { iqama ?? time }
}

public extension Settings {
    /// The windows in the days that haven't ended by `now`, earliest first. Each opens five minutes before the prayer's
    /// pre-adhan reminder, so its alert and the reminder's don't arrive together, or 30 minutes before the prayer
    /// without one. Fajr has none, so nothing wakes the night: its window is the one before sunrise, when Fajr's time
    /// runs out. The iqama follows the iqama timer, as the countdown faces do.
    func prayerWindows(in prayerDays: [PrayerDay], from now: Date, using calendar: Calendar) -> [PrayerWindow] {
        prayerDays
            .flatMap(\.times)
            .filter { $0.type.isEssential && $0.type != .fajr }
            .map { prayerTime in
                let time = prayerTime.dateInterval.start
                let reminderMinutes = preAdhanMinutes[prayerTime.type]
                let leadMinutes = reminderMinutes > 0 ? reminderMinutes + 5 : 30

                return PrayerWindow(
                    prayer: prayerTime.type,
                    isJumuah: prayerTime.isJumuah(using: calendar),
                    start: time - .minutes(leadMinutes),
                    time: time,
                    iqama: isIqamaTimerEnabled ? iqamaTimes[prayerTime, using: calendar] : nil
                )
            }
            .filter { $0.end > now }
            .sorted(by: \.start)
    }
}
