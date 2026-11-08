//
//  PrayerTimerStopwatchTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-08.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing
import ZamzamCore

// MARK: - Iqama over Stopwatch

extension PrayerTimerTests {
    @Test
    func afterTheAdhanAnIqamaCountsDownInsteadOfTheStopwatch() throws {
        let prayers: [(prayer: Prayer, adhan: Date, iqama: Date)] = [
            (.fajr, today(hour: 5, minute: 52), today(hour: 6, minute: 15)),
            (.dhuhr, today(hour: 12, minute: 10), today(hour: 12, minute: 45)),
            (.asr, today(hour: 14, minute: 25), today(hour: 15, minute: 0)),
            (.maghrib, today(hour: 16, minute: 50), today(hour: 17, minute: 0)),
            (.isha, today(hour: 18, minute: 15), today(hour: 19, minute: 30))
        ]

        try prayers.forEach { item in
            let prayerTimer = try prayerTimer(at: item.adhan + .minutes(1))
            #expect(prayerTimer.type == item.prayer)
            #expect(prayerTimer.timerType == .iqama)
            #expect(prayerTimer.countdownDate == item.iqama)
        }
    }

    @Test
    func afterTheIqamaPassesInsideTheCountUpTheTimerCountsDownToTheNextPrayer() throws {
        let prayerTimer = try prayerTimer(at: today(hour: 12, minute: 50), stopwatchMinutes: 60)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.countdownDate == today(hour: 14, minute: 25))
        assertCalculations(for: prayerTimer, minutes: 95)
    }
}

// MARK: - Stopwatch End

extension PrayerTimerTests {
    @Test
    func theCountUpEndsItsMinutesAfterTheAdhan() throws {
        let prayerTimer = try prayerTimer(at: today(hour: 12, minute: 20), isIqamaTimerEnabled: false, stopwatchMinutes: 20)
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(prayerTimer.stopwatchEnd == today(hour: 12, minute: 30))
    }

    @Test
    func aCountdownHasNoCountUpEnd() throws {
        let prayerTimer = try prayerTimer(at: today(hour: 11, minute: 0))
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.stopwatchEnd == nil)
    }
}

// MARK: - Stopwatch without an Iqama

extension PrayerTimerTests {
    @Test
    func afterFajrAdhan() async throws {
        let date = today(hour: 6, minute: 0)
        let prayerTimer = try prayerTimer(at: date, isIqamaTimerEnabled: false)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 5, minute: 52))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.isNamedJumuah == prayerTimer.isJumuah)
        assertCalculations(for: prayerTimer, minutes: -8)
    }

    @Test
    func afterDhuhrAdhan() async throws {
        let date = today(hour: 12, minute: 20)
        let prayerTimer = try prayerTimer(at: date, isIqamaTimerEnabled: false)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == today(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.isNamedJumuah == prayerTimer.isJumuah)
        assertCalculations(for: prayerTimer, minutes: -10)
    }

    @Test
    func afterDhuhrAdhanOnJumuahBeforeTheKhutba() async throws {
        let date = friday(hour: 12, minute: 20)
        let prayerTimer = try prayerTimer(at: date, isIqamaTimerEnabled: false)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(!prayerTimer.isNamedJumuah)
        assertCalculations(for: prayerTimer, minutes: -10)
    }

    @Test
    func afterAsrAdhan() async throws {
        let date = today(hour: 14, minute: 40)
        let prayerTimer = try prayerTimer(at: date, isIqamaTimerEnabled: false)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.countdownDate == today(hour: 14, minute: 25))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.isNamedJumuah == prayerTimer.isJumuah)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    @Test
    func afterIshaAdhan() async throws {
        let date = today(hour: 18, minute: 20)
        let prayerTimer = try prayerTimer(at: date, isIqamaTimerEnabled: false)
        #expect(prayerTimer.type == .isha)
        #expect(prayerTimer.countdownDate == today(hour: 18, minute: 15))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.isNamedJumuah == prayerTimer.isJumuah)
        assertCalculations(for: prayerTimer, minutes: -5)
    }
}
