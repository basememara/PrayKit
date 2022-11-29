//
//  NotificationServiceUN.swift
//  PrayServices
//
//  Created by Basem Emara on 2021-06-06.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Combine
import CoreLocation
import Foundation
import Intents
import PrayCore
import UserNotifications
import ZamzamCore
import ZamzamNotification
#if os(iOS)
import CoreSpotlight
import BackgroundTasks
#endif

public struct NotificationServiceUN: NotificationService {
    private let prayerManager: PrayerManager
    private let userNotification: UNUserNotificationCenter
    private let preferences: Preferences
    private let constants: Constants
    private let localized: NotificationServiceLocalizable
    private let log: LogManager

    public init(
        prayerManager: PrayerManager,
        userNotification: UNUserNotificationCenter,
        preferences: Preferences,
        constants: Constants,
        localized: NotificationServiceLocalizable,
        log: LogManager
    ) {
        self.prayerManager = prayerManager
        self.userNotification = userNotification
        self.preferences = preferences
        self.constants = constants
        self.localized = localized
        self.log = log
    }
}

public extension NotificationServiceUN {
    /// Schedules local notifications for prayers
    func schedulePrayers() async {
        // swiftlint:disable:previous function_body_length cyclomatic_complexity
        guard let request = PrayerAPI.Request(from: preferences) else {
            log.error("Could not schedule prayer notifications due to missing settings")
            return
        }

        let dateInterval = DateInterval(start: .now, end: .now + .weeks(1))
        let prayerRequestHash = PrayerRequestHash(request: request, dateInterval: dateInterval, preferences: preferences)
        let iqamaUpdateIntervalIdentifier = "update-interval-iqama-reminder"
        let iqamaUpdateIntervalOriginAt = (await userNotification.get(withIdentifier: iqamaUpdateIntervalIdentifier)?
            .content.userInfo["origin_at"] as? TimeInterval)
            .map { Date(timeIntervalSince1970: $0) } ?? .now

        guard await userNotification.get(withIdentifier: "calibrate")?.hasChanged(from: prayerRequestHash) ?? true else {
            log.info("Request is unchanged from last execution, exit schedule prayers")
            return
        }

        log.info("Begin scheduling prayer notifications from \(dateInterval.start.formatted())")
        let prayerDays: [PrayerDay]

        do {
            prayerDays = try await prayerManager.fetch(between: dateInterval, with: request)
        } catch {
            log.error("Could not fetch prayers for scheduling notifications", error: error)
            return
        }

        guard !prayerDays.isEmpty else {
            log.error("Fetched prayers are empty!")
            return
        }

        log.info("Fetched \(prayerDays.count) days of prayers, begin scheduling notifications")

        // Remove pending prayer notifications to be created fresh
        await userNotification.removePending(
            withCategories: [
                NotificationCategory.main.rawValue,
                NotificationCategory.reminder.rawValue,
                NotificationCategory.calibrate.rawValue,
                NotificationCategory.beacon.rawValue
            ]
        )

        log.debug("Removed pending notifications to recreate fresh")

        let calendar = Calendar(identifier: .gregorian, timeZone: preferences.lastTimeZone)
        let timeFormatStyle = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: preferences.lastTimeZone)
        var lastScheduledDate = dateInterval.end
        var counter = 58 // Unofficial limit for scheduling local notifications
        #if !os(macOS)
        var siriShortcuts = [INRelevantShortcut]()
        #endif

        defer {
            log.info("Scheduled \(58 - counter) notifications successfully")
            scheduleBackgroundRefreshTask(at: lastScheduledDate - .days(2))
            #if !os(macOS)
            Task { [siriShortcuts] in
                do {
                    try await INRelevantShortcutStore.default.setRelevantShortcuts(siriShortcuts)
                    log.debug("Donated \(siriShortcuts.count) Siri shortcuts successfully")
                } catch {
                    log.error("Siri shortcuts could not be stored", error: error)
                }
            }
            #endif
        }

        // Schedule available notifications
        prayerDays.forEach { prayerDay in
            prayerDay.times.forEach { prayerTime in
                guard counter > 0 else { return }

                let isObligation = prayerTime.type.isObligation
                let prefixIdentifier = prayerTime.dateInterval.start
                    .shortString(timeZone: preferences.lastTimeZone, calendar: calendar, locale: .posix)

                // Schedule local notification for each prayer
                let identifier = "\(prefixIdentifier)-\(prayerTime.type)"
                let sound = sound(for: prayerTime.type)
                var userInfo: [String: Any] = [:]

                // Encode prayer time for later retrieval
                do {
                    let data = try prayerTime.encode()
                    userInfo["prayer_time"] = data
                } catch {
                    log.error("Failed to encode prayer time for notification", error: error)
                }

                // Add prayer notifications
                if sound != .off && counter > 0 {
                    userNotification.add(
                        date: prayerTime.dateInterval.start,
                        body: localized.prayerNotificationBody(
                            for: prayerTime,
                            at: prayerTime.dateInterval.start.formatted(timeFormatStyle)
                        ),
                        sound: notificationSound(for: prayerTime.type),
                        interruptionLevel: .timeSensitive,
                        calendar: calendar,
                        identifier: identifier,
                        category: (isObligation ? NotificationCategory.main : .reminder).rawValue,
                        userInfo: userInfo
                    ) {
                        guard let error = $0 else { return }
                        log.error("Failed to create a notifications for \"\(identifier)\"", error: error)
                    }

                    // Update last date and counter
                    lastScheduledDate = prayerTime.dateInterval.start
                    counter -= 1
                } else if sound == .off {
                    userNotification.remove(withIdentifier: identifier)
                }

                #if !os(macOS)
                // Add Siri shortcut
                siriShortcuts.append(
                    INRelevantShortcut(
                        for: prayerTime,
                        formatStyle: timeFormatStyle,
                        region: preferences.lastRegionName,
                        localized: localized,
                        userInfo: userInfo
                    )
                )
                #endif

                // Add reminder notifications
                let reminderIdentifier = "\(identifier)-reminder"
                let reminderSound = preferences.reminderSounds[prayerTime.type] ?? .off
                let reminderMinutes = preferences.preAdhanMinutes[prayerTime.type]

                if reminderSound != .off && reminderMinutes > 0 && counter > 0 {
                    userNotification.add(
                        date: prayerTime.dateInterval.start - .minutes(reminderMinutes),
                        body: localized.prayerNotificationReminder(for: prayerTime, minutes: reminderMinutes),
                        sound: reminderSound.file.map {
                            #if os(iOS)
                            return UNNotificationSound(named: UNNotificationSoundName($0))
                            #else
                            return .default
                            #endif
                        },
                        interruptionLevel: .timeSensitive,
                        calendar: calendar,
                        identifier: reminderIdentifier,
                        category: NotificationCategory.reminder.rawValue,
                        userInfo: userInfo
                    ) {
                        guard let error = $0 else { return }
                        log.error("Failed to create a notifications for \"\(reminderIdentifier)\"", error: error)
                    }

                    // Update counter
                    counter -= 1
                } else if reminderSound == .off {
                    userNotification.remove(withIdentifier: reminderIdentifier)
                }

                // Add imsak notifications if applicable
                if prayerTime.type == .fajr {
                    let reminderIdentifier = "\(identifier)-imsak-reminder"
                    let reminderMinutes = preferences.preAdhanMinutes.imsak

                    if reminderSound != .off && reminderMinutes > 0 && counter > 0 {
                        userNotification.add(
                            date: prayerTime.dateInterval.start - .minutes(reminderMinutes),
                            body: localized.prayerNotificationReminder(for: prayerTime, minutes: reminderMinutes),
                            sound: reminderSound.file.map {
                                #if os(iOS)
                                return UNNotificationSound(named: UNNotificationSoundName($0))
                                #else
                                return .default
                                #endif
                            },
                            interruptionLevel: .timeSensitive,
                            calendar: calendar,
                            identifier: reminderIdentifier,
                            category: NotificationCategory.reminder.rawValue,
                            userInfo: userInfo
                        ) {
                            guard let error = $0 else { return }
                            log.error("Failed to create a notifications for \"\(reminderIdentifier)\"", error: error)
                        }

                        // Update counter
                        counter -= 1
                    } else if reminderSound == .off {
                        userNotification.remove(withIdentifier: reminderIdentifier)
                    }
                }

                // Add iqama notification if applicable
                let iqamaIdentifier = "\(identifier)-iqama-reminder"
                let isJumuah = prayerTime.type == .dhuhr && prayerTime.dateInterval.start.isJumuah(using: calendar)
                let iqamaMinutes = isJumuah ? preferences.iqamaReminders.jumuahMinutes : preferences.iqamaReminders.minutes
                let iqamaSound = preferences.iqamaReminders.sound

                if let iqamaTime = preferences.iqamaTimes[prayerTime, using: calendar], iqamaSound != .off && iqamaMinutes > 0 && counter > 0 {
                    userNotification.add(
                        date: iqamaTime - .minutes(iqamaMinutes),
                        body: isJumuah
                            ? localized.khutbaNotificationBody(at: iqamaTime.formatted(timeFormatStyle))
                            : localized.iqamaNotificationBody(for: prayerTime, at: iqamaTime.formatted(timeFormatStyle)),
                        sound: iqamaSound.file.map {
                            #if os(iOS)
                            return UNNotificationSound(named: UNNotificationSoundName($0))
                            #else
                            return .default
                            #endif
                        },
                        interruptionLevel: .timeSensitive,
                        calendar: calendar,
                        identifier: iqamaIdentifier,
                        category: NotificationCategory.reminder.rawValue,
                        userInfo: userInfo
                    ) {
                        guard let error = $0 else { return }
                        log.error("Failed to create a notifications for \"\(iqamaIdentifier)\"", error: error)
                    }

                    // Update counter
                    counter -= 1
                } else if iqamaSound == .off {
                    userNotification.remove(withIdentifier: iqamaIdentifier)
                }
            }
        }

        // Add iqama update interval if applicable
        var iqamaUpdateInterval: TimeInterval?
        switch (preferences.iqamaReminders.updateInterval, preferences.iqamaTimes.isEmpty) {
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
            let date = -iqamaUpdateIntervalOriginAt.timeIntervalSinceNow < timeInterval ? iqamaUpdateIntervalOriginAt : .now

            userNotification.add(
                date: date.addingTimeInterval(timeInterval),
                body: "Check masjid iqama times",
                interruptionLevel: .passive,
                identifier: iqamaUpdateIntervalIdentifier,
                category: NotificationCategory.reminder.rawValue,
                userInfo: ["origin_at": iqamaUpdateIntervalOriginAt.timeIntervalSince1970]
            ) {
                guard let error = $0 else { return }
                log.error("Failed to create a notifications for \"\(iqamaUpdateIntervalIdentifier)\"", error: error)
            }

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
            log.error("Failed to encode prayer request hash for notifications", error: error)
        }

        userNotification.add(
            date: calibrateDate,
            body: localized.calibrateNotificationBody,
            sound: .default,
            calendar: calendar,
            identifier: "calibrate",
            category: NotificationCategory.calibrate.rawValue,
            userInfo: calibrateUserInfo
        ) {
            guard let error = $0 else { return }
            log.error("Failed to create a notifications for \"calibrate\"", error: error)
        }

        #if os(iOS)
        if preferences.isGPSEnabled && preferences.geofenceRadius > 0 {
            let region = CLCircularRegion(
                center: request.coordinates.location,
                radius: preferences.geofenceRadius,
                identifier: "Home"
            ).apply {
                $0.notifyOnEntry = false
                $0.notifyOnExit = true
            }

            userNotification.add(
                region: region,
                body: localized.beaconNotificationBody,
                title: localized.beaconNotificationTitle,
                sound: .default,
                identifier: "calibrate-beacon",
                category: NotificationCategory.beacon.rawValue,
                userInfo: ["coordinates": request.coordinates.description]
            ) {
                guard let error = $0 else { return }
                log.error("Failed to create a notifications for \"calibrate-beacon\"", error: error)
            }
        } else {
            await userNotification.remove(withCategory: NotificationCategory.beacon.rawValue)
        }
        #endif
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

    func addSnooze(for prayerTime: PrayerTime, in timeInterval: TimeInterval?) -> Date {
        let timeInterval = timeInterval ?? TimeInterval(preferences.snoozeMinutes * 60)
        let date = Date(timeIntervalSinceNow: timeInterval)
        let identifier = "\(date.shortString(timeZone: preferences.lastTimeZone, locale: .posix))-\(prayerTime.type)-snooze"
        let sound = preferences.reminderSounds[prayerTime.type] ?? .off

        userNotification.add(
            timeInterval: timeInterval,
            body: localized.prayerNotificationReminder(for: prayerTime),
            sound: sound.file.map {
                #if os(iOS)
                return UNNotificationSound(named: UNNotificationSoundName($0))
                #else
                return .default
                #endif
            },
            interruptionLevel: .timeSensitive,
            identifier: identifier,
            category: NotificationCategory.snooze.rawValue,
            userInfo: [
                "prayer_time": (try? prayerTime.encode()) ?? Data(),
                // Next trigger date not as expected
                // https://stackoverflow.com/q/40411812
                "trigger_timestamp": date.timeIntervalSince1970
            ]
        ) {
            guard let error = $0 else { return }
            log.error("Failed to create a notifications for \"\(identifier)\"", error: error)
        }

        log.info("Added notification reminder")
        return date
    }

    func removeSnooze() async {
        await userNotification.remove(withCategory: NotificationCategory.snooze.rawValue)
    }
}

// MARK: - Helpers

private extension NotificationServiceUN {
    func sound(for prayer: Prayer) -> NotificationSound {
        preferences.notificationSounds[prayer] ?? .off
    }

    func soundFile(for prayer: Prayer) -> String? {
        let sound = sound(for: prayer)

        guard case .adhan = sound else { return sound.file }
        return (preferences.notificationAdhan[prayer] ?? .alAqsa).file(for: .short)
    }

    func notificationSound(for prayer: Prayer) -> UNNotificationSound? {
        #if os(iOS)
        guard let file = soundFile(for: prayer) else { return nil }
        return UNNotificationSound(named: UNNotificationSoundName(file))
        #else
        return .default
        #endif
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
    convenience init(for prayerTime: PrayerTime, formatStyle: Date.FormatStyle, region: String?, localized: NotificationServiceLocalizable, userInfo: [AnyHashable: Any]) {
        let title = localized.prayerNotificationBody(for: prayerTime, at: prayerTime.dateInterval.start.formatted(formatStyle))
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

public protocol NotificationServiceLocalizable {
    var beaconNotificationBody: String { get }
    var beaconNotificationTitle: String { get }
    var calibrateNotificationBody: String { get }

    func prayerNotificationBody(for prayerTime: PrayerTime, at time: String) -> String
    func prayerNotificationReminder(for prayerTime: PrayerTime) -> String
    func prayerNotificationReminder(for prayerTime: PrayerTime, minutes: Int) -> String
    func iqamaNotificationBody(for prayerTime: PrayerTime, at time: String) -> String
    func khutbaNotificationBody(at time: String) -> String
}
