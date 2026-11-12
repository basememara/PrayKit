//
//  NotificationTextTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices
import Testing

/// The plan names its wording and holds dates; these render it the way the applier does.
struct NotificationTextTests {
    private let timeZone = TimeZone(identifier: "America/Toronto") ?? .gmt
    private let locale = Locale(identifier: "en_US")

    @Test(arguments: [(true, "Asr at 15:49"), (false, "Asr at 3:49\u{202F}PM")])
    func aPrayerIsWrittenOnTheAppsClock(is24Hour: Bool, expected: String) throws {
        let asr = PrayerTime(type: .asr, dateInterval: DateInterval(start: try date(hour: 15, minute: 49), duration: 3600))
        #expect(text(of: .prayer(asr), is24Hour: is24Hour) == expected)
    }

    @Test(arguments: [(true, "Duha reminder at 07:45"), (false, "Duha reminder at 7:45\u{202F}AM")])
    func theDuhaReminderIsWrittenOnTheAppsClock(is24Hour: Bool, expected: String) throws {
        #expect(text(of: .duha(at: try date(hour: 7, minute: 45)), is24Hour: is24Hour) == expected)
    }

    @Test
    func theIqamaUpdateIsWrittenInTheAppsLanguage() throws {
        let request = try #require(try iqamaUpdateRequest())
        #expect(text(of: request.body, is24Hour: false) == "Check your masjid's iqama times")
    }
}

// MARK: - Helpers

private extension NotificationTextTests {
    var calendar: Calendar {
        Calendar(identifier: .gregorian, timeZone: timeZone)
    }

    func date(hour: Int, minute: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: hour, minute: minute)))
    }

    /// The iqama-update request of a plan whose settings have an iqama and a weekly update reminder.
    func iqamaUpdateRequest() throws -> NotificationPlan.Request? {
        let place = Place(coordinates: Coordinates(latitude: 43.6510, longitude: -79.3470), timeZone: timeZone, regionName: nil, fixedAt: nil)
        let now = try date(hour: 12, minute: 0)
        var settings = Settings()
        settings.iqamaTimes.asr = .minutes(10)
        settings.iqamaReminders.updateInterval = .weekly
        let request = try #require(PrayerAPI.Request(settings: settings, place: place))
        let week = DateInterval(start: now, duration: 7 * 24 * 3600)
        let plan = NotificationPlan.make(
            days: [],
            settings: settings,
            request: request,
            requestHash: PrayerRequestHash(request: request, dateInterval: week, settings: settings),
            now: now,
            iqamaUpdateOrigin: nil
        )

        return plan.requests.first { $0.identifier == NotificationPlan.iqamaUpdateIdentifier }
    }

    func text(of body: NotificationPlan.Body, is24Hour: Bool) -> String {
        let timeFormatter = DateFormatter.prayerTime(is24Hour: is24Hour, using: timeZone, locale: locale)
        return body.text(localized: EnglishNotificationText(), timeFormatter: timeFormatter, calendar: calendar)
    }
}

// MARK: - Types

private struct EnglishNotificationText: NotificationServiceLocalizable {
    let beaconNotificationBody = "Beacon"
    let beaconNotificationTitle = "Beacon title"
    let calibrateNotificationBody = "Calibrate"
    let iqamaUpdateNotificationBody = "Check your masjid's iqama times"

    func prayerNotificationBody(for prayerTime: PrayerTime, at time: String, using calendar: Calendar) -> String {
        "\(prayerTime.type.rawValue.capitalized) at \(time)"
    }

    func prayerNotificationReminder(for prayerTime: PrayerTime, using calendar: Calendar) -> String {
        "\(prayerTime.type.rawValue.capitalized) reminder"
    }

    func prayerNotificationReminder(for prayerTime: PrayerTime, minutes: Int, using calendar: Calendar) -> String {
        "\(prayerTime.type.rawValue.capitalized) in \(minutes) mins"
    }

    func iqamaNotificationBody(for prayerTime: PrayerTime, minutes: Int, isJumuah: Bool) -> String {
        "\(prayerTime.type.rawValue.capitalized) Iqama in \(minutes) mins"
    }

    func duhaNotificationBody(at time: String) -> String {
        "Duha reminder at \(time)"
    }
}
