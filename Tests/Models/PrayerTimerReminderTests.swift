//
//  PrayerTimerReminderTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing
import ZamzamCore

// MARK: - The Reminder of the Prayer Counted To

extension PrayerTimerTests {
    /// 25 minutes before the khutba, over the 80 minutes from Dhuhr's adhan to it.
    @Test(arguments: [(30, 10), (10, 30)])
    func theWarningBeforeTheKhutbaIsAsLongAsDhuhrsReminder(dhuhrMinutes: Int, asrMinutes: Int) throws {
        let prayerTimer = try prayerTimer(
            at: friday(hour: 13, minute: 5),
            preAdhanMinutes: PreAdhanMinutes(rawValue: ["dhuhr": dhuhrMinutes, "asr": asrMinutes])
        )

        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.timerType == .iqama)
        #expect(prayerTimer.countdownDate == friday(hour: 13, minute: 30))
        #expect(prayerTimer.isDangerZone == (dhuhrMinutes >= 25))
        #expect(abs(prayerTimer.dangerZone - (Double(dhuhrMinutes) / 80)) <= 0.0001)
    }
}

// MARK: - The Iqama Timer Switch

extension PrayerTimerTests {
    @Test
    func afterTheKhutbaWithTheTimerOffNothingCountsUpFromIt() throws {
        let prayerTimer = try prayerTimer(at: friday(hour: 13, minute: 45), isIqamaTimerEnabled: false)

        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.countdownDate == friday(hour: 14, minute: 25))
        #expect(prayerTimer.stopwatchEnd == nil)
    }

    @Test
    func afterIshaWithTheTimerOffSunriseAfterIshaCountsToSunrise() throws {
        let prayerTimer = try prayerTimer(at: today(hour: 19, minute: 45), isIqamaTimerEnabled: false, sunriseAfterIsha: true)

        #expect(prayerTimer.type == .sunrise)
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.countdownDate == today(day: 27, hour: 7, minute: 20))
    }

    @Test(arguments: [true, false])
    func fridaysTimelineHoldsTheKhutbaOnlyWhileTheTimerIsOn(isIqamaTimerEnabled: Bool) throws {
        let timer = try prayerTimer(at: friday(hour: 12, minute: 20))
        let calendar = Calendar(identifier: .gregorian, timeZone: timer.timeZone)
        let dhuhr = try #require(timer.prayerDay.times[.dhuhr])
        var settings = Settings()
        settings.iqamaTimes.jumuah = .time(hour: 13, minutes: 30)
        settings.stopwatchMinutes = 20
        settings.isIqamaTimerEnabled = isIqamaTimerEnabled

        let timeline = settings.expandedTimeline(for: dhuhr, using: calendar)
        let khutbaMoments = [friday(hour: 13, minute: 30), friday(hour: 13, minute: 50)]

        try #require(dhuhr.isJumuah(using: calendar))
        #expect(timeline.contains(friday(hour: 12, minute: 10)))
        #expect(khutbaMoments.map(timeline.contains) == [isIqamaTimerEnabled, isIqamaTimerEnabled])
    }
}

// MARK: - The Reminder Moment Before the Khutba

extension PrayerTimerTests {
    /// Dhuhr's 20 minutes are counted back from the khutba at 13:30 while the timer counts to it, else from the adhan at 12:10.
    @Test(arguments: [true, false])
    func fridaysReminderMomentIsCountedBackFromWhatTheTimerCountsTo(isIqamaTimerEnabled: Bool) throws {
        let timer = try prayerTimer(at: friday(hour: 12, minute: 20))
        let calendar = Calendar(identifier: .gregorian, timeZone: timer.timeZone)
        let dhuhr = try #require(timer.prayerDay.times[.dhuhr])
        var settings = Settings()
        settings.iqamaTimes.jumuah = .time(hour: 13, minutes: 30)
        settings.preAdhanMinutes = PreAdhanMinutes(rawValue: ["dhuhr": 20])
        settings.isIqamaTimerEnabled = isIqamaTimerEnabled

        let timeline = settings.expandedTimeline(for: dhuhr, using: calendar)

        #expect(timeline.contains(friday(hour: 13, minute: 10)) == isIqamaTimerEnabled)
        #expect(timeline.contains(friday(hour: 11, minute: 50)) == !isIqamaTimerEnabled)
    }

    @Test(arguments: [20, 45])
    func onAFridayTheTimerTurnsRedAtTheTimelinesReminderMoment(dhuhrMinutes: Int) async throws {
        let prayerManager = PrayTestFixture().prayerManager
        var settings = Settings()
        settings.iqamaTimes.jumuah = .time(hour: 13, minutes: 30)
        settings.preAdhanMinutes = PreAdhanMinutes(rawValue: ["dhuhr": dhuhrMinutes])
        var fridays = [String]()

        for place in DayFixture.all {
            let calendar = try place.calendar()
            let days = try await place.days(1, using: prayerManager)
            let day = try #require(days.first)
            let dhuhr = try #require(day.times[.dhuhr])

            if dhuhr.isJumuah(using: calendar) {
                let khutba = try #require(settings.timerIqama(for: dhuhr, using: calendar))
                let reminder = khutba - .minutes(dhuhrMinutes)
                let atReminder = try #require(PrayerTimer(at: reminder, using: day, settings: settings, timeZone: calendar.timeZone))
                let aSecondBefore = try #require(PrayerTimer(at: reminder - 1, using: day, settings: settings, timeZone: calendar.timeZone))

                fridays.append(place.name)
                #expect(settings.expandedTimeline(for: dhuhr, using: calendar).contains(reminder), "\(place.name)")
                #expect(atReminder.countdownDate == khutba, "\(place.name)")
                #expect(atReminder.isDangerZone, "\(place.name)")
                #expect(!aSecondBefore.isDangerZone, "\(place.name)")
            }
        }

        #expect(fridays.count == 3)
    }
}
