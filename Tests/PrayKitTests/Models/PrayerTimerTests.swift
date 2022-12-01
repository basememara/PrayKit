//
//  PrayerTimerTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2022-11-26.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import XCTest
import PrayCore
import PrayMocks
import ZamzamCore

final class PrayerTimerTests: XCTestCase {
    let timeZone = TimeZone(identifier: "America/New_York") ?? .current
    lazy var calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
}

// MARK: - Iqama, Stopwatch, Jumuah

extension PrayerTimerTests {
    func testBeforeIshaAdhan() async throws {
        let date = today(hour: 18, minute: 0)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .isha)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 18, minute: 15))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15)
    }

    func testAfterIshaAdhan() async throws {
        let date = today(hour: 18, minute: 20)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .isha)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 18, minute: 15))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -5)
    }

    func testBeforeIshaIqama() async throws {
        let date = today(hour: 18, minute: 35)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .isha)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 19, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 55, lastAdhanTime: today(hour: 18, minute: 15))
    }

    func testAfterIshaIqama() async throws {
        let date = today(hour: 19, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .fajr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 5, minute: 52) + .days(1))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 10 * 60 + 7)
    }
}

extension PrayerTimerTests {
    func testBeforeFajrAdhan() async throws {
        let date = today(hour: 5, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .fajr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 5, minute: 52))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 12)
    }

    func testAfterFajrAdhan() async throws {
        let date = today(hour: 6, minute: 0)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .fajr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 5, minute: 52))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -8)
    }

    func testBeforeFajrIqama() async throws {
        let date = today(hour: 6, minute: 12)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .fajr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 6, minute: 15))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 3, lastAdhanTime: today(hour: 5, minute: 52))
    }

    func testAfterFajrIqama() async throws {
        let date = today(hour: 6, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .sunrise)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 7, minute: 20))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 50)
    }
}

extension PrayerTimerTests {
    func testBeforeSunrise() async throws {
        let date = today(hour: 7, minute: 5)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .sunrise)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 7, minute: 20))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15)
    }

    func testAfterSunrise() async throws {
        let date = today(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 12, minute: 10))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 4 * 60 + 40)
    }
}

extension PrayerTimerTests {
    func testBeforeDhuhrAdhan() async throws {
        let date = today(hour: 11, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 12, minute: 10))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 25)
    }

    func testAfterDhuhrAdhan() async throws {
        let date = today(hour: 12, minute: 20)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 12, minute: 10))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -10)
    }

    func testBeforeDhuhrIqama() async throws {
        let date = today(hour: 12, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 12, minute: 45))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15, lastAdhanTime: today(hour: 12, minute: 10))
    }

    func testAfterDhuhrIqama() async throws {
        let date = today(hour: 13, minute: 0)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 85)
    }
}

extension PrayerTimerTests {
    func testBeforeAsrAdhan() async throws {
        let date = today(hour: 14, minute: 15)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 10)
    }

    func testAfterAsrAdhan() async throws {
        let date = today(hour: 14, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    func testBeforeAsrIqama() async throws {
        let date = today(hour: 14, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 15, minute: 0))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15, lastAdhanTime: today(hour: 14, minute: 25))
    }

    func testAfterAsrIqama() async throws {
        let date = today(hour: 15, minute: 15)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .maghrib)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 16, minute: 50))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 95)
    }
}

extension PrayerTimerTests {
    func testBeforeMaghribAdhan() async throws {
        let date = today(hour: 16, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .maghrib)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 16, minute: 50))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 10)
    }

    func testAfterMaghribAdhan() async throws {
        let date = today(hour: 16, minute: 55)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .maghrib)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 17, minute: 0))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 5, lastAdhanTime: today(hour: 16, minute: 50))
    }

    func testAfterMaghribIqama() async throws {
        let date = today(hour: 17, minute: 10)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .isha)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 18, minute: 15))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 65)
    }
}

// MARK: Jumuah

extension PrayerTimerTests {
    func testAfterSunriseBeforeJumuah() async throws {
        let date = friday(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 13, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 6 * 60, lastAdhanTime: friday(hour: 7, minute: 20))
    }

    func testAfterSunriseBeforeDhuhrOnJumuah() async throws {
        let date = friday(hour: 11, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 13, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 1 * 60 + 45, lastAdhanTime: friday(hour: 7, minute: 20))
    }

    func testAfterDhuhrAdhanOnJumuah() async throws {
        let date = friday(hour: 12, minute: 20)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 12, minute: 10))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -10)
    }

    func testBeforeDhuhrIqamaOnJumuah() async throws {
        let date = friday(hour: 12, minute: 30)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 13, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 60, lastAdhanTime: friday(hour: 12, minute: 10))
    }

    func testAfterJumuahKhutba() async throws {
        let date = friday(hour: 13, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 13, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    func testBeforeAsrAdhanOnJumuah() async throws {
        let date = friday(hour: 14, minute: 15)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 10)
    }

    func testAfterAsrAdhanOnJumuah() async throws {
        let date = friday(hour: 14, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    func testBeforeAsrIqamaOnJumuah() async throws {
        let date = friday(hour: 14, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 15, minute: 0))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15, lastAdhanTime: friday(hour: 14, minute: 25))
    }

    func testAfterAsrIqamaOnJumuah() async throws {
        let date = friday(hour: 15, minute: 15)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .maghrib)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 16, minute: 50))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 95)
    }
}

// MARK: - Iqama, Stopwatch, Sunrise

extension PrayerTimerTests {
    func testBeforeIshaAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 18, minute: 0)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .isha)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 18, minute: 15))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15)
    }

    func testAfterIshaAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 18, minute: 20)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .isha)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 18, minute: 15))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -5)
    }

    func testBeforeIshaIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 18, minute: 35)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .isha)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 19, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 55, lastAdhanTime: today(hour: 18, minute: 15))
    }

    func testAfterIshaIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 19, minute: 45)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .fajr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 5, minute: 52) + .days(1))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 10 * 60 + 7)
    }
}

extension PrayerTimerTests {
    func testBeforeFajrAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 5, minute: 40)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .fajr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 5, minute: 52))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 12)
    }

    func testAfterFajrAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 6, minute: 0)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .fajr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 5, minute: 52))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -8)
    }

    func testBeforeFajrIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 6, minute: 12)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .fajr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 6, minute: 15))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 3, lastAdhanTime: today(hour: 5, minute: 52))
    }

    func testAfterFajrIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 6, minute: 30)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .sunrise)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 7, minute: 20))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 50)
    }
}

extension PrayerTimerTests {
    func testBeforeSunriseWithSunriseAfterIsha() async throws {
        let date = today(hour: 7, minute: 5)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .sunrise)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 7, minute: 20))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15)
    }

    func testAfterSunriseWithSunriseAfterIsha() async throws {
        let date = today(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 12, minute: 10))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 4 * 60 + 40)
    }
}

extension PrayerTimerTests {
    func testBeforeDhuhrAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 11, minute: 45)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 12, minute: 10))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 25)
    }

    func testAfterDhuhrAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 12, minute: 20)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 12, minute: 10))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -10)
    }

    func testBeforeDhuhrIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 12, minute: 30)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 12, minute: 45))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15, lastAdhanTime: today(hour: 12, minute: 10))
    }

    func testAfterDhuhrIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 13, minute: 0)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 85)
    }
}

extension PrayerTimerTests {
    func testBeforeAsrAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 14, minute: 15)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 10)
    }

    func testAfterAsrAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 14, minute: 40)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    func testBeforeAsrIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 14, minute: 45)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 15, minute: 0))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15, lastAdhanTime: today(hour: 14, minute: 25))
    }

    func testAfterAsrIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 15, minute: 15)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .maghrib)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 16, minute: 50))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 95)
    }
}

extension PrayerTimerTests {
    func testBeforeMaghribAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 16, minute: 40)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .maghrib)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 16, minute: 50))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 10)
    }

    func testAfterMaghribAdhanWithSunriseAfterIsha() async throws {
        let date = today(hour: 16, minute: 55)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .maghrib)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 17, minute: 0))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 5, lastAdhanTime: today(hour: 16, minute: 50))
    }

    func testAfterMaghribIqamaWithSunriseAfterIsha() async throws {
        let date = today(hour: 17, minute: 10)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .isha)
        XCTAssertEqual(prayerTimer.countdownDate, today(hour: 18, minute: 15))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 65)
    }
}

// MARK: Jumuah

extension PrayerTimerTests {
    func testAfterSunriseBeforeJumuahWithSunriseAfterIsha() async throws {
        let date = friday(hour: 7, minute: 30)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 13, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 6 * 60, lastAdhanTime: friday(hour: 7, minute: 20))
    }

    func testAfterSunriseBeforeDhuhrOnJumuahWithSunriseAfterIsha() async throws {
        let date = friday(hour: 11, minute: 45)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 13, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 1 * 60 + 45, lastAdhanTime: friday(hour: 7, minute: 20))
    }

    func testAfterDhuhrAdhanOnJumuahWithSunriseAfterIsha() async throws {
        let date = friday(hour: 12, minute: 20)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 12, minute: 10))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -10)
    }

    func testBeforeDhuhrIqamaOnJumuahWithSunriseAfterIsha() async throws {
        let date = friday(hour: 12, minute: 30)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 13, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 60, lastAdhanTime: friday(hour: 12, minute: 10))
    }

    func testAfterJumuahKhutbaWithSunriseAfterIsha() async throws {
        let date = friday(hour: 13, minute: 45)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 13, minute: 30))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssert(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    func testBeforeAsrAdhanOnJumuahWithSunriseAfterIsha() async throws {
        let date = friday(hour: 14, minute: 15)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssert(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 10)
    }

    func testAfterAsrAdhanOnJumuahWithSunriseAfterIsha() async throws {
        let date = friday(hour: 14, minute: 40)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 14, minute: 25))
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: -15)
    }

    func testBeforeAsrIqamaOnJumuahWithSunriseAfterIsha() async throws {
        let date = friday(hour: 14, minute: 45)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 15, minute: 0))
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 15, lastAdhanTime: friday(hour: 14, minute: 25))
    }

    func testAfterAsrIqamaOnJumuahWithSunriseAfterIsha() async throws {
        let date = friday(hour: 15, minute: 15)
        let prayerTimer = try prayerTimer(at: date, sunriseAfterIsha: true)
        XCTAssertEqual(prayerTimer.type, .maghrib)
        XCTAssertEqual(prayerTimer.countdownDate, friday(hour: 16, minute: 50))
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertFalse(prayerTimer.isDangerZone)
        XCTAssertFalse(prayerTimer.isJumuah)
        XCTAssertNotNil(prayerTimer.localizeAt)
        assertCalculations(for: prayerTimer, minutes: 95)
    }
}

private extension PrayerTimerTests {
    func assertCalculations(for prayerTimer: PrayerTimer, minutes: Int, lastAdhanTime: Date? = nil) {
        XCTAssertEqual(prayerTimer.timeRemaining, Double(minutes) * 60)
        XCTAssertEqual(prayerTimer.timeRange.formatted(Date.ComponentsFormatStyle(style: .condensedAbbreviated, fields: [.minute])), "\(abs(minutes))min")
        switch prayerTimer.timerType {
        case .stopwatch:
            XCTAssertEqual(prayerTimer.progressRemaining, 1 + prayerTimer.timeRemaining / prayerTimer.timeDuration, accuracy: 0.0001)
        case .iqama:
            XCTAssertEqual(prayerTimer.progressRemaining, 1 - prayerTimer.date.timeIntervalSince(lastAdhanTime ?? .distantPast) / prayerTimer.timeDuration, accuracy: 0.0001)
        case .countdown:
            XCTAssertEqual(prayerTimer.progressRemaining, prayerTimer.timeRemaining / prayerTimer.timeDuration, accuracy: 0.0001)
        }
    }
}

// MARK: - Helpers

private extension PrayerTimerTests {
    func prayerTimer(at date: Date, isIqamaTimerEnabled: Bool = true, stopwatchMinutes: Int = 20, sunriseAfterIsha: Bool = false) throws -> PrayerTimer {
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
            jumuah: .time(hour: 13, minutes: 30)
        )

        return try XCTUnwrap(
            PrayerTimer(
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
                        Prayer.isha.rawValue: 20
                    ]
                ),
                sunriseAfterIsha: sunriseAfterIsha,
                timeZone: timeZone
            )
        )
    }

    func today(day: Int = 26, hour: Int, minute: Int) -> Date {
        Date(year: 2022, month: 11, day: day, hour: hour, minute: minute, timeZone: timeZone) ?? .now
    }

    func friday(hour: Int, minute: Int) -> Date {
        today(day: 25, hour: hour, minute: minute)
    }
}
