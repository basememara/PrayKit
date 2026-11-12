//
//  NotificationServiceUN.swift
//  PrayServices
//
//  Created by Basem Emara on 2021-06-06.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import CoreLocation
import Foundation
import Intents
import PrayCore
import UserNotifications
import ZamzamCore
import ZamzamNotification
#if os(iOS)
import BackgroundTasks
import CoreSpotlight
#endif

/// `UNUserNotificationCenter` is documented as thread-safe, hence the unchecked conformance.
public struct NotificationServiceUN: NotificationService, @unchecked Sendable {
    private let prayerManager: PrayerManager
    private let userNotification: UNUserNotificationCenter
    private let storage: SettingsStorage
    private let constants: Constants
    private let localized: NotificationServiceLocalizable
    private let log: LogManager
    private let flight = SingleFlight()

    public init(
        prayerManager: PrayerManager,
        userNotification: UNUserNotificationCenter,
        storage: SettingsStorage,
        constants: Constants,
        localized: NotificationServiceLocalizable,
        log: LogManager
    ) {
        self.prayerManager = prayerManager
        self.userNotification = userNotification
        self.storage = storage
        self.constants = constants
        self.localized = localized
        self.log = log
    }
}

public extension NotificationServiceUN {
    /// Schedules local notifications for prayers, one run at a time: a call during a run waits for it and
    /// one more run, so the last call always schedules from the latest settings. With every prayer sound off, a run
    /// clears the pending prayer notifications instead.
    func schedulePrayers(silencingAdhans: Bool) async {
        await flight.run { await scheduleOnce(silencingAdhans: silencingAdhans) }
    }
}

extension NotificationServiceUN {
    /// The prayers with something left to notify from now, each named by its prayer day rather than its start, so an
    /// Isha after midnight can't share an identifier with the next day's. A prayer that has ended has nothing left,
    /// its reminders all being earlier.
    static func prayersToNotify(in prayerDays: [PrayerDay], from now: Date, calendar: Calendar) -> [(prefix: String, prayerTime: PrayerTime)] {
        prayerDays.flatMap { prayerDay in
            let prefix = prayerDay.date.shortString(calendar: calendar)
            return prayerDay.times.filter { $0.dateInterval.end > now }.map { (prefix, $0) }
        }
    }
}

private extension NotificationServiceUN {
    func scheduleOnce(silencingAdhans: Bool) async {
        let state = storage.load()

        // First, since clearing needs no place and must not wait on the request hash
        if let categories = NotificationPlan.clearedCategories(for: state.document.settings) {
            log.debug("Prayer sounds disabled, clearing notifications")
            await userNotification.removePending(withCategories: categories.map(\.rawValue))
            return
        }

        let settings = silencingAdhans ? state.document.settings.silencingAdhans() : state.document.settings

        guard let request = PrayerAPI.Request(settings: settings, place: state.place) else {
            log.error("Could not schedule prayer notifications without a place")
            return
        }

        let timeZone = request.timeZone
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)

        // Read once, so the week, the request hash and every comparison in the plan share one moment
        let now = Date.now
        let dateInterval = DateInterval(start: now, end: now + .weeks(1, calendar))
        let prayerRequestHash = PrayerRequestHash(request: request, dateInterval: dateInterval, settings: settings)
        let iqamaUpdateOrigin = (await userNotification.get(withIdentifier: NotificationPlan.iqamaUpdateIdentifier)?
            .content.userInfo["origin_at"] as? TimeInterval)
            .map { Date(timeIntervalSince1970: $0) }

        guard await userNotification.get(withIdentifier: "calibrate")?.hasChanged(from: prayerRequestHash) ?? true else {
            log.info("Request is unchanged from last execution, exit schedule prayers")
            return
        }

        log.info("Begin scheduling prayer notifications from \(dateInterval.start.formatted())")
        let prayerDays: [PrayerDay]

        do {
            // From the prayer day holding now, whose Isha may still be to come after midnight
            prayerDays = try await prayerManager.fetch(spanning: dateInterval, with: request)
        } catch {
            log.error("Could not fetch prayers for scheduling notifications", error: error)
            return
        }

        guard !prayerDays.isEmpty else {
            log.error("Fetched prayers are empty!")
            return
        }

        log.info("Fetched \(prayerDays.count) days of prayers, begin scheduling notifications")

        let plan = NotificationPlan.make(
            days: prayerDays,
            settings: settings,
            request: request,
            requestHash: prayerRequestHash,
            now: now,
            iqamaUpdateOrigin: iqamaUpdateOrigin
        )

        let timeFormatter = DateFormatter.prayerTime(is24Hour: settings.enable24hTimeFormat, using: timeZone)
        await apply(plan, timeFormatter: timeFormatter, calendar: calendar, regionName: state.place?.regionName)
    }

    func apply(_ plan: NotificationPlan, timeFormatter: DateFormatter, calendar: Calendar, regionName: String?) async {
        for removal in plan.removals {
            switch removal {
            case let .identifier(identifier):
                userNotification.remove(withIdentifier: identifier)
            case let .category(category):
                await userNotification.remove(withCategory: category.rawValue)
            }
        }

        // Replace the schedule without ever emptying it, so a suspension mid-run leaves the previous
        // notifications in place: drop only what this run will not re-add, then add, which replaces an
        // existing identifier in place
        let managedCategories = [
            NotificationCategory.main.rawValue,
            NotificationCategory.reminder.rawValue,
            NotificationCategory.calibrate.rawValue,
            NotificationCategory.beacon.rawValue
        ]
        let scheduledIdentifiers = Set(plan.requests.map(\.identifier))
        let staleIdentifiers = await userNotification.pendingNotificationRequests()
            .filter { managedCategories.contains($0.content.categoryIdentifier) && !scheduledIdentifiers.contains($0.identifier) }
            .map(\.identifier)

        // The removal has no completion, so wait for it to land: adding first could exceed the 64-request cap
        userNotification.remove(withIdentifiers: staleIdentifiers)
        _ = await userNotification.pendingNotificationRequests()

        for request in plan.requests {
            do {
                try await add(request, timeFormatter: timeFormatter, calendar: calendar)
            } catch {
                log.error("Failed to create a notifications for \"\(request.identifier)\"", error: error)
            }
        }

        log.debug("Replaced pending notifications, removed \(staleIdentifiers.count) no longer scheduled")

        let pendingCount = await userNotification.pendingNotificationRequests().count
        let scheduledRange = "\(plan.firstScheduled?.formatted() ?? "none") to \(plan.lastScheduled.formatted())"
        log.info("Requested \(plan.requested) notifications for prayers from \(scheduledRange), \(pendingCount) pending in the notification center")
        scheduleBackgroundRefreshTask(at: plan.lastScheduled - .days(2, calendar))

        #if !os(macOS)
        let siriShortcuts = plan.shortcutPrayers.map { prayerTime in
            INRelevantShortcut(
                for: prayerTime,
                timeFormatter: timeFormatter,
                calendar: calendar,
                region: regionName,
                localized: localized,
                userInfo: userInfo(for: .prayerTime(prayerTime))
            )
        }

        // Awaited here rather than donated from a `Task`, which would have sent
        // the non-Sendable shortcuts across an isolation boundary.
        do {
            try await INRelevantShortcutStore.default.setRelevantShortcuts(siriShortcuts)
            log.debug("Donated \(siriShortcuts.count) Siri shortcuts successfully")
        } catch {
            log.error("Siri shortcuts could not be stored", error: error)
        }
        #endif
    }

    func add(_ request: NotificationPlan.Request, timeFormatter: DateFormatter, calendar: Calendar) async throws {
        let body = request.body.text(localized: localized, timeFormatter: timeFormatter, calendar: calendar)
        let title = request.body.title(localized: localized)
        let sound = request.sound.map(Self.sound(for:))
        let category = request.category.rawValue

        switch request.trigger {
        case let .date(date):
            try await userNotification.add(
                date: date,
                body: body,
                title: title,
                sound: sound,
                interruptionLevel: request.interruptionLevel,
                identifier: request.identifier,
                category: category,
                userInfo: userInfo(for: request.payload)
            )
        #if os(iOS)
        case let .region(center, radius):
            try await userNotification.add(
                region: NotificationPlan.Trigger.homeRegion(center: center, radius: radius),
                body: body,
                title: title,
                sound: sound,
                interruptionLevel: request.interruptionLevel,
                identifier: request.identifier,
                category: category,
                userInfo: userInfo(for: request.payload)
            )
        #endif
        }
    }

    func userInfo(for payload: NotificationPlan.Payload) -> [String: Any] {
        do {
            return try payload.userInfo()
        } catch {
            let subject = if case .requestHash = payload { "prayer request hash for notifications" } else { "prayer time for notification" }
            log.error("Failed to encode \(subject)", error: error)
            return [:]
        }
    }
}

public extension NotificationServiceUN {
    var hasSnooze: Bool {
        get async {
            await userNotification.exists(
                withCategory: NotificationCategory.snooze.rawValue,
                pendingOnly: true
            )
        }
    }

    func addSnooze(for prayerTime: PrayerTime, in timeInterval: TimeInterval?) async -> Date {
        let state = storage.load()
        let timeInterval = timeInterval ?? TimeInterval(state.document.settings.snoozeMinutes * 60)
        let date = Date(timeIntervalSinceNow: timeInterval)
        let calendar = state.placeCalendar
        let identifier = "\(date.shortString(calendar: calendar))-\(prayerTime.type)-snooze"
        let sound = state.document.settings.reminderSounds[prayerTime.type] ?? .off

        do {
            try await userNotification.add(
                timeInterval: timeInterval,
                body: localized.prayerNotificationReminder(for: prayerTime, using: calendar),
                sound: sound.file.map(Self.sound(named:)),
                interruptionLevel: .timeSensitive,
                identifier: identifier,
                category: NotificationCategory.snooze.rawValue,
                userInfo: [
                    "prayer_time": (try? prayerTime.encode()) ?? Data(),
                    // Next trigger date not as expected
                    // https://stackoverflow.com/q/40411812
                    "trigger_timestamp": date.timeIntervalSince1970
                ]
            )
            log.info("Added notification reminder")
        } catch {
            log.error("Failed to create a notifications for \"\(identifier)\"", error: error)
        }

        return date
    }

    func removeSnooze() async {
        await userNotification.remove(withCategory: NotificationCategory.snooze.rawValue)
    }
}

// MARK: - Helpers

private extension NotificationServiceUN {
    /// A sound file the app keeps in its bundle or its sounds folder, by name; the watch plays the default sound.
    static func sound(named file: String) -> UNNotificationSound {
        #if os(watchOS)
        .default
        #else
        UNNotificationSound(named: UNNotificationSoundName(file))
        #endif
    }

    static func sound(for sound: NotificationPlan.Sound) -> UNNotificationSound {
        switch sound {
        case .default:
            .default
        case let .file(file):
            Self.sound(named: file)
        }
    }
}

private extension NotificationServiceUN {
    func scheduleBackgroundRefreshTask(at date: Date) {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: constants.bgRefreshTaskID)
        request.earliestBeginDate = date

        do {
            try BGTaskScheduler.shared.submit(request)
            log.info("Scheduled background refresh for '\(constants.bgRefreshTaskID)'")
        } catch {
            log.error("Could not schedule background refresh for '\(constants.bgRefreshTaskID)'", error: error)
        }
        #endif
    }
}

private extension UNNotificationRequest {
    func hasChanged(from prayerRequestHash: PrayerRequestHash) -> Bool {
        do {
            guard let data = content.userInfo["prayer_request_hash"] as? Data else { return true }
            return try prayerRequestHash != data.decode()
        } catch {
            return true
        }
    }
}

public extension PrayerTime {
    init?(from notificationContent: UNNotificationContent) {
        guard let object: PrayerTime = try? (notificationContent.userInfo["prayer_time"] as? Data)?.decode() else {
            return nil
        }

        self = object
    }
}

#if !os(macOS)
private extension INRelevantShortcut {
    convenience init(
        for prayerTime: PrayerTime,
        timeFormatter: DateFormatter,
        calendar: Calendar,
        region: String?,
        localized: NotificationServiceLocalizable,
        userInfo: [AnyHashable: Any]
    ) {
        let title = localized.prayerNotificationBody(for: prayerTime, at: timeFormatter.string(from: prayerTime.dateInterval.start), using: calendar)
        let subtitle = region

        let userActivity = NSUserActivity(activityType: "io.zamzam.Pray-Watch.prayer-time")
        userActivity.title = title
        userActivity.isEligibleForPrediction = true
        userActivity.isEligibleForSearch = true
        userActivity.userInfo = userInfo

        #if os(iOS)
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.item.identifier)
        attributes.contentDescription = subtitle
        userActivity.contentAttributeSet = attributes
        #endif

        let cardTemplate = INDefaultCardTemplate(title: title)
        cardTemplate.subtitle = subtitle

        self.init(shortcut: INShortcut(userActivity: userActivity))
        self.shortcutRole = .information
        self.widgetKind = "WidgetView"
        self.watchTemplate = cardTemplate

        let dateProvider = INDateRelevanceProvider(start: prayerTime.dateInterval.start, end: prayerTime.dateInterval.end)
        self.relevanceProviders = [dateProvider]
    }
}
#endif

// MARK: - Localization

public protocol NotificationServiceLocalizable: Sendable {
    var beaconNotificationBody: String { get }
    var beaconNotificationTitle: String { get }
    var calibrateNotificationBody: String { get }
    var iqamaUpdateNotificationBody: String { get }

    /// Names the prayer on its own date in `calendar`, the place's, so a Friday Dhuhr is Jumuah wherever the device is.
    func prayerNotificationBody(for prayerTime: PrayerTime, at time: String, using calendar: Calendar) -> String
    func prayerNotificationReminder(for prayerTime: PrayerTime, using calendar: Calendar) -> String
    func prayerNotificationReminder(for prayerTime: PrayerTime, minutes: Int, using calendar: Calendar) -> String
    func iqamaNotificationBody(for prayerTime: PrayerTime, minutes: Int, isJumuah: Bool) -> String
    func duhaNotificationBody(at time: String) -> String
}
