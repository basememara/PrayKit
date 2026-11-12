//
//  PrayerRequestHashTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
@testable import PrayCore
@testable import PrayServices
import Testing

/// Notifications are rescheduled only when the hash changes, so every setting they read must be in it.
struct PrayerRequestHashTests {
    private static let notificationKeys: Set<SettingKey> = [
        .calculationMethod, .juristicMethod, .fajrDegrees, .maghribDegrees, .ishaDegrees, .elevationRule,
        .adjustmentMinutes, .adjustmentElevation, .polarResolution, .isGPSEnabled, .geofenceRadius, .iqamaTimes, .iqamaReminders,
        .preAdhanMinutes, .duhaReminder, .notificationAdhan, .notificationSounds, .reminderSounds, .alarms, .isPlacePinned,
        .enable24hTimeFormat
    ]

    @Test(arguments: SettingKey.allCases)
    func onlyNotificationSettingsChangeTheHash(key: SettingKey) throws {
        let field = try #require(Settings.fields.first { $0.key == key })
        let place = Place(coordinates: Coordinates(latitude: 43.6510, longitude: -79.3470), timeZone: try #require(TimeZone(identifier: "America/Toronto")), regionName: nil, fixedAt: nil)
        let interval = DateInterval(start: Date(timeIntervalSince1970: 1_800_000_000), duration: 7 * 24 * 3600)
        var changed = Settings()
        field.copy(from: .everyFieldChanged, into: &changed)

        // A stored method counts once it's picked by hand; one that follows the place is read from the place
        if key == .calculationMethod {
            changed.manualMethod = Settings.everyFieldChanged.manualMethod
        }

        let before = PrayerRequestHash(request: try #require(PrayerAPI.Request(settings: Settings(), place: place)), dateInterval: interval, settings: Settings())
        let after = PrayerRequestHash(request: try #require(PrayerAPI.Request(settings: changed, place: place)), dateInterval: interval, settings: changed)

        #expect((before != after) == Self.notificationKeys.contains(key))
    }

    /// The notification text writes its times on the app's clock, so switching it reschedules.
    @Test
    func theTwentyFourHourSettingChangesTheHash() throws {
        let place = Place(coordinates: Coordinates(latitude: 43.6510, longitude: -79.3470), timeZone: try #require(TimeZone(identifier: "America/Toronto")), regionName: nil, fixedAt: nil)
        let interval = DateInterval(start: Date(timeIntervalSince1970: 1_800_000_000), duration: 7 * 24 * 3600)
        let request = try #require(PrayerAPI.Request(settings: Settings(), place: place))
        var twentyFourHour = Settings()
        twentyFourHour.enable24hTimeFormat = true

        #expect(PrayerRequestHash(request: request, dateInterval: interval, settings: Settings()) != PrayerRequestHash(request: request, dateInterval: interval, settings: twentyFourHour))
    }

    /// A hash stored before a field joined it can't be read back, which the scheduler counts as a changed request.
    @Test
    func aHashStoredWithoutTheTwentyFourHourFieldIsUnreadable() throws {
        let place = Place(coordinates: Coordinates(latitude: 43.6510, longitude: -79.3470), timeZone: try #require(TimeZone(identifier: "America/Toronto")), regionName: nil, fixedAt: nil)
        let interval = DateInterval(start: Date(timeIntervalSince1970: 1_800_000_000), duration: 7 * 24 * 3600)
        let hash = PrayerRequestHash(request: try #require(PrayerAPI.Request(settings: Settings(), place: place)), dateInterval: interval, settings: Settings())
        var stored = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(hash)) as? [String: Any])
        stored["enable24hTimeFormat"] = nil
        let older = try JSONSerialization.data(withJSONObject: stored)

        #expect(throws: DecodingError.self) { try JSONDecoder().decode(PrayerRequestHash.self, from: older) }
    }
}
