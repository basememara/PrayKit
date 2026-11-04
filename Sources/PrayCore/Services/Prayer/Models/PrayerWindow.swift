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
    public let next: Next

    public init(prayer: Prayer, isJumuah: Bool, start: Date, time: Date, iqama: Date?, next: Next) {
        self.prayer = prayer
        self.isJumuah = isJumuah
        self.start = start
        self.time = time
        self.iqama = iqama
        self.next = next
    }
}

public extension PrayerWindow {
    /// The prayer after a window's, which an activity points to once its window is over.
    struct Next: Hashable, Codable, Sendable {
        public let prayer: Prayer
        public let isJumuah: Bool
        public let time: Date

        public init(prayer: Prayer, isJumuah: Bool, time: Date) {
            self.prayer = prayer
            self.isJumuah = isJumuah
            self.time = time
        }

        /// Whether this prayer has a window, and so an activity, of its own; Fajr doesn't.
        public var hasWindow: Bool { prayer.hasWindow }
    }

    var end: Date { iqama ?? time }
}

public extension Settings {
    /// The windows in the days that haven't ended by `now`, earliest first. Each opens five minutes before the prayer's
    /// pre-adhan reminder, so its alert and the reminder's don't arrive together, or 30 minutes before the prayer
    /// without one. Fajr has none, so nothing wakes the night: its window is the one before sunrise, when Fajr's time
    /// runs out. The iqama follows the iqama timer, as the countdown faces do, and the next prayer comes from the
    /// window's own day, tomorrow's Fajr after Isha.
    func prayerWindows(in prayerDays: [PrayerDay], from now: Date, using calendar: Calendar) -> [PrayerWindow] {
        prayerDays
            .flatMap { day in
                day.times
                    .filter(\.type.hasWindow)
                    .compactMap { prayerTime in window(for: prayerTime, in: day, using: calendar) }
            }
            .filter { $0.end > now }
            .sorted(by: \.start)
    }
}

private extension Settings {
    /// `nil` only for a day without the day after it, which has no prayer to point to after Isha.
    func window(for prayerTime: PrayerTime, in day: PrayerDay, using calendar: Calendar) -> PrayerWindow? {
        let time = prayerTime.dateInterval.start
        guard let next = day.next(at: time) else { return nil }

        let reminderMinutes = preAdhanMinutes[prayerTime.type]
        let leadMinutes = reminderMinutes > 0 ? reminderMinutes + 5 : 30

        return PrayerWindow(
            prayer: prayerTime.type,
            isJumuah: prayerTime.isJumuah(using: calendar),
            start: time - .minutes(leadMinutes),
            time: time,
            iqama: isIqamaTimerEnabled ? iqamaTimes[prayerTime, using: calendar] : nil,
            next: PrayerWindow.Next(prayer: next.type, isJumuah: next.isJumuah(using: calendar), time: next.dateInterval.start)
        )
    }
}

private extension Prayer {
    var hasWindow: Bool { isEssential && self != .fajr }
}
