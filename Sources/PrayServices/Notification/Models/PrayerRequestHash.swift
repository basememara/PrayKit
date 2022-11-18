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
    let isGPSEnabled: Bool
    let geofenceRadius: Double

    init(request: PrayerAPI.Request, dateInterval: DateInterval, preferences: Preferences) {
        self.request = request
        self.snoozeMinutes = preferences.snoozeMinutes
        self.preAdhanMinutes = preferences.preAdhanMinutes
        self.sunriseAfterIsha = preferences.sunriseAfterIsha
        self.notificationAdhan = preferences.notificationAdhan
        self.notificationSounds = preferences.notificationSounds
        self.reminderSounds = preferences.reminderSounds
        self.isGPSEnabled = preferences.isGPSEnabled
        self.geofenceRadius = preferences.geofenceRadius

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
