//
//  NotificationPlanRangeTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices
import Testing
import ZamzamCore

/// Where a plan's scheduled range ends, which decides when calibrate asks for the app to be opened and when the
/// background refresh is due: at the last adhan, or with every adhan off, where a spent budget stopped.
struct NotificationPlanRangeTests {
    private let fixture = PrayTestFixture()
}

extension NotificationPlanRangeTests {
    /// About twelve reminders a day spend the budget in under five days, with no adhan to mark where they stop.
    @Test
    func calibrateComesBeforeTheLastReminderWhenEveryAdhanIsOff() async throws {
        let input = try await input { settings in
            Prayer.allCases.forEach { settings.notificationSounds[$0] = .off }
            [Prayer.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha].forEach { settings.reminderSounds[$0] = .beep }
            settings.preAdhanMinutes = PreAdhanMinutes(rawValue: ["fajr": 30, "sunrise": 15, "dhuhr": 20, "asr": 25, "maghrib": 10, "isha": 35, "imsak": 10])
            settings.iqamaTimes = IqamaTimes(fajr: .minutes(20), dhuhr: .minutes(15), asr: .minutes(15), maghrib: .minutes(5), isha: .minutes(10), jumuah: nil)
            settings.iqamaReminders = IqamaReminders(sound: .iqama, minutes: 10, jumuahMinutes: 45, updateInterval: .off)
        }

        let plan = input.plan()
        let lastReminder = try #require(plan.lastPrayerRequest)
        let calibrate = try #require(plan.calibrate)

        try #require(plan.requested == input.budget)
        try #require(lastReminder < input.week.end - .days(1, input.calendar))

        #expect(calibrate <= lastReminder - .hours(12))
        #expect(plan.lastScheduled == lastReminder)
    }

    /// One reminder a day leaves most of the budget, so the week is fully scheduled and its end stands. Ending the
    /// range at the last request here would put calibrate in the past on the reminder's own day.
    @Test
    func calibrateStaysAWeekOutWhenAFewRemindersLeaveTheBudgetUnspent() async throws {
        let input = try await input { settings in
            Prayer.allCases.forEach {
                settings.notificationSounds[$0] = .off
                settings.reminderSounds[$0] = .off
            }

            settings.reminderSounds[.dhuhr] = .beep
        }

        let plan = input.plan()
        let calibrate = try #require(plan.calibrate)

        try #require(plan.lastPrayerRequest != nil)
        try #require(plan.requested < input.budget)

        #expect(plan.lastScheduled == input.week.end)
        #expect(calibrate == input.week.end - .hours(12))
    }

    @Test
    func calibrateComesTwelveHoursBeforeTheLastAdhanAtTheDefaults() async throws {
        let input = try await input()
        let plan = input.plan()
        let lastAdhan = try #require(plan.lastPrayerRequest)

        try #require(plan.requests.contains { $0.category == .main && $0.fireDate == lastAdhan })

        #expect(plan.calibrate == lastAdhan - .hours(12))
        #expect(plan.lastScheduled == lastAdhan)
    }
}

private extension NotificationPlanRangeTests {
    /// Kuala Lumpur's week from 10:00, on the budget the app runs with.
    func input(_ change: (inout Settings) -> Void = { _ in }) async throws -> ScheduleInput {
        let place = try #require(DayFixture.all.first { $0.name == "Kuala Lumpur" })
        let week = try await place.scheduleInput(at: .midMorning, using: fixture.prayerManager)
        var settings = week.settings
        change(&settings)

        return week.with(settings: settings, budget: week.budget, iqamaUpdateOrigin: nil)
    }
}

private extension NotificationPlan {
    /// When the last of the prayers' own notifications fires: an adhan, an iqama or a reminder.
    var lastPrayerRequest: Date? {
        requests.filter { $0.prayerTime != nil }.compactMap(\.fireDate).max()
    }

    var calibrate: Date? {
        requests.first { $0.category == .calibrate }?.fireDate
    }
}
