//
//  NotificationService.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-06-06.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSDateInterval

public protocol NotificationService: Sendable {
    func schedulePrayers(silencingAdhans: Bool) async

    @discardableResult
    func addSnooze(for prayerTime: PrayerTime, in timeInterval: TimeInterval?) async -> Date

    var hasSnooze: Bool { get async }
    func removeSnooze() async

    /// Clears the delivered notifications the settings say go when the one with `identifier` is opened, swiped away
    /// or snoozed (`Settings.deliveredToClear`).
    func clearDelivered(touching identifier: String) async
}

public extension NotificationService {
    func schedulePrayers() async {
        await schedulePrayers(silencingAdhans: false)
    }

    @discardableResult
    func addSnooze(for prayerTime: PrayerTime) async -> Date {
        await addSnooze(for: prayerTime, in: nil)
    }
}
