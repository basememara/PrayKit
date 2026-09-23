//
//  PrayerTimerTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2022-11-26.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import Testing
import PrayCore
import PrayMocks
import ZamzamCore

struct PrayerTimerTests {
    private let timeZone = TimeZone(identifier: "America/New_York") ?? .current
    private let calendar: Calendar

    init() {
        calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
    }
}

// MARK: - Iqama, Stopwatch, Jumuah

extension PrayerTimerTests {
    @Test
    func beforeIshaAdhanWithIqama() async throws {
        let date = today(hour: 17, minute: 55)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .isha)
        #expect(prayerTimer.countdownDate == today(hour: 18, minute: 15))
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.isDangerZone)
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 20)
    }

    @Test
    func afterIshaAdhanWithIqama() async throws {
        let date = today(hour: 18, minute: 20)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .isha)
        #expect(prayerTimer.countdownDate == today(hour: 18, minute: 15))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: -5)
    }

    @Test
    func beforeIshaIqama() async throws {
        let date = today(hour: 18, minute: 35)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .isha)
        #expect(prayerTimer.countdownDate == today(hour: 19, minute: 30))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 55, lastAdhanTime: today(hour: 18, minute: 15))
    }

    @Test
    func afterIshaIqama() async throws {
        let date = today(hour: 19, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 5, minute: 52) + .days(1))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 10 * 60 + 7)
    }

    @Test
    func beforeFajrAdhanWithIqama() async throws {
        let date = today(hour: 5, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 5, minute: 52))
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.isDangerZone)
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 12)
    }

    @Test
    func afterFajrAdhanWithIqama() async throws {
        let date = today(hour: 6, minute: 0)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 5, minute: 52))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: -8)
    }

    @Test
    func beforeFajrIqama() async throws {
        let date = today(hour: 6, minute: 12)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 6, minute: 15))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 3, lastAdhanTime: today(hour: 5, minute: 52))
    }

    @Test
    func afterFajrIqama() async throws {
        let date = today(hour: 6, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .sunrise)
        #expect(prayerTimer.countdownDate == today(hour: 7, minute: 20))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 50)
    }

    @Test
    func beforeSunriseWithIqama() async throws {
        let date = today(hour: 7, minute: 5)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .sunrise)
        #expect(prayerTimer.countdownDate == today(hour: 7, minute: 20))
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.isDangerZone)
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 15)
    }

    @Test
    func afterSunriseWithIqama() async throws {
        let date = today(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == today(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 4 * 60 + 40)
    }

    @Test
    func beforeDhuhrAdhanWithIqama() async throws {
        let date = today(hour: 11, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == today(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 25)
    }

    @Test
    func afterDhuhrAdhanWithIqama() async throws {
        let date = today(hour: 12, minute: 20)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == today(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: -10)
    }

    @Test
    func beforeDhuhrIqama() async throws {
        let date = today(hour: 12, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == today(hour: 12, minute: 45))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 15, lastAdhanTime: today(hour: 12, minute: 10))
    }

    @Test
    func afterDhuhrIqama() async throws {
        let date = today(hour: 13, minute: 0)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.countdownDate == today(hour: 14, minute: 25))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 85)
    }

    @Test
    func beforeAsrAdhanWithIqama() async throws {
        let date = today(hour: 14, minute: 15)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.countdownDate == today(hour: 14, minute: 25))
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.isDangerZone)
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 10)
    }

    @Test
    func afterAsrAdhanWithIqama() async throws {
        let date = today(hour: 14, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.countdownDate == today(hour: 14, minute: 25))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    @Test
    func beforeAsrIqama() async throws {
        let date = today(hour: 14, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.countdownDate == today(hour: 15, minute: 0))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 15, lastAdhanTime: today(hour: 14, minute: 25))
    }

    @Test
    func afterAsrIqama() async throws {
        let date = today(hour: 15, minute: 15)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .maghrib)
        #expect(prayerTimer.countdownDate == today(hour: 16, minute: 50))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 95)
    }

    @Test
    func beforeMaghribAdhanWithIqama() async throws {
        let date = today(hour: 16, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .maghrib)
        #expect(prayerTimer.countdownDate == today(hour: 16, minute: 50))
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.isDangerZone)
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 10)
    }

    @Test
    func afterMaghribAdhanWithIqama() async throws {
        let date = today(hour: 16, minute: 55)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .maghrib)
        #expect(prayerTimer.countdownDate == today(hour: 17, minute: 0))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 5, lastAdhanTime: today(hour: 16, minute: 50))
    }

    @Test
    func afterMaghribIqama() async throws {
        let date = today(hour: 17, minute: 10)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .isha)
        #expect(prayerTimer.countdownDate == today(hour: 18, minute: 15))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 65)
    }
}

// MARK: Jumuah

extension PrayerTimerTests {
    @Test
    func afterSunriseBeforeJumuah() async throws {
        let date = friday(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 13, minute: 30))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 6 * 60, lastAdhanTime: friday(hour: 7, minute: 20))
    }

    @Test
    func afterSunriseBeforeDhuhrOnJumuah() async throws {
        let date = friday(hour: 11, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 13, minute: 30))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 1 * 60 + 45, lastAdhanTime: friday(hour: 7, minute: 20))
    }

    @Test
    func afterDhuhrAdhanOnJumuah() async throws {
        let date = friday(hour: 12, minute: 20)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt == nil)
        assertCalculations(for: prayerTimer, minutes: -10)
    }

    @Test
    func beforeDhuhrIqamaOnJumuah() async throws {
        let date = friday(hour: 12, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 13, minute: 30))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 60, lastAdhanTime: friday(hour: 12, minute: 10))
    }

    @Test
    func afterJumuahKhutba() async throws {
        let date = friday(hour: 13, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 13, minute: 30))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    @Test
    func beforeAsrAdhanOnJumuah() async throws {
        let date = friday(hour: 14, minute: 15)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.countdownDate == friday(hour: 14, minute: 25))
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.isDangerZone)
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 10)
    }

    @Test
    func afterAsrAdhanOnJumuah() async throws {
        let date = friday(hour: 14, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.countdownDate == friday(hour: 14, minute: 25))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    @Test
    func beforeAsrIqamaOnJumuah() async throws {
        let date = friday(hour: 14, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.countdownDate == friday(hour: 15, minute: 0))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 15, lastAdhanTime: friday(hour: 14, minute: 25))
    }

    @Test
    func afterAsrIqamaOnJumuah() async throws {
        let date = friday(hour: 15, minute: 15)
        let prayerTimer = try prayerTimer(at: date)
        #expect(prayerTimer.type == .maghrib)
        #expect(prayerTimer.countdownDate == friday(hour: 16, minute: 50))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 95)
    }
}

// MARK: No Jumuah

extension PrayerTimerTests {
    @Test
    func afterSunriseBeforeNoJumuah() async throws {
        let date = friday(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date, isJumuahEnabled: false)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 4 * 60 + 40)
    }

    @Test
    func afterSunriseBeforeDhuhrOnNoJumuah() async throws {
        let date = friday(hour: 11, minute: 55)
        let prayerTimer = try prayerTimer(at: date, isJumuahEnabled: false)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.isDangerZone)
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 15)
    }

    @Test
    func afterDhuhrAdhanOnNoJumuah() async throws {
        let date = friday(hour: 12, minute: 20)
        let prayerTimer = try prayerTimer(at: date, isJumuahEnabled: false)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: -10)
    }

    @Test
    func beforeDhuhrIqamaOnNoJumuah() async throws {
        let date = friday(hour: 12, minute: 30)
        let prayerTimer = try prayerTimer(at: date, isJumuahEnabled: false)
        #expect(prayerTimer.type == .asr)
        #expect(prayerTimer.countdownDate == friday(hour: 14, minute: 25))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 60 + 55)
    }
}

// MARK: - Iqama, Stopwatch, Sunrise

extension PrayerTimerTests {
    @Test
    func afterIshaAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 18, minute: 20)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        #expect(prayerTimer.type == .isha)
        #expect(prayerTimer.countdownDate == today(hour: 18, minute: 15))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: -5)
    }

    @Test
    func beforeIshaIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 18, minute: 35)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        #expect(prayerTimer.type == .isha)
        #expect(prayerTimer.countdownDate == today(hour: 19, minute: 30))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 55, lastAdhanTime: today(hour: 18, minute: 15))
    }

    @Test
    func afterIshaIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 19, minute: 45)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 6, minute: 15) + .days(1))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 10 * 60 + 30, lastAdhanTime: today(hour: 18, minute: 15))
    }

    @Test
    func beforeFajrAdhanIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 5, minute: 40)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 6, minute: 15))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 35, lastAdhanTime: today(hour: 18, minute: 15) - .days(1, calendar))
    }

    @Test
    func afterFajrAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 6, minute: 0)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 5, minute: 52))
        #expect(prayerTimer.timerType == .stopwatch)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: -8)
    }

    @Test
    func beforeFajrIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 6, minute: 12)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 6, minute: 15))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 3, lastAdhanTime: today(hour: 5, minute: 52))
    }

    @Test
    func afterFajrIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 6, minute: 30)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        #expect(prayerTimer.type == .sunrise)
        #expect(prayerTimer.countdownDate == today(hour: 7, minute: 20))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 50)
    }

    @Test
    func beforeSunriseWithSunriseAfterIsha() async throws {
        let date = today(hour: 7, minute: 5)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        #expect(prayerTimer.type == .sunrise)
        #expect(prayerTimer.countdownDate == today(hour: 7, minute: 20))
        #expect(prayerTimer.timerType == .countdown)
        #expect(prayerTimer.isDangerZone)
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 15)
    }

    @Test
    func afterSunriseWithSunriseAfterIsha() async throws {
        let date = today(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == today(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 4 * 60 + 40)
    }
}

// MARK: - Stopwatch, Sunrise

extension PrayerTimerTests {
    @Test
    func beforeIsha() async throws {
        let date = today(hour: 18, minute: 35)
        let prayerTimer = try prayerTimer(at: date, isIqamaTimerEnabled: false)
        #expect(prayerTimer.type == .fajr)
        #expect(prayerTimer.countdownDate == today(hour: 5, minute: 52) + .days(1, calendar))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 11 * 60 + 17)
    }

    @Test
    func beforeDhuhr() async throws {
        let date = today(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date, isIqamaTimerEnabled: false)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == today(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(!(prayerTimer.isJumuah))
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 4 * 60 + 40)
    }

    @Test
    func beforeDhuhrOnJumuah() async throws {
        let date = friday(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date, isIqamaTimerEnabled: false)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 13, minute: 30))
        #expect(prayerTimer.timerType == .iqama)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 6 * 60, lastAdhanTime: friday(hour: 7, minute: 20))
    }

    @Test
    func beforeDhuhrOnJumuahNoKhutba() async throws {
        let date = friday(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date, isIqamaTimerEnabled: false, isJumuahEnabled: false)
        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.countdownDate == friday(hour: 12, minute: 10))
        #expect(prayerTimer.timerType == .countdown)
        #expect(!(prayerTimer.isDangerZone))
        #expect(prayerTimer.isJumuah)
        #expect(prayerTimer.localizeAt != nil)
        assertCalculations(for: prayerTimer, minutes: 4 * 60 + 40)
    }
}

// MARK: - Helpers

private extension PrayerTimerTests {
    func assertCalculations(for prayerTimer: PrayerTimer, minutes: Int, lastAdhanTime: Date? = nil) {
        let componentFormatStyle = Date.ComponentsFormatStyle(style: .condensedAbbreviated, fields: [.minute])
        let formattedComponent = prayerTimer.timeRange.formatted(componentFormatStyle).components(separatedBy: .decimalDigits.inverted).joined()

        #expect(prayerTimer.timeRemaining == Double(minutes) * 60)
        #expect(formattedComponent == "\(abs(minutes))")

        switch prayerTimer.timerType {
        case .stopwatch:
            #expect(abs(prayerTimer.progressRemaining - (1 + prayerTimer.timeRemaining / prayerTimer.timeDuration)) <= 0.0001)
        case .iqama:
            #expect(abs(prayerTimer.progressRemaining - (1 - prayerTimer.date.timeIntervalSince(lastAdhanTime ?? .distantPast) / prayerTimer.timeDuration)) <= 0.0001)
        case .countdown:
            #expect(abs(prayerTimer.progressRemaining - prayerTimer.timeRemaining / prayerTimer.timeDuration) <= 0.0001)
        }
    }
}

private extension PrayerTimerTests {
    func prayerTimer(
        at date: Date,
        isIqamaTimerEnabled: Bool = true,
        stopwatchMinutes: Int = 20,
        sunriseAfterIsha: Bool = false,
        isJumuahEnabled: Bool = true
    ) throws -> PrayerTimer {
        let prayerDay = PrayerDay.mock(
            at: date,
            times: [(5, 52), (7, 20), (12, 10), (14, 25), (16, 50), (18, 15), (0, 28), (1, 46)],
            calendar: calendar,
            filter: .essential
        )

        let iqamaTimes = IqamaTimes(
            fajr: .time(hour: 6, minutes: 15),
            dhuhr: .time(hour: 12, minutes: 45),
            asr: .time(hour: 15, minutes: 0),
            maghrib: .minutes(10),
            isha: .time(hour: 19, minutes: 30),
            jumuah: isJumuahEnabled ? .time(hour: 13, minutes: 30) : nil
        )

        return try #require(PrayerTimer(
                at: date,
                using: prayerDay,
                iqamaTimes: iqamaTimes,
                isIqamaTimerEnabled: isIqamaTimerEnabled,
                stopwatchMinutes: stopwatchMinutes,
                preAdhanMinutes: PreAdhanMinutes(
                    rawValue: [
                        Prayer.fajr.rawValue: 20,
                        Prayer.sunrise.rawValue: 20,
                        Prayer.dhuhr.rawValue: 20,
                        Prayer.asr.rawValue: 20,
                        Prayer.maghrib.rawValue: 20,
                        Prayer.isha.rawValue: 25
                    ]
                ),
                sunriseAfterIsha: sunriseAfterIsha,
                timeZone: timeZone
            ))
    }

    func today(day: Int = 26, hour: Int, minute: Int) -> Date {
        Date(year: 2022, month: 11, day: day, hour: hour, minute: minute, timeZone: timeZone) ?? .now
    }

    func friday(hour: Int, minute: Int) -> Date {
        today(day: 25, hour: hour, minute: minute)
    }
}
