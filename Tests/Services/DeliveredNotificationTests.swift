//
//  DeliveredNotificationTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

/// Opening, swiping away or snoozing a prayer notification clears the others with it, unless this device clears one at a
/// time, which keeps the later prayers as a checklist and sweeps away only reminders whose prayer has begun (#73).
struct DeliveredNotificationTests {
    private let fajr: DeliveredNotification
    private let dhuhr: DeliveredNotification
    private let asrReminder: DeliveredNotification
    private let dhuhrIqamaReminder: DeliveredNotification
    private let methodSuggestion: DeliveredNotification
    private let day: Date

    init() throws {
        let calendar = Calendar(identifier: .gregorian, timeZone: try #require(TimeZone(identifier: "Asia/Kuala_Lumpur")))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 13)))
        let at = { (hour: Int, minute: Int) in Self.time(hour, minute, on: day) }
        self.day = day

        fajr = DeliveredNotification(identifier: "fajr", category: .main, date: at(5, 38), prayerStart: at(5, 38))
        dhuhr = DeliveredNotification(identifier: "dhuhr", category: .main, date: at(12, 59), prayerStart: at(12, 59))
        // "Asr in 15 minutes", delivered before Asr
        asrReminder = DeliveredNotification(identifier: "asr-reminder", category: .reminder, date: at(16, 6), prayerStart: at(16, 21))
        // "Dhuhr Iqama in 10 minutes", delivered after Dhuhr began
        dhuhrIqamaReminder = DeliveredNotification(identifier: "dhuhr-iqama", category: .reminder, date: at(13, 1), prayerStart: at(12, 59))
        methodSuggestion = DeliveredNotification(identifier: "methodSuggestion", category: .methodSuggestion, date: at(9, 0), prayerStart: nil)
    }

    private var delivered: [DeliveredNotification] { [fajr, dhuhr, asrReminder, dhuhrIqamaReminder, methodSuggestion] }

    private func time(_ hour: Int, _ minute: Int) -> Date {
        Self.time(hour, minute, on: day)
    }

    private static func time(_ hour: Int, _ minute: Int, on day: Date) -> Date {
        day.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
    }
}

extension DeliveredNotificationTests {
    @Test
    func byDefaultEveryPrayerNotificationClearsTogether() {
        let settings = Settings()

        let cleared = settings.deliveredToClear(touching: fajr.identifier, among: delivered, at: time(13, 5))

        #expect(Set(cleared) == [fajr.identifier, dhuhr.identifier, asrReminder.identifier, dhuhrIqamaReminder.identifier])
    }

    @Test
    func clearingOneLeavesTheLaterPrayers() {
        var settings = Settings()
        settings.clearsOneNotification = true

        let cleared = settings.deliveredToClear(touching: fajr.identifier, among: delivered, at: time(13, 5))

        #expect(cleared == [fajr.identifier])
    }

    @Test
    func aReminderWhosePrayerHasBegunGoesWithIt() {
        var settings = Settings()
        settings.clearsOneNotification = true

        let cleared = settings.deliveredToClear(touching: dhuhr.identifier, among: delivered, at: time(16, 30))

        #expect(Set(cleared) == [dhuhr.identifier, asrReminder.identifier])
    }

    @Test
    func aReminderForAPrayerStillToComeStays() {
        var settings = Settings()
        settings.clearsOneNotification = true

        let cleared = settings.deliveredToClear(touching: dhuhr.identifier, among: delivered, at: time(16, 10))

        #expect(cleared == [dhuhr.identifier])
    }

    /// An iqama reminder arrives after its prayer has begun, so the prayer having begun doesn't make it stale.
    @Test
    func anIqamaReminderIsNeverSweptAway() {
        var settings = Settings()
        settings.clearsOneNotification = true

        let cleared = settings.deliveredToClear(touching: fajr.identifier, among: delivered, at: time(16, 30))

        #expect(Set(cleared) == [fajr.identifier, asrReminder.identifier])
    }

    @Test(arguments: [false, true])
    func aMethodSuggestionIsNeverCleared(clearsOne: Bool) {
        var settings = Settings()
        settings.clearsOneNotification = clearsOne

        let cleared = settings.deliveredToClear(touching: fajr.identifier, among: delivered, at: time(13, 5))

        #expect(!cleared.contains(methodSuggestion.identifier))
    }
}
