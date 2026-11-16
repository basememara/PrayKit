//
//  NotificationClearTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices
import Testing

/// With every prayer sound off, a scheduling run clears instead of planning, whoever calls it.
struct NotificationClearTests {
    @Test
    func everySoundOffClearsThePrayerNotifications() {
        var settings = Settings()
        settings.disablePrayerSounds()

        #expect(NotificationPlan.clearedCategories(for: settings) == [.main, .reminder, .calibrate])
    }

    @Test
    func noSoundsOrReminderTimesSetClearsThePrayerNotifications() {
        var settings = Settings()
        settings.notificationSounds = NotificationSounds(rawValue: [:])
        settings.preAdhanMinutes = PreAdhanMinutes(rawValue: [:])

        #expect(NotificationPlan.clearedCategories(for: settings) == [.main, .reminder, .calibrate])
    }

    @Test
    func oneReminderBackOnPlans() {
        var settings = Settings()
        settings.disablePrayerSounds()
        settings.preAdhanMinutes[.fajr] = 30

        #expect(NotificationPlan.clearedCategories(for: settings) == nil)
    }
}
