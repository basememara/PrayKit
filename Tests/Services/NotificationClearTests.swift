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
    func everySoundOffClearsThePrayerNotifications() throws {
        let settings = try #require(NotificationSettingsRow.row("all-off")).settings

        #expect(NotificationPlan.clearedCategories(for: settings) == [.main, .reminder, .calibrate])
    }

    @Test(arguments: ["defaults", "notification-sounds-off", "reminder-sounds-off", "everything-off", "silencing-adhans"])
    func anythingStillOnPlans(rowID: String) throws {
        let settings = try #require(NotificationSettingsRow.row(rowID)).settings

        #expect(NotificationPlan.clearedCategories(for: settings) == nil)
    }

    @Test
    func oneSoundBackOnPlans() throws {
        var settings = try #require(NotificationSettingsRow.row("all-off")).settings
        settings.reminderSounds[.fajr] = .beep

        #expect(NotificationPlan.clearedCategories(for: settings) == nil)
    }
}
