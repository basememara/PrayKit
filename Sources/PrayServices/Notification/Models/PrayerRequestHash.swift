//
//  PrayerRequestHash.swift
//  PrayServices
//
//  Created by Basem Emara on 2021-06-28.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation.NSDateFormatter
import PrayCore
import ZamzamCore

struct PrayerRequestHash: Identifiable, Equatable, Codable {
    let id: String
    let request: PrayerAPI.Request
    let snoozeMinutes: Int
    let preAdhanMinutes: PreAdhanMinutes
    let sunriseAfterIsha: Bool
    let notificationAdhan: NotificationAdhan
    let notificationSounds: NotificationSounds
    let reminderSounds: ReminderSounds
    let iqamaTimes: IqamaTimes
    let iqamaReminders: IqamaReminders
    let duhaReminder: DuhaType?
    let isGPSEnabled: Bool
    let geofenceRadius: Double

    init(request: PrayerAPI.Request, dateInterval: DateInterval, settings: Settings) {
        self.request = request
        self.snoozeMinutes = settings.snoozeMinutes
        self.preAdhanMinutes = settings.preAdhanMinutes
        self.sunriseAfterIsha = settings.sunriseAfterIsha
        self.notificationAdhan = settings.notificationAdhan
        self.notificationSounds = settings.notificationSounds
        self.reminderSounds = settings.reminderSounds
        self.iqamaTimes = settings.iqamaTimes
        self.iqamaReminders = settings.iqamaReminders
        self.duhaReminder = settings.duhaReminder
        self.isGPSEnabled = settings.isGPSEnabled
        self.geofenceRadius = settings.geofenceRadius

        let calendar = Calendar(
            identifier: .gregorian,
            timeZone: request.timeZone,
            locale: .posix
        )

        self.id = [
            dateInterval.start.shortString(calendar: calendar),
            "|",
            dateInterval.end.shortString(calendar: calendar)
        ].joined()
    }
}
