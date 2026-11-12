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

    func plan() -> NotificationPlan {
        NotificationPlan.make(
            days: days,
            settings: settings,
            request: request,
            requestHash: requestHash,
            now: now,
            iqamaUpdateOrigin: iqamaUpdateOrigin,
            budget: budget
        )
    }

    /// The plan as the applier hands it to the notification center: worded, with each `userInfo` built.
    func planned() throws -> ScheduleOutcome {
        try plan().outcome(localized: LocalizedStub(), timeZone: request.timeZone, calendar: calendar)
    }

    func legacy() async -> ScheduleOutcome {
        await LegacyNotificationSchedule.schedule(
            prayerDays: days,
            settings: settings,
            request: request,
            now: now,
            iqamaUpdateOrigin: iqamaUpdateOrigin,
            prayerRequestHash: requestHash,
            localized: LocalizedStub(),
            budget: budget,
            userNotification: LegacyNotificationRecorder()
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
            budget: 58
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

// MARK: - Wording

/// Wording that carries its arguments, so two runs that word a notification differently never read the same.
struct LocalizedStub: NotificationServiceLocalizable {
    let beaconNotificationBody = "beacon body"
    let beaconNotificationTitle = "beacon title"
    let calibrateNotificationBody = "calibrate body"

    func prayerNotificationBody(for prayerTime: PrayerTime, at time: String, using calendar: Calendar) -> String {
        "prayer \(Self.describe(prayerTime)) at \(time) jumuah \(prayerTime.isJumuah(using: calendar))"
    }

    func prayerNotificationReminder(for prayerTime: PrayerTime, using calendar: Calendar) -> String {
        "snooze \(Self.describe(prayerTime)) jumuah \(prayerTime.isJumuah(using: calendar))"
    }

    func prayerNotificationReminder(for prayerTime: PrayerTime, minutes: Int, using calendar: Calendar) -> String {
        "reminder \(Self.describe(prayerTime)) minutes \(minutes) jumuah \(prayerTime.isJumuah(using: calendar))"
    }

    func iqamaNotificationBody(for prayerTime: PrayerTime, minutes: Int, isJumuah: Bool) -> String {
        "iqama \(Self.describe(prayerTime)) minutes \(minutes) jumuah \(isJumuah)"
    }

    func duhaNotificationBody(at time: String) -> String {
        "duha at \(time)"
    }

    private static func describe(_ prayerTime: PrayerTime) -> String {
        "\(prayerTime.type.rawValue) \(prayerTime.dateInterval.start.timeIntervalSince1970) \(prayerTime.dateInterval.duration)"
    }
}

// MARK: - Plan as an outcome

extension NotificationPlan {
    func outcome(localized: NotificationServiceLocalizable, timeZone: TimeZone, calendar: Calendar) throws -> ScheduleOutcome {
        let timeFormatStyle = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)

        let removed = removals.map { removal -> ScheduleEntry in
            switch removal {
            case let .identifier(identifier):
                .removeIdentifier(identifier)
            case let .category(category):
                .removeCategory(category.rawValue)
            }
        }

        let added = try requests.map { request in
            ScheduleEntry.add(
                ScheduleEntry.Notification(
                    identifier: request.identifier,
                    trigger: ScheduleEntry.Trigger(request.trigger),
                    body: request.body.text(localized: localized, timeFormatStyle: timeFormatStyle, calendar: calendar),
                    title: request.body.title(localized: localized),
                    sound: request.sound.map(ScheduleEntry.Sound.init),
                    interruptionLevel: request.interruptionLevel,
                    category: request.category.rawValue,
                    userInfo: ScheduleEntry.values(of: try request.payload.userInfo())
                )
            )
        }

        return ScheduleOutcome(
            entries: removed + added,
            shortcutPrayers: shortcutPrayers,
            firstScheduled: firstScheduled,
            lastScheduled: lastScheduled,
            requested: requested
        )
    }
}

private extension ScheduleEntry.Trigger {
    init(_ trigger: NotificationPlan.Trigger) {
        switch trigger {
        case let .date(date):
            self = .date(date)
        #if os(iOS)
        case let .region(center, radius):
            self = .region(ScheduleEntry.Region(NotificationPlan.Trigger.homeRegion(center: center, radius: radius)))
        #endif
        }
    }
}

private extension ScheduleEntry.Sound {
    init(_ sound: NotificationPlan.Sound) {
        switch sound {
        case .default:
            self = .default
        case let .file(file):
            self = .file(file)
        }
    }
}

extension ScheduleOutcome {
    /// Where another outcome first parts from this one, or `nil` when they are the same.
    func firstDifference(from other: ScheduleOutcome) -> String? {
        let shared = min(entries.count, other.entries.count)

        if let index = (0..<shared).first(where: { entries[$0] != other.entries[$0] }) {
            return "entry \(index): \(other.entries[index]) became \(entries[index])"
        }

        guard entries.count == other.entries.count else {
            let extra = entries.count > shared ? "gained \(entries[shared])" : "lost \(other.entries[shared])"
            return "\(other.entries.count) entries became \(entries.count): \(extra)"
        }

        guard shortcutPrayers == other.shortcutPrayers else {
            return "\(other.shortcutPrayers.count) Siri prayers became \(shortcutPrayers.count), or changed"
        }

        guard firstScheduled == other.firstScheduled, lastScheduled == other.lastScheduled else {
            return "scheduled \(String(describing: other.firstScheduled)) to \(other.lastScheduled) became \(String(describing: firstScheduled)) to \(lastScheduled)"
        }

        return requested == other.requested ? nil : "requested \(other.requested) became \(requested)"
    }
}

extension ScheduleEntry: CustomStringConvertible {
    var description: String {
        switch self {
        case let .add(notification):
            "add \(notification)"
        case let .removeIdentifier(identifier):
            "remove \(identifier)"
        case let .removeCategory(category):
            "remove category \(category)"
        }
    }
}

extension ScheduleEntry.Notification: CustomStringConvertible {
    var description: String {
        let values = userInfo.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }

        return [
            identifier,
            "\(trigger)",
            "\"\(body)\"",
            "title \(title ?? "-")",
            "sound \(sound.map { "\($0)" } ?? "-")",
            "level \(interruptionLevel?.name ?? "-")",
            category,
            "userInfo \(values.joined(separator: ", "))"
        ].joined(separator: " | ")
    }
}

extension ScheduleEntry.Value: CustomStringConvertible {
    var description: String {
        switch self {
        case let .prayerTime(prayerTime):
            "\(prayerTime.type.rawValue) \(prayerTime.dateInterval.start) for \(prayerTime.dateInterval.duration)s"
        case let .requestHash(requestHash):
            requestHash.id
        case let .number(number):
            "\(number)"
        case let .text(text):
            text
        case let .unreadable(value):
            "unreadable \(value)"
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

// MARK: - Stamps

extension Snapshot {
    /// A date on the place's clock with its offset from UTC, which tells the two passes of a repeated hour apart.
    static func stamp(_ date: Date, using calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let offset = calendar.timeZone.secondsFromGMT(for: date)

        return String(format: "%04d-%02d-%02d ", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            + String(format: "%02d:%02d:%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
            + (offset < 0 ? "-" : "+")
            + String(format: "%02d%02d", abs(offset) / 3600, abs(offset) % 3600 / 60)
    }
}
