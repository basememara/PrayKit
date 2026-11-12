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
    /// The categories a run clears in place of a plan, when every prayer sound is off; `nil` when it plans.
    static func clearedCategories(for settings: Settings) -> [NotificationCategory]? {
        settings.isPrayerSoundsDisabled ? [.main, .reminder, .calibrate] : nil
    }

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

        draft.endRangeWhereTheBudgetStopped()
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
    var lastRequested: Date?
    var counter: Int
}

private extension Draft {
    mutating func schedule(_ prayerTime: PrayerTime, prefixIdentifier: String) {
        guard counter > 0 else { return }

        let prayer = prayerTime.type
        let start = prayerTime.dateInterval.start
        let isJumuah = prayerTime.isJumuah(using: calendar)
        let identifier = "\(prefixIdentifier)-\(prayer)"
        let sound = settings.notificationSounds[prayer] ?? .off

        let iqamaIdentifier = "\(identifier)-iqama-reminder"
        let iqamaTime = settings.iqamaTimes[prayerTime, using: calendar]
        let iqamaMinutes = isJumuah ? settings.iqamaReminders.jumuahMinutes : settings.iqamaReminders.minutes
        let iqamaSound = settings.iqamaReminders.sound
        let iqamaDate = iqamaTime.flatMap { fireDate(iqamaMinutes, before: $0) }
        let hasIqamaReminder = iqamaSound != .off && iqamaDate.map { $0 > now } ?? false

        // The Jumuah iqama reminder replaces the dhuhr prayer
        if let date = slot(for: identifier, at: isJumuah && hasIqamaReminder ? nil : start, isOff: sound == .off) {
            let file = settings.notificationSoundFile(for: prayer)
            add(identifier, at: date, .prayer(prayerTime), sound: file, category: prayer.isObligation ? .main : .reminder, for: prayerTime)
            firstScheduled = firstScheduled ?? date
            lastScheduled = date
        }

        // The iqama reminder goes before the optional reminders so the Jumuah replacement for dhuhr
        // cannot lose the last budget slot to a pre-adhan reminder
        if let date = slot(for: iqamaIdentifier, at: iqamaDate, isOff: iqamaSound == .off) {
            add(iqamaIdentifier, at: date, .iqama(prayerTime, minutes: iqamaMinutes, isJumuah: isJumuah), sound: iqamaSound.file, for: prayerTime)
        }

        shortcutPrayers.append(prayerTime)

        let reminderIdentifier = "\(identifier)-reminder"
        let reminderSound = settings.reminderSounds[prayer] ?? .off
        let reminderMinutes = settings.preAdhanMinutes[prayer]
        let reminderDate = fireDate(reminderMinutes, before: isJumuah ? iqamaTime ?? start : start)

        // An alarm rings at the reminder's time, so the reminder still shows but stays silent
        let isSilenced = settings.ringsAlarm(for: prayer)

        if let date = slot(for: reminderIdentifier, at: reminderDate, isOff: reminderSound == .off) {
            add(reminderIdentifier, at: date, .reminder(prayerTime, minutes: reminderMinutes), sound: isSilenced ? nil : reminderSound.file, for: prayerTime)
        }

        if prayer == .fajr {
            let imsakIdentifier = "\(identifier)-imsak-reminder"
            let imsakMinutes = settings.preAdhanMinutes.imsak

            if let date = slot(for: imsakIdentifier, at: fireDate(imsakMinutes, before: start), isOff: reminderSound == .off) {
                add(imsakIdentifier, at: date, .reminder(prayerTime, minutes: imsakMinutes), sound: reminderSound.file, for: prayerTime)
            }
        }

        if prayer == .sunrise {
            let duhaIdentifier = "\(identifier)-duha-reminder"
            let duhaDate = settings.duhaReminder?.date(from: prayerTime.dateInterval, using: calendar)

            if let date = slot(for: duhaIdentifier, at: duhaDate, isOff: reminderSound == .off) {
                add(duhaIdentifier, at: date, .duha(at: date), sound: reminderSound.file, for: prayerTime)
            }
        }
    }

    /// A notification that is on and still to come takes a slot from the budget and gets its date back;
    /// one that is off is removed, even with no date to fire at.
    mutating func slot(for identifier: String, at date: Date?, isOff: Bool) -> Date? {
        // The system silently drops calendar triggers already in the past, so they must not consume the budget
        guard let date, !isOff, counter > 0, date > now else {
            if isOff {
                removals.append(.identifier(identifier))
            }

            return nil
        }

        counter -= 1
        return date
    }

    mutating func add(
        _ identifier: String,
        at date: Date,
        _ body: NotificationPlan.Body,
        sound: String?,
        category: NotificationCategory = .reminder,
        for prayerTime: PrayerTime
    ) {
        lastRequested = max(lastRequested ?? date, date)

        requests.append(
            NotificationPlan.Request(
                identifier: identifier,
                trigger: .date(date),
                body: body,
                sound: sound.map(NotificationPlan.Sound.file),
                interruptionLevel: .timeSensitive,
                category: category,
                payload: .prayerTime(prayerTime)
            )
        )
    }

    func fireDate(_ minutes: Int, before date: Date) -> Date? {
        minutes > 0 ? date - .minutes(minutes) : nil
    }

    /// The last adhan marks where the range ends. With every adhan off and the budget spent, nothing does, so
    /// the range ends at the last request made, and calibrate and the background refresh come before they run out.
    mutating func endRangeWhereTheBudgetStopped() {
        guard firstScheduled == nil, counter <= 0, let lastRequested else { return }
        lastScheduled = lastRequested
    }

    mutating func scheduleIqamaUpdate(from origin: Date) {
        guard !settings.iqamaTimes.isEmpty, let timeInterval = settings.iqamaReminders.updateInterval.timeInterval else {
            removals.append(.identifier(NotificationPlan.iqamaUpdateIdentifier))
            return
        }

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

private extension IqamaReminders.UpdateInterval {
    var timeInterval: TimeInterval? {
        switch self {
        case .weekly:
            7 * 24 * 3600
        case .biweekly:
            14 * 24 * 3600
        case .monthly:
            30 * 24 * 3600
        case .bimonthly:
            60 * 24 * 3600
        case .off:
            nil
        }
    }
}

// MARK: - Rendering

extension NotificationPlan.Body {
    /// The words the notification shows, in the app's language, with times written by `timeFormatter` on the place's clock.
    func text(localized: NotificationServiceLocalizable, timeFormatter: DateFormatter, calendar: Calendar) -> String {
        switch self {
        case let .prayer(prayerTime):
            localized.prayerNotificationBody(
                for: prayerTime,
                at: timeFormatter.string(from: prayerTime.dateInterval.start),
                using: calendar
            )
        case let .iqama(prayerTime, minutes, isJumuah):
            localized.iqamaNotificationBody(for: prayerTime, minutes: minutes, isJumuah: isJumuah)
        case let .reminder(prayerTime, minutes):
            localized.prayerNotificationReminder(for: prayerTime, minutes: minutes, using: calendar)
        case let .duha(reminderTime):
            localized.duhaNotificationBody(at: timeFormatter.string(from: reminderTime))
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
