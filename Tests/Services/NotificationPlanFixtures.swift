//
//  NotificationPlanFixtures.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices
import Testing
import UserNotifications
import ZamzamCore

// MARK: - Input

/// Everything one scheduling run decides from, with the days fetched as the scheduler fetches them.
struct ScheduleInput: Sendable {
    let days: [PrayerDay]
    let settings: Settings
    let request: PrayerAPI.Request
    let now: Date
    let iqamaUpdateOrigin: Date?
    let budget: Int

    var calendar: Calendar {
        Calendar(identifier: .gregorian, timeZone: request.timeZone)
    }

    var week: DateInterval {
        DateInterval(start: now, end: now + .weeks(1, calendar))
    }

    var requestHash: PrayerRequestHash {
        PrayerRequestHash(request: request, dateInterval: week, settings: settings)
    }

    func with(settings: Settings, budget: Int, iqamaUpdateOrigin: Date?) -> ScheduleInput {
        ScheduleInput(days: days, settings: settings, request: request, now: now, iqamaUpdateOrigin: iqamaUpdateOrigin, budget: budget)
    }

    /// The iPhone's plan unless asked otherwise, so every branch is taken on every platform the tests run on.
    func plan(schedulesBeacon: Bool = true) -> NotificationPlan {
        NotificationPlan.make(
            days: days,
            settings: settings,
            request: request,
            requestHash: requestHash,
            now: now,
            iqamaUpdateOrigin: iqamaUpdateOrigin,
            schedulesBeacon: schedulesBeacon,
            budget: budget
        )
    }
}

extension DayFixture {
    /// The fixture's week from a moment, at the defaults: the scheduler's own fetch.
    func scheduleInput(at moment: ScheduleMoment, using prayerManager: PrayerManager) async throws -> ScheduleInput {
        let request = try request()
        let calendar = try calendar()
        let now = try await date(of: moment, using: prayerManager)
        let week = DateInterval(start: now, end: now + .weeks(1, calendar))

        return ScheduleInput(
            days: try await prayerManager.fetch(spanning: week, with: request),
            settings: Settings(),
            request: request,
            now: now,
            iqamaUpdateOrigin: nil,
            budget: NotificationPlan.defaultBudget
        )
    }

    private func date(of moment: ScheduleMoment, using prayerManager: PrayerManager) async throws -> Date {
        let request = try request()
        let calendar = try calendar()
        let noon = try firstNoon()
        let friday = try #require((0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: noon) }.first { $0.isJumuah(using: calendar) })
        let firstDay = try await prayerManager.fetch(for: noon, with: request).times
        let fridayDay = try await prayerManager.fetch(for: friday, with: request).times

        switch moment {
        case .beforeFajr:
            return try #require(firstDay[.fajr]).dateInterval.start - 3600
        case .midMorning:
            return try date(year, month, day, 10)
        case .afterDhuhr:
            return try #require(firstDay[.dhuhr]).dateInterval.start + 300
        case .afterIsha:
            return try #require(firstDay[.isha]).dateInterval.start + 1800
        case .fridayMorning:
            return try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: friday))
        case .fridayAfterDhuhr:
            return try #require(fridayDay[.dhuhr]).dateInterval.start + 300
        }
    }
}

/// When a run happens, against the fixture's first day or the first Friday from it.
enum ScheduleMoment: String, CaseIterable, Sendable {
    case beforeFajr = "an hour before Fajr"
    case midMorning = "10:00"
    case afterDhuhr = "5 minutes after Dhuhr"
    case afterIsha = "30 minutes after Isha"
    case fridayMorning = "Friday 09:00"
    case fridayAfterDhuhr = "Friday, 5 minutes after Dhuhr"
}

/// The stored origin of the iqama update reminder, against the moment and the reminder's interval.
enum ScheduleOrigin: String, CaseIterable, Sendable {
    case absent
    case inside
    case boundary
    case outside
    case ahead

    func date(from now: Date, interval: TimeInterval) -> Date? {
        switch self {
        case .absent:
            nil
        case .inside:
            now - interval / 2
        case .boundary:
            now - interval
        case .outside:
            now - interval - 3600
        case .ahead:
            now + 3600
        }
    }
}

// MARK: - Requests

extension NotificationPlan.Request {
    /// The prayer a request is for; the iqama update, calibrate and the beacon are for none.
    var prayerTime: PrayerTime? {
        guard case let .prayerTime(prayerTime) = payload else { return nil }
        return prayerTime
    }

    var fireDate: Date? {
        switch trigger {
        case let .date(date):
            date
        case .region:
            nil
        }
    }
}

extension UNNotificationInterruptionLevel {
    var name: String {
        switch self {
        case .passive:
            "passive"
        case .active:
            "active"
        case .timeSensitive:
            "timeSensitive"
        case .critical:
            "critical"
        @unknown default:
            "level \(rawValue)"
        }
    }
}
