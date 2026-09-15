//
//  PrayerTimelineAdhanTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2022-04-02.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import XCTest
import CoreLocation
import PrayCore
import PrayServices
import ZamzamCore

final class PrayerTimelineAdhanTests: TestCase {
    private let preferences = Preferences(defaults: .test)
}

extension PrayerTimelineAdhanTests {
    // swiftlint:disable:next function_body_length
    func testToronto() async throws {
        // Given
        let expanded = PrayerManager.Expanded.intervals(0)

        preferences.preAdhanMinutes = PreAdhanMinutes(
            rawValue: [
                Prayer.fajr.rawValue: 34,
                Prayer.sunrise.rawValue: 27,
                Prayer.dhuhr.rawValue: 14,
                Prayer.asr.rawValue: 16,
                Prayer.maghrib.rawValue: 22,
                Prayer.isha.rawValue: 9
            ]
        )

        preferences.iqamaTimes = IqamaTimes(
            fajr: .time(hour: 6, minutes: 31),
            dhuhr: .minutes(12),
            asr: .time(hour: 16, minutes: 38),
            maghrib: .minutes(8),
            isha: nil,
            jumuah: .time(hour: 13, minutes: 30)
        )

        preferences.isIqamaTimerEnabled = true
        preferences.stopwatchMinutes = 18

        // When
        let (timeline, timeZone, date) = try await fetchPrayerDay(
            date: "2022/02/22 06:00",
            expanded: expanded,
            limit: 111,
            timeZoneIdentifier: "America/New_York",
            latitude: 43.651070,
            longitude: -79.347015,
            method: .northAmerica
        )

        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let dateFormatter = DateFormatter(dateFormat: "MMM dd, hh:mma")
        let timeFormatter = DateFormatter(dateFormat: "hh:mma")
        let dateTimeFormatter = DateFormatter(dateFormat: "yyyy/MM/dd HH:mm", timeZone: timeZone)

        // Then
        for (index, entry) in timeline.enumerated() {
            print(
                [
                    "\(index) |",
                    dateFormatter.string(for: entry.date),
                    "|",
                    try XCTUnwrap(entry.prayerDay.current(at: entry.date)).type.rawValue,
                    timeFormatter.string(for: try XCTUnwrap(entry.prayerDay.current(at: entry.date)).dateInterval.start)
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            )
        }

        func time(_ timeString: String, on dateString: String = "2022/02/22") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        XCTAssertEqual(timeline.count, 112)
        XCTAssertEqual(timeline[0, .fajr]?.dateInterval.start, time("05:46"))
        XCTAssertEqual(timeline[0, .sunrise]?.dateInterval.start, time("07:05"))
        XCTAssertEqual(timeline[0, .dhuhr]?.dateInterval.start, time("12:32"))
        XCTAssertEqual(timeline[0, .asr]?.dateInterval.start, time("15:29"))
        XCTAssertEqual(timeline[0, .maghrib]?.dateInterval.start, time("17:57"))
        XCTAssertEqual(timeline[0, .isha]?.dateInterval.start, time("19:16"))
        XCTAssertEqual(timeline[0, .midnight]?.dateInterval.start, time("23:51"))
        XCTAssertEqual(timeline[0, .lastThird]?.dateInterval.start, time("01:49", on: "2022/02/23"))

        try Prayer.allCases.filter(\.isEssential).forEach {
            let prayer = try XCTUnwrap(timeline[0, $0])

            let stopwatchTime = prayer.dateInterval.start + .minutes(preferences.stopwatchMinutes)
            if stopwatchTime > date {
                XCTAssert(timeline.contains { $0.date == stopwatchTime })
            }

            let preAdhanTime = prayer.dateInterval.start - .minutes(preferences.preAdhanMinutes[$0])
            if preAdhanTime > date {
                XCTAssert(timeline.contains { $0.date == preAdhanTime })
            }

            let iqamaTime = preferences.iqamaTimes[prayer, using: calendar]
            if let iqamaTime, iqamaTime > date {
                XCTAssert(timeline.contains { $0.date == iqamaTime })
            }
        }
    }
}

extension PrayerTimelineAdhanTests {
    // swiftlint:disable:next function_body_length
    func testLondon() async throws {
        // Given
        let expanded = PrayerManager.Expanded.intervals(0)

        preferences.preAdhanMinutes = PreAdhanMinutes(
            rawValue: [
                Prayer.fajr.rawValue: 34,
                Prayer.sunrise.rawValue: 27,
                Prayer.dhuhr.rawValue: 14,
                Prayer.asr.rawValue: 16,
                Prayer.maghrib.rawValue: 22,
                Prayer.isha.rawValue: 9
            ]
        )

        preferences.iqamaTimes = IqamaTimes(
            fajr: .time(hour: 6, minutes: 1),
            dhuhr: .minutes(12),
            asr: .time(hour: 16, minutes: 38),
            maghrib: .minutes(8),
            isha: nil,
            jumuah: .time(hour: 13, minutes: 30)
        )

        preferences.isIqamaTimerEnabled = false
        preferences.stopwatchMinutes = 18

        // When
        let (timeline, timeZone, date) = try await fetchPrayerDay(
            date: "2022/02/22 06:00",
            expanded: expanded,
            limit: 111,
            timeZoneIdentifier: "GMT",
            latitude: 51.509865,
            longitude: -0.118092,
            method: .london
        )

        let dateFormatter = DateFormatter(dateFormat: "MMM dd, h:mma", timeZone: timeZone)
        let timeFormatter = DateFormatter(dateFormat: "h:mma", timeZone: timeZone)
        let dateTimeFormatter = DateFormatter(dateFormat: "yyyy/MM/dd HH:mm", timeZone: timeZone)

        // Then
        for (index, entry) in timeline.enumerated() {
            print(
                [
                    "\(index) |",
                    dateFormatter.string(for: entry.date),
                    "|",
                    try XCTUnwrap(entry.prayerDay.current(at: entry.date)).type.rawValue,
                    timeFormatter.string(for: try XCTUnwrap(entry.prayerDay.current(at: entry.date)).dateInterval.start)
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            )
        }

        func time(_ timeString: String, on dateString: String = "2022/02/22") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        XCTAssertEqual(timeline.count, 112)
        XCTAssertEqual(timeline[0, .fajr]?.dateInterval.start, time("05:21"))
        XCTAssertEqual(timeline[0, .sunrise]?.dateInterval.start, time("06:58"))
        XCTAssertEqual(timeline[0, .dhuhr]?.dateInterval.start, time("12:19"))
        XCTAssertEqual(timeline[0, .asr]?.dateInterval.start, time("14:55"))
        XCTAssertEqual(timeline[0, .maghrib]?.dateInterval.start, time("17:31"))
        XCTAssertEqual(timeline[0, .isha]?.dateInterval.start, time("18:59"))
        XCTAssertEqual(timeline[0, .midnight]?.dateInterval.start, time("23:25"))
        XCTAssertEqual(timeline[0, .lastThird]?.dateInterval.start, time("01:23", on: "2022/02/23"))

        try Prayer.allCases.filter(\.isEssential).forEach {
            let prayer = try XCTUnwrap(timeline[0, $0])

            let stopwatchTime = prayer.dateInterval.start + .minutes(preferences.stopwatchMinutes)
            if stopwatchTime > date {
                XCTAssert(timeline.contains { $0.date == stopwatchTime })
            }

            let preAdhanTime = prayer.dateInterval.start - .minutes(preferences.preAdhanMinutes[$0])
            if preAdhanTime > date {
                XCTAssert(timeline.contains { $0.date == preAdhanTime })
            }
        }
    }
}

extension PrayerTimelineAdhanTests {
    // swiftlint:disable:next function_body_length
    func testFinalHour() async throws {
        // Given
        let expanded = PrayerManager.Expanded.finalHour

        preferences.preAdhanMinutes = PreAdhanMinutes(
            rawValue: [
                Prayer.fajr.rawValue: 34,
                Prayer.sunrise.rawValue: 27,
                Prayer.dhuhr.rawValue: 14,
                Prayer.asr.rawValue: 16,
                Prayer.maghrib.rawValue: 22,
                Prayer.isha.rawValue: 9
            ]
        )

        // When
        let (timeline, timeZone, date) = try await fetchPrayerDay(
            date: "2022/04/01 06:00",
            expanded: expanded,
            limit: 30,
            timeZoneIdentifier: "America/New_York",
            latitude: 43.651070,
            longitude: -79.347015,
            method: .northAmerica
        )

        let dateFormatter = DateFormatter(dateFormat: "MMM dd, hh:mma")
        let timeFormatter = DateFormatter(dateFormat: "hh:mma")
        let dateTimeFormatter = DateFormatter(dateFormat: "yyyy/MM/dd HH:mm", timeZone: timeZone)

        // Then
        for (index, entry) in timeline.enumerated() {
            print(
                [
                    "\(index) |",
                    dateFormatter.string(for: entry.date),
                    "|",
                    try XCTUnwrap(entry.prayerDay.current(at: entry.date)).type.rawValue,
                    timeFormatter.string(for: try XCTUnwrap(entry.prayerDay.current(at: entry.date)).dateInterval.start)
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            )
        }

        func time(_ timeString: String, on dateString: String = "2022/04/01") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        XCTAssertEqual(timeline.count, 31)
        XCTAssertEqual(timeline[0, .fajr]?.dateInterval.start, time("05:38"))
        XCTAssertEqual(timeline[0, .sunrise]?.dateInterval.start, time("06:59"))
        XCTAssertEqual(timeline[0, .dhuhr]?.dateInterval.start, time("13:22"))
        XCTAssertEqual(timeline[0, .asr]?.dateInterval.start, time("16:57"))
        XCTAssertEqual(timeline[0, .maghrib]?.dateInterval.start, time("19:44"))
        XCTAssertEqual(timeline[0, .isha]?.dateInterval.start, time("21:06"))
        XCTAssertEqual(timeline[0, .midnight]?.dateInterval.start, time("00:40", on: "2022/04/02"))
        XCTAssertEqual(timeline[0, .lastThird]?.dateInterval.start, time("02:19", on: "2022/04/02"))

        try Prayer.allCases.filter(\.isEssential).forEach {
            let prayer = try XCTUnwrap(timeline[0, $0])

            let finalHour = prayer.dateInterval.start - .hours(1)
            if finalHour > date {
                XCTAssert(timeline.contains { $0.date == finalHour })
            }

            let preAdhanTime = prayer.dateInterval.start - .minutes(preferences.preAdhanMinutes[$0])
            if preAdhanTime > date {
                XCTAssert(timeline.contains { $0.date == preAdhanTime })
            }
        }
    }
}

// MARK: - Helpers

private extension PrayerTimelineAdhanTests {
    func fetchPrayerDay(
        date dateString: String,
        expanded: PrayerManager.Expanded,
        limit: Int,
        timeZoneIdentifier: String,
        latitude: Double,
        longitude: Double,
        method: CalculationMethod,
        jurisprudence: Madhab = .standard,
        elevation: ElevationRule? = nil,
        filter: PrayerFilter = .all
    ) async throws -> ([PrayerTimer], TimeZone, Date) {
        let coordinates = Coordinates(
            latitude: latitude,
            longitude: longitude
        )

        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { throw PrayError.invalidTimes }
        let dateTimeFormatter = DateFormatter(dateFormat: "yyyy/MM/dd HH:mm", timeZone: timeZone)
        guard let date = dateTimeFormatter.date(from: dateString) else { throw PrayError.invalidTimes }

        let request = PrayerAPI.Request(
            coordinates: coordinates,
            timeZone: timeZone,
            method: method,
            jurisprudence: jurisprudence,
            elevation: elevation,
            fajrDegrees: nil,
            maghribDegrees: nil,
            ishaDegrees: nil,
            adjustments: nil,
            filter: filter
        )

        return (try await prayerManager.fetch(from: date, expanded: expanded, limit: limit, with: request), timeZone, date)
    }
}

private extension Array where Element == PrayerTimer {
    subscript(_ index: Int, _ prayer: Prayer) -> PrayerTime? {
        self[index].prayerDay.times[prayer]
    }
}
