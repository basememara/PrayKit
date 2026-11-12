//
//  LegacyNotificationSchedule.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import CoreLocation
import Foundation
import PrayCore
@testable import PrayServices
import UserNotifications
import ZamzamCore

/// What the scheduler decided before the decision moved into `NotificationPlan`, frozen as it stood at `0208839`:
/// the body of `NotificationServiceUN.scheduleOnce` from its fetched days through its beacon block, copied line for
/// line, talking to a recorder in place of the notification center. `NotificationPlanDifferentialTests` holds the
/// plan to it; change nothing here.
///
/// The copy differs from the original only where it must: the moment and the budget come in as parameters, the log
/// lines are gone, and a Siri shortcut is recorded as its prayer on every platform.
enum LegacyNotificationSchedule {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func schedule(
        prayerDays: [PrayerDay],
        settings: Settings,
        request: PrayerAPI.Request,
        now moment: Date,
        iqamaUpdateOrigin: Date?,
        prayerRequestHash: PrayerRequestHash,
        localized: NotificationServiceLocalizable,
        budget: Int,
        userNotification: LegacyNotificationRecorder
    ) async -> ScheduleOutcome {
        let timeZone = request.timeZone
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let dateInterval = DateInterval(start: moment, end: moment + .weeks(1, calendar))
        let iqamaUpdateIntervalIdentifier = "update-interval-iqama-reminder"
        let iqamaUpdateIntervalOriginAt = iqamaUpdateOrigin ?? moment

        let timeFormatStyle = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)
        var firstScheduledDate: Date?
        var lastScheduledDate = dateInterval.end
        var counter = budget // Unofficial limit for scheduling local notifications
        var pendingAdds: [(identifier: String, add: () async throws -> Void)] = []
        let now = dateInterval.start
        var siriShortcuts = [PrayerTime]()

        // Schedule available notifications
        Self.prayersToNotify(in: prayerDays, from: now, calendar: calendar).forEach { prefixIdentifier, prayerTime in
            guard counter > 0 else { return }

            let isObligation = prayerTime.type.isObligation
            let isJumuah = prayerTime.isJumuah(using: calendar)
            let iqamaTime = settings.iqamaTimes[prayerTime, using: calendar]
            let iqamaMinutes = isJumuah ? settings.iqamaReminders.jumuahMinutes : settings.iqamaReminders.minutes
            let iqamaSound = settings.iqamaReminders.sound
            let iqamaReminderDate = iqamaTime.map { $0 - .minutes(iqamaMinutes) }
            let hasIqamaReminder = iqamaReminderDate.map { iqamaSound != .off && iqamaMinutes > 0 && $0 > now } ?? false

            // Schedule local notification for each prayer
            let identifier = "\(prefixIdentifier)-\(prayerTime.type)"
            let sound = settings.notificationSounds[prayerTime.type] ?? .off
            var userInfo: [String: Any] = [:]

            // Encode prayer time for later retrieval
            do {
                let data = try prayerTime.encode()
                userInfo["prayer_time"] = data
            } catch {
            }

            // Add prayer notifications; the system silently drops calendar triggers already in the past,
            // so they must not consume the budget, and the Jumuah iqama reminder replaces the dhuhr prayer
            if sound != .off, counter > 0, prayerTime.dateInterval.start > now, !(isJumuah && hasIqamaReminder) {
                pendingAdds.append((identifier, {
                    try await userNotification.add(
                        date: prayerTime.dateInterval.start,
                        body: localized.prayerNotificationBody(
                            for: prayerTime,
                            at: prayerTime.dateInterval.start.formatted(timeFormatStyle),
                            using: calendar
                        ),
                        sound: settings.notificationSoundFile(for: prayerTime.type).map(Self.sound(named:)),
                        interruptionLevel: .timeSensitive,
                        identifier: identifier,
                        category: (isObligation ? NotificationCategory.main : .reminder).rawValue,
                        userInfo: userInfo
                    )
                }))

                // Update scheduled range and counter
                firstScheduledDate = firstScheduledDate ?? prayerTime.dateInterval.start
                lastScheduledDate = prayerTime.dateInterval.start
                counter -= 1
            } else if sound == .off {
                userNotification.remove(withIdentifier: identifier)
            }

            // Add iqama notification if applicable; it goes before the optional reminders so the Jumuah
            // replacement for dhuhr cannot lose the last budget slot to a pre-adhan reminder
            let iqamaIdentifier = "\(identifier)-iqama-reminder"

            if let iqamaReminderDate, hasIqamaReminder, counter > 0 {
                pendingAdds.append((iqamaIdentifier, {
                    try await userNotification.add(
                        date: iqamaReminderDate,
                        body: localized.iqamaNotificationBody(for: prayerTime, minutes: iqamaMinutes, isJumuah: isJumuah),
                        sound: iqamaSound.file.map(Self.sound(named:)),
                        interruptionLevel: .timeSensitive,
                        identifier: iqamaIdentifier,
                        category: NotificationCategory.reminder.rawValue,
                        userInfo: userInfo
                    )
                }))

                // Update counter
                counter -= 1
            } else if iqamaSound == .off {
                userNotification.remove(withIdentifier: iqamaIdentifier)
            }

            // Add Siri shortcut
            siriShortcuts.append(prayerTime)

            // Add reminder notifications
            let reminderIdentifier = "\(identifier)-reminder"
            let reminderSound = settings.reminderSounds[prayerTime.type] ?? .off
            let reminderMinutes = settings.preAdhanMinutes[prayerTime.type]

            let reminderDate = (isJumuah ? iqamaTime ?? prayerTime.dateInterval.start : prayerTime.dateInterval.start)
                - .minutes(reminderMinutes)

            // An alarm rings at the reminder's time, so the reminder still shows but stays silent
            let isSilenced = settings.ringsAlarm(for: prayerTime.type)

            if reminderSound != .off, reminderMinutes > 0, counter > 0, reminderDate > now {
                pendingAdds.append((reminderIdentifier, {
                    try await userNotification.add(
                        date: reminderDate,
                        body: localized.prayerNotificationReminder(for: prayerTime, minutes: reminderMinutes, using: calendar),
                        sound: isSilenced ? nil : reminderSound.file.map(Self.sound(named:)),
                        interruptionLevel: .timeSensitive,
                        identifier: reminderIdentifier,
                        category: NotificationCategory.reminder.rawValue,
                        userInfo: userInfo
                    )
                }))

                // Update counter
                counter -= 1
            } else if reminderSound == .off {
                userNotification.remove(withIdentifier: reminderIdentifier)
            }

            // Add imsak notifications if applicable
            if prayerTime.type == .fajr {
                let reminderIdentifier = "\(identifier)-imsak-reminder"
                let reminderMinutes = settings.preAdhanMinutes.imsak
                let reminderDate = prayerTime.dateInterval.start - .minutes(reminderMinutes)

                if reminderSound != .off, reminderMinutes > 0, counter > 0, reminderDate > now {
                    pendingAdds.append((reminderIdentifier, {
                        try await userNotification.add(
                            date: reminderDate,
                            body: localized.prayerNotificationReminder(for: prayerTime, minutes: reminderMinutes, using: calendar),
                            sound: reminderSound.file.map(Self.sound(named:)),
                            interruptionLevel: .timeSensitive,
                            identifier: reminderIdentifier,
                            category: NotificationCategory.reminder.rawValue,
                            userInfo: userInfo
                        )
                    }))

                    // Update counter
                    counter -= 1
                } else if reminderSound == .off {
                    userNotification.remove(withIdentifier: reminderIdentifier)
                }
            }

            // Add duha notifications if applicable
            if prayerTime.type == .sunrise {
                let reminderIdentifier = "\(identifier)-duha-reminder"
                let reminderTime = settings.duhaReminder?.date(from: prayerTime.dateInterval, using: calendar)

                if let reminderTime, reminderSound != .off, counter > 0, reminderTime > now {
                    pendingAdds.append((reminderIdentifier, {
                        try await userNotification.add(
                            date: reminderTime,
                            body: localized.duhaNotificationBody(at: reminderTime.formatted(timeFormatStyle)),
                            sound: reminderSound.file.map(Self.sound(named:)),
                            interruptionLevel: .timeSensitive,
                            identifier: reminderIdentifier,
                            category: NotificationCategory.reminder.rawValue,
                            userInfo: userInfo
                        )
                    }))

                    // Update counter
                    counter -= 1
                } else if reminderSound == .off {
                    userNotification.remove(withIdentifier: reminderIdentifier)
                }
            }
        }

        // Add iqama update interval if applicable
        var iqamaUpdateInterval: TimeInterval?
        switch (settings.iqamaReminders.updateInterval, settings.iqamaTimes.isEmpty) {
        case (.weekly, false):
            iqamaUpdateInterval = 7 * 24 * 3600
        case (.biweekly, false):
            iqamaUpdateInterval = 14 * 24 * 3600
        case (.monthly, false):
            iqamaUpdateInterval = 30 * 24 * 3600
        case (.bimonthly, false):
            iqamaUpdateInterval = 60 * 24 * 3600
        case (_, true), (.off, _):
            userNotification.remove(withIdentifier: iqamaUpdateIntervalIdentifier)
        }

        if let timeInterval = iqamaUpdateInterval {
            let date = -iqamaUpdateIntervalOriginAt.timeIntervalSince(now) < timeInterval ? iqamaUpdateIntervalOriginAt : now

            pendingAdds.append((iqamaUpdateIntervalIdentifier, {
                try await userNotification.add(
                    date: date.addingTimeInterval(timeInterval),
                    body: "Check masjid iqama times",
                    interruptionLevel: .passive,
                    identifier: iqamaUpdateIntervalIdentifier,
                    category: NotificationCategory.reminder.rawValue,
                    userInfo: ["origin_at": date.timeIntervalSince1970]
                )
            }))

            // Update counter
            counter -= 1
        }

        // Ensure more prayer notifications are schedueled beyond limit
        let calibrateDate = lastScheduledDate - .hours(12)
        var calibrateUserInfo: [String: Any] = [:]

        // Create hash to ensure duplicate requests only run when necessary
        do {
            let data = try prayerRequestHash.encode()
            calibrateUserInfo["prayer_request_hash"] = data
        } catch {
        }

        pendingAdds.append(("calibrate", {
            try await userNotification.add(
                date: calibrateDate,
                body: localized.calibrateNotificationBody,
                sound: .default,
                identifier: "calibrate",
                category: NotificationCategory.calibrate.rawValue,
                userInfo: calibrateUserInfo
            )
        }))

        #if os(iOS)
        if settings.followsLocation, settings.geofenceRadius > 0 {
            let region = CLCircularRegion(
                center: request.coordinates.location,
                radius: settings.geofenceRadius,
                identifier: "Home"
            ).apply {
                $0.notifyOnEntry = false
                $0.notifyOnExit = true
            }

            pendingAdds.append(("calibrate-beacon", {
                try await userNotification.add(
                    region: region,
                    body: localized.beaconNotificationBody,
                    title: localized.beaconNotificationTitle,
                    sound: .default,
                    identifier: "calibrate-beacon",
                    category: NotificationCategory.beacon.rawValue,
                    userInfo: ["coordinates": request.coordinates.description]
                )
            }))
        } else {
            await userNotification.remove(withCategory: NotificationCategory.beacon.rawValue)
        }
        #endif

        for pending in pendingAdds {
            try? await pending.add()
        }

        return ScheduleOutcome(
            entries: userNotification.entries,
            shortcutPrayers: siriShortcuts,
            firstScheduled: firstScheduledDate,
            lastScheduled: lastScheduledDate,
            requested: budget - counter
        )
    }
}

private extension LegacyNotificationSchedule {
    static func prayersToNotify(in prayerDays: [PrayerDay], from now: Date, calendar: Calendar) -> [(prefix: String, prayerTime: PrayerTime)] {
        NotificationServiceUN.prayersToNotify(in: prayerDays, from: now, calendar: calendar)
    }

    static func sound(named file: String) -> ScheduleEntry.Sound {
        .file(file)
    }
}

// MARK: - Recorder

/// Stands in for the notification center, with the calls the scheduler makes and their defaults.
final class LegacyNotificationRecorder {
    private(set) var entries = [ScheduleEntry]()

    func add(
        date: Date,
        body: String,
        title: String? = nil,
        sound: ScheduleEntry.Sound? = .default,
        interruptionLevel: UNNotificationInterruptionLevel? = nil,
        identifier: String,
        category: String,
        userInfo: [String: Any]
    ) async throws {
        entries.append(
            .add(
                ScheduleEntry.Notification(
                    identifier: identifier,
                    trigger: .date(date),
                    body: body,
                    title: title,
                    sound: sound,
                    interruptionLevel: interruptionLevel,
                    category: category,
                    userInfo: ScheduleEntry.values(of: userInfo)
                )
            )
        )
    }

    #if os(iOS)
    func add(
        region: CLRegion,
        body: String,
        title: String? = nil,
        sound: ScheduleEntry.Sound? = .default,
        interruptionLevel: UNNotificationInterruptionLevel? = nil,
        identifier: String,
        category: String,
        userInfo: [String: Any]
    ) async throws {
        entries.append(
            .add(
                ScheduleEntry.Notification(
                    identifier: identifier,
                    trigger: .region(ScheduleEntry.Region(region)),
                    body: body,
                    title: title,
                    sound: sound,
                    interruptionLevel: interruptionLevel,
                    category: category,
                    userInfo: ScheduleEntry.values(of: userInfo)
                )
            )
        )
    }
    #endif

    func remove(withIdentifier id: String) {
        entries.append(.removeIdentifier(id))
    }

    func remove(withCategory category: String) async {
        entries.append(.removeCategory(category))
    }
}

// MARK: - Entries

/// What a scheduling run did, in the order it did it, reduced to values two runs can be compared by.
struct ScheduleOutcome: Equatable {
    let entries: [ScheduleEntry]
    let shortcutPrayers: [PrayerTime]
    let firstScheduled: Date?
    let lastScheduled: Date
    let requested: Int
}

enum ScheduleEntry: Equatable {
    case add(Notification)
    case removeIdentifier(String)
    case removeCategory(String)
}

extension ScheduleEntry {
    struct Notification: Equatable {
        let identifier: String
        let trigger: Trigger
        let body: String
        let title: String?
        let sound: Sound?
        let interruptionLevel: UNNotificationInterruptionLevel?
        let category: String
        let userInfo: [String: Value]
    }

    enum Trigger: Equatable {
        case date(Date)
        #if os(iOS)
        case region(Region)
        #endif
    }

    enum Sound: Equatable {
        case `default`
        case file(String)
    }

    /// A `userInfo` value read back as what it holds, so two dictionaries compare by content.
    enum Value: Equatable {
        case prayerTime(PrayerTime)
        case requestHash(PrayerRequestHash)
        case number(Double)
        case text(String)
        case unreadable(String)
    }

    static func values(of userInfo: [String: Any]) -> [String: Value] {
        Dictionary(uniqueKeysWithValues: userInfo.map { key, value in (key, Self.value(of: value, for: key)) })
    }

    private static func value(of value: Any, for key: String) -> Value {
        switch (key, value) {
        case let ("prayer_time", data as Data):
            (try? data.decode() as PrayerTime).map(Value.prayerTime) ?? .unreadable("\(data)")
        case let ("prayer_request_hash", data as Data):
            (try? data.decode() as PrayerRequestHash).map(Value.requestHash) ?? .unreadable("\(data)")
        case let (_, number as Double):
            .number(number)
        case let (_, text as String):
            .text(text)
        default:
            .unreadable("\(value)")
        }
    }
}

#if os(iOS)
extension ScheduleEntry {
    struct Region: Equatable {
        let identifier: String
        let latitude: Double?
        let longitude: Double?
        let radius: Double?
        let notifyOnEntry: Bool
        let notifyOnExit: Bool

        init(_ region: CLRegion) {
            let circle = region as? CLCircularRegion

            identifier = region.identifier
            latitude = circle?.center.latitude
            longitude = circle?.center.longitude
            radius = circle?.radius
            notifyOnEntry = region.notifyOnEntry
            notifyOnExit = region.notifyOnExit
        }
    }
}
#endif
