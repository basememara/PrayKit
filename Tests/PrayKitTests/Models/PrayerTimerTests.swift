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

final class PrayerTimerTests: XCTestCase {
    let timeZone = TimeZone(identifier: "America/New_York") ?? .current
    lazy var calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
}

extension PrayerTimerTests {
    func testBeforeAdhan() async throws {
        let date = today(hour: 11, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertEqual(prayerTimer.date, today(hour: 12, minute: 10))
        XCTAssertNotNil(prayerTimer.localizeAt)
    }

    func testAfterAdhanBeforeStopwatch() async throws {
        let date = today(hour: 12, minute: 19)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertEqual(prayerTimer.date, today(hour: 12, minute: 10))
        XCTAssertNotNil(prayerTimer.localizeAt)
    }

    func testAfterStopwatchBeforeIqama() async throws {
        let date = today(hour: 12, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertEqual(prayerTimer.date, today(hour: 12, minute: 45))
        XCTAssertNotNil(prayerTimer.localizeAt)
    }

    func testAfterIqama() async throws {
        let date = today(hour: 13, minute: 0)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertEqual(prayerTimer.date, today(hour: 14, minute: 26))
        XCTAssertNotNil(prayerTimer.localizeAt)
    }

    func testLongAfterIqama() async throws {
        let date = today(hour: 13, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertEqual(prayerTimer.date, today(hour: 14, minute: 26))
        XCTAssertNotNil(prayerTimer.localizeAt)
    }
}

extension PrayerTimerTests {
    func testBeforeAdhanJumuah() async throws {
        let date = friday(hour: 11, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertEqual(prayerTimer.date, friday(hour: 13, minute: 30))
        XCTAssertNotNil(prayerTimer.localizeAt)
    }

    func testAfterAdhanBeforeStopwatchJumuah() async throws {
        let date = friday(hour: 12, minute: 19)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertEqual(prayerTimer.date, friday(hour: 12, minute: 10))
        XCTAssertNil(prayerTimer.localizeAt)
    }

    func testAfterStopwatchBeforeIqamaJumuah() async throws {
        let date = friday(hour: 12, minute: 40)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.timerType, .iqama)
        XCTAssertEqual(prayerTimer.date, friday(hour: 13, minute: 30))
        XCTAssertNotNil(prayerTimer.localizeAt)
    }

    func testShortlyAfterIqamaJumuah() async throws {
        let date = friday(hour: 13, minute: 45)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .dhuhr)
        XCTAssertEqual(prayerTimer.timerType, .stopwatch)
        XCTAssertEqual(prayerTimer.date, friday(hour: 13, minute: 30))
        XCTAssertNotNil(prayerTimer.localizeAt)
    }

    func testAfterIqamaJumuah() async throws {
        let date = friday(hour: 14, minute: 0)
        let prayerTimer = try prayerTimer(at: date)
        XCTAssertEqual(prayerTimer.type, .asr)
        XCTAssertEqual(prayerTimer.timerType, .countdown)
        XCTAssertEqual(prayerTimer.date, friday(hour: 14, minute: 26))
        XCTAssertNotNil(prayerTimer.localizeAt)
    }
}

// MARK: - Helpers

private extension PrayerTimerTests {
    func prayerTimer(at date: Date, isIqamaTimerEnabled: Bool = true, stopwatchMinutes: Int = 20) throws -> PrayerTimer {
        let prayerDay = PrayerDay.mock(
            at: date,
            times: [(5, 52), (7, 23), (12, 10), (14, 26), (17, 32), (18, 15), (0, 28), (1, 46)],
            calendar: calendar,
            filter: .essential
        )

        let iqamaTimes = IqamaTimes(
            fajr: .time(hour: 6, minutes: 1),
            dhuhr: .time(hour: 12, minutes: 45),
            asr: .time(hour: 16, minutes: 38),
            maghrib: .minutes(8),
            isha: .time(hour: 23, minutes: 6),
            jumuah: .time(hour: 13, minutes: 30)
        )

        return PrayerTimer(
            currentPrayer: try XCTUnwrap(prayerDay.current(at: date)),
            nextPrayer: try XCTUnwrap(prayerDay.next(at: date)),
            iqamaTimes: iqamaTimes,
            isIqamaTimerEnabled: isIqamaTimerEnabled,
            stopwatchMinutes: stopwatchMinutes,
            preAdhanMinutes: 20,
            calendar: calendar,
            date: date
        )
    }

    func today(day: Int = 26, hour: Int, minute: Int) -> Date {
        Date(year: 2022, month: 11, day: day, hour: hour, minute: minute, timeZone: timeZone) ?? .now
    }

    func friday(hour: Int, minute: Int) -> Date {
        today(day: 25, hour: hour, minute: minute)
    }
}
