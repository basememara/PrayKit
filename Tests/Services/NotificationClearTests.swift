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
    func noSoundsSetClearsThePrayerNotifications() {
        var settings = Settings()
        settings.notificationSounds = NotificationSounds(rawValue: [:])
        settings.reminderSounds = ReminderSounds(rawValue: [:])

        #expect(NotificationPlan.clearedCategories(for: settings) == [.main, .reminder, .calibrate])
    }

    @Test
    func oneSoundBackOnPlans() {
        var settings = Settings()
        settings.disablePrayerSounds()
        settings.reminderSounds[.fajr] = .beep

        #expect(NotificationPlan.clearedCategories(for: settings) == nil)
    }
}
