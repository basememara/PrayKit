//
//  NotificationPlan.swift
//  PrayServices
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import CoreLocation
import Foundation
import PrayCore
import UserNotifications
import ZamzamCore

/// What one scheduling run asks of the notification center, decided from the prayer days, the settings and the
/// moment alone, so it can be built and compared without a notification center, a clock or a language.
struct NotificationPlan: Equatable, Sendable {
    /// In the order they are added.
    var requests: [Request]
    /// In the order they are removed, all of them before the first request is added.
    var removals: [Removal]
    var shortcutPrayers: [PrayerTime]
    var firstScheduled: Date?
    var lastScheduled: Date
    /// How much of the budget the run spent, which the iqama update can overdraw by one.
    var requested: Int
}

// MARK: - Types

extension NotificationPlan {
    static let iqamaUpdateIdentifier = "update-interval-iqama-reminder"

    struct Request: Equatable, Sendable {
        let identifier: String
        let trigger: Trigger
        let body: Body
        let sound: Sound?
        let interruptionLevel: UNNotificationInterruptionLevel?
        let category: NotificationCategory
        let payload: Payload
    }

    enum Trigger: Equatable, Sendable {
        case date(Date)
        #if os(iOS)
        case region(center: Coordinates, radius: Double)
        #endif
    }

    /// The wording a request shows, named rather than written out, since the words belong to the app's language.
    enum Body: Equatable, Sendable {
        case prayer(PrayerTime)
        case iqama(PrayerTime, minutes: Int, isJumuah: Bool)
        case reminder(PrayerTime, minutes: Int)
        case duha(at: Date)
        case iqamaUpdate
        case calibrate
        case beacon
    }

    /// The sound a request plays; a request without one is silent.
    enum Sound: Equatable, Sendable {
        case `default`
        case file(String)
    }

    /// What a request carries in its `userInfo`.
    enum Payload: Equatable, Sendable {
        case prayerTime(PrayerTime)
        case iqamaUpdateOrigin(Date)
        case requestHash(PrayerRequestHash)
        case coordinates(Coordinates)
    }

    enum Removal: Equatable, Sendable {
        case identifier(String)
        case category(NotificationCategory)
    }
}

// MARK: - Decision

extension NotificationPlan {
    static func make(
        days: [PrayerDay],
        settings: Settings,
        request: PrayerAPI.Request,
        requestHash: PrayerRequestHash,
        now: Date,
        iqamaUpdateOrigin: Date?,
        budget: Int = 58 // Unofficial limit for scheduling local notifications
    ) -> NotificationPlan {
        let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone)
        var draft = Draft(settings: settings, calendar: calendar, now: now, lastScheduled: now + .weeks(1, calendar), counter: budget)

        NotificationServiceUN.prayersToNotify(in: days, from: now, calendar: calendar).forEach { prefixIdentifier, prayerTime in
            draft.schedule(prayerTime, prefixIdentifier: prefixIdentifier)
        }

        draft.scheduleIqamaUpdate(from: iqamaUpdateOrigin ?? now)
        draft.scheduleCalibrate(with: requestHash)
        #if os(iOS)
        draft.scheduleBeacon(at: request.coordinates)
        #endif

        return NotificationPlan(
            requests: draft.requests,
            removals: draft.removals,
            shortcutPrayers: draft.shortcutPrayers,
            firstScheduled: draft.firstScheduled,
            lastScheduled: draft.lastScheduled,
            requested: budget - draft.counter
        )
    }
}

/// A plan while it is being decided, with what is left of the budget.
private struct Draft {
    let settings: Settings
    let calendar: Calendar
    let now: Date
    var requests = [NotificationPlan.Request]()
    var removals = [NotificationPlan.Removal]()
    var shortcutPrayers = [PrayerTime]()
    var firstScheduled: Date?
    var lastScheduled: Date
    var counter: Int
}

private extension Draft {
    mutating func schedule(_ prayerTime: PrayerTime, prefixIdentifier: String) {
        guard counter > 0 else { return }

        let isObligation = prayerTime.type.isObligation
        let isJumuah = prayerTime.isJumuah(using: calendar)
        let iqamaTime = settings.iqamaTimes[prayerTime, using: calendar]
        let iqamaMinutes = isJumuah ? settings.iqamaReminders.jumuahMinutes : settings.iqamaReminders.minutes
        let iqamaSound = settings.iqamaReminders.sound
        let iqamaReminderDate = iqamaTime.map { $0 - .minutes(iqamaMinutes) }
        let hasIqamaReminder = iqamaReminderDate.map { iqamaSound != .off && iqamaMinutes > 0 && $0 > now } ?? false

        let identifier = "\(prefixIdentifier)-\(prayerTime.type)"
        let sound = settings.notificationSounds[prayerTime.type] ?? .off

        // Add prayer notifications; the system silently drops calendar triggers already in the past,
        // so they must not consume the budget, and the Jumuah iqama reminder replaces the dhuhr prayer
        if sound != .off, counter > 0, prayerTime.dateInterval.start > now, !(isJumuah && hasIqamaReminder) {
            requests.append(
                NotificationPlan.Request(
                    identifier: identifier,
                    trigger: .date(prayerTime.dateInterval.start),
                    body: .prayer(prayerTime),
                    sound: settings.notificationSoundFile(for: prayerTime.type).map(NotificationPlan.Sound.file),
                    interruptionLevel: .timeSensitive,
                    category: isObligation ? .main : .reminder,
                    payload: .prayerTime(prayerTime)
                )
            )

            firstScheduled = firstScheduled ?? prayerTime.dateInterval.start
            lastScheduled = prayerTime.dateInterval.start
            counter -= 1
        } else if sound == .off {
            removals.append(.identifier(identifier))
        }

        // Add iqama notification if applicable; it goes before the optional reminders so the Jumuah
        // replacement for dhuhr cannot lose the last budget slot to a pre-adhan reminder
        let iqamaIdentifier = "\(identifier)-iqama-reminder"

        if let iqamaReminderDate, hasIqamaReminder, counter > 0 {
            requests.append(
                NotificationPlan.Request(
                    identifier: iqamaIdentifier,
                    trigger: .date(iqamaReminderDate),
                    body: .iqama(prayerTime, minutes: iqamaMinutes, isJumuah: isJumuah),
                    sound: iqamaSound.file.map(NotificationPlan.Sound.file),
                    interruptionLevel: .timeSensitive,
                    category: .reminder,
                    payload: .prayerTime(prayerTime)
                )
            )

            counter -= 1
        } else if iqamaSound == .off {
            removals.append(.identifier(iqamaIdentifier))
        }

        shortcutPrayers.append(prayerTime)
        scheduleReminders(for: prayerTime, identifier: identifier, isJumuah: isJumuah, iqamaTime: iqamaTime)
    }

    mutating func scheduleReminders(for prayerTime: PrayerTime, identifier: String, isJumuah: Bool, iqamaTime: Date?) {
        let reminderIdentifier = "\(identifier)-reminder"
        let reminderSound = settings.reminderSounds[prayerTime.type] ?? .off
        let reminderMinutes = settings.preAdhanMinutes[prayerTime.type]

        let reminderDate = (isJumuah ? iqamaTime ?? prayerTime.dateInterval.start : prayerTime.dateInterval.start)
            - .minutes(reminderMinutes)

        // An alarm rings at the reminder's time, so the reminder still shows but stays silent
        let isSilenced = settings.ringsAlarm(for: prayerTime.type)

        if reminderSound != .off, reminderMinutes > 0, counter > 0, reminderDate > now {
            requests.append(
                NotificationPlan.Request(
                    identifier: reminderIdentifier,
                    trigger: .date(reminderDate),
                    body: .reminder(prayerTime, minutes: reminderMinutes),
                    sound: isSilenced ? nil : reminderSound.file.map(NotificationPlan.Sound.file),
                    interruptionLevel: .timeSensitive,
                    category: .reminder,
                    payload: .prayerTime(prayerTime)
                )
            )

            counter -= 1
        } else if reminderSound == .off {
            removals.append(.identifier(reminderIdentifier))
        }

        if prayerTime.type == .fajr {
            let reminderIdentifier = "\(identifier)-imsak-reminder"
            let reminderMinutes = settings.preAdhanMinutes.imsak
            let reminderDate = prayerTime.dateInterval.start - .minutes(reminderMinutes)

            if reminderSound != .off, reminderMinutes > 0, counter > 0, reminderDate > now {
                requests.append(
                    NotificationPlan.Request(
                        identifier: reminderIdentifier,
                        trigger: .date(reminderDate),
                        body: .reminder(prayerTime, minutes: reminderMinutes),
                        sound: reminderSound.file.map(NotificationPlan.Sound.file),
                        interruptionLevel: .timeSensitive,
                        category: .reminder,
                        payload: .prayerTime(prayerTime)
                    )
                )

                counter -= 1
            } else if reminderSound == .off {
                removals.append(.identifier(reminderIdentifier))
            }
        }

        if prayerTime.type == .sunrise {
            let reminderIdentifier = "\(identifier)-duha-reminder"
            let reminderTime = settings.duhaReminder?.date(from: prayerTime.dateInterval, using: calendar)

            if let reminderTime, reminderSound != .off, counter > 0, reminderTime > now {
                requests.append(
                    NotificationPlan.Request(
                        identifier: reminderIdentifier,
                        trigger: .date(reminderTime),
                        body: .duha(at: reminderTime),
                        sound: reminderSound.file.map(NotificationPlan.Sound.file),
                        interruptionLevel: .timeSensitive,
                        category: .reminder,
                        payload: .prayerTime(prayerTime)
                    )
                )

                counter -= 1
            } else if reminderSound == .off {
                removals.append(.identifier(reminderIdentifier))
            }
        }
    }

    mutating func scheduleIqamaUpdate(from origin: Date) {
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
            removals.append(.identifier(NotificationPlan.iqamaUpdateIdentifier))
        }

        if let timeInterval = iqamaUpdateInterval {
            let date = -origin.timeIntervalSince(now) < timeInterval ? origin : now

            requests.append(
                NotificationPlan.Request(
                    identifier: NotificationPlan.iqamaUpdateIdentifier,
                    trigger: .date(date.addingTimeInterval(timeInterval)),
                    body: .iqamaUpdate,
                    sound: .default,
                    interruptionLevel: .passive,
                    category: .reminder,
                    payload: .iqamaUpdateOrigin(date)
                )
            )

            counter -= 1
        }
    }

    mutating func scheduleCalibrate(with requestHash: PrayerRequestHash) {
        // Ensure more prayer notifications are schedueled beyond limit
        requests.append(
            NotificationPlan.Request(
                identifier: "calibrate",
                trigger: .date(lastScheduled - .hours(12)),
                body: .calibrate,
                sound: .default,
                interruptionLevel: nil,
                category: .calibrate,
                payload: .requestHash(requestHash)
            )
        )
    }

    #if os(iOS)
    mutating func scheduleBeacon(at coordinates: Coordinates) {
        if settings.followsLocation, settings.geofenceRadius > 0 {
            requests.append(
                NotificationPlan.Request(
                    identifier: "calibrate-beacon",
                    trigger: .region(center: coordinates, radius: settings.geofenceRadius),
                    body: .beacon,
                    sound: .default,
                    interruptionLevel: nil,
                    category: .beacon,
                    payload: .coordinates(coordinates)
                )
            )
        } else {
            removals.append(.category(.beacon))
        }
    }
    #endif
}

// MARK: - Rendering

extension NotificationPlan.Body {
    /// The words the notification shows, in the app's language and on the place's clock.
    func text(localized: NotificationServiceLocalizable, timeFormatStyle: Date.FormatStyle, calendar: Calendar) -> String {
        switch self {
        case let .prayer(prayerTime):
            localized.prayerNotificationBody(
                for: prayerTime,
                at: prayerTime.dateInterval.start.formatted(timeFormatStyle),
                using: calendar
            )
        case let .iqama(prayerTime, minutes, isJumuah):
            localized.iqamaNotificationBody(for: prayerTime, minutes: minutes, isJumuah: isJumuah)
        case let .reminder(prayerTime, minutes):
            localized.prayerNotificationReminder(for: prayerTime, minutes: minutes, using: calendar)
        case let .duha(reminderTime):
            localized.duhaNotificationBody(at: reminderTime.formatted(timeFormatStyle))
        case .iqamaUpdate:
            "Check masjid iqama times"
        case .calibrate:
            localized.calibrateNotificationBody
        case .beacon:
            localized.beaconNotificationBody
        }
    }

    func title(localized: NotificationServiceLocalizable) -> String? {
        self == .beacon ? localized.beaconNotificationTitle : nil
    }
}

extension NotificationPlan.Payload {
    func userInfo() throws -> [String: Any] {
        switch self {
        case let .prayerTime(prayerTime):
            // Encode prayer time for later retrieval
            ["prayer_time": try prayerTime.encode()]
        case let .iqamaUpdateOrigin(date):
            ["origin_at": date.timeIntervalSince1970]
        case let .requestHash(requestHash):
            // Create hash to ensure duplicate requests only run when necessary
            ["prayer_request_hash": try requestHash.encode()]
        case let .coordinates(coordinates):
            ["coordinates": coordinates.description]
        }
    }
}

#if os(iOS)
extension NotificationPlan.Trigger {
    static func homeRegion(center: Coordinates, radius: Double) -> CLCircularRegion {
        CLCircularRegion(
            center: center.location,
            radius: radius,
            identifier: "Home"
        ).apply {
            $0.notifyOnEntry = false
            $0.notifyOnExit = true
        }
    }
}
#endif
