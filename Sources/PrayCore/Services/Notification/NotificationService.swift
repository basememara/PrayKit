//
//  NotificationService.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-06-06.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSDateInterval

public protocol NotificationService {
    func schedulePrayers() async

    @discardableResult
    func addSnooze(for prayerTime: PrayerTime, in timeInterval: TimeInterval?) -> Date

    var hasSnooze: Bool { get async }
    func removeSnooze() async
}

public extension NotificationService {
    @discardableResult
    func addSnooze(for prayerTime: PrayerTime) -> Date {
        addSnooze(for: prayerTime, in: nil)
    }
}

// MARK: - Namespace

public enum NotificationAPI {}
