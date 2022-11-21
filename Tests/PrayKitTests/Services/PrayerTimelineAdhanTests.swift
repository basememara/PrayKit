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

        preferences.iqamaTimerMinutes = 18

        // When
        let (timeline, timeZone) = try await fetchPrayerDay(
            date: "2022/02/22 06:00",
            expanded: expanded,
            limit: 111,
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

        func time(_ timeString: String, on dateString: String = "2022/02/22") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        XCTAssertEqual(timeline.count, 111)
        XCTAssertEqual(timeline[0, .fajr]?.dateInterval.start, time("05:46"))
        XCTAssertEqual(timeline[0, .sunrise]?.dateInterval.start, time("07:05"))
        XCTAssertEqual(timeline[0, .dhuhr]?.dateInterval.start, time("12:32"))
        XCTAssertEqual(timeline[0, .asr]?.dateInterval.start, time("15:29"))
        XCTAssertEqual(timeline[0, .maghrib]?.dateInterval.start, time("17:57"))
        XCTAssertEqual(timeline[0, .isha]?.dateInterval.start, time("19:16"))
        XCTAssertEqual(timeline[0, .midnight]?.dateInterval.start, time("23:51"))
        XCTAssertEqual(timeline[0, .lastThird]?.dateInterval.start, time("01:49", on: "2022/02/23"))

        func test(for prayer: Prayer, index: Int) throws {
            let prayerTime = try XCTUnwrap(timeline[index, prayer])
            let date = prayerTime.dateInterval.start
            if preferences.preAdhanMinutes[prayer] != 0 {
                XCTAssertEqual(timeline[index].date, date - .minutes(preferences.preAdhanMinutes[prayer]))
            }
            XCTAssertEqual(timeline[index + 1].date, date)
            if preferences.iqamaTimerMinutes != 0 {
                XCTAssertEqual(timeline[index + 2].date, date + .minutes(preferences.iqamaTimerMinutes))
            }
        }

        try test(for: .fajr, index: 0)
        try test(for: .sunrise, index: 3)
        try test(for: .dhuhr, index: 6)
        try test(for: .asr, index: 9)
        try test(for: .maghrib, index: 12)
        try test(for: .isha, index: 15)
        try test(for: .fajr, index: 18)
        try test(for: .sunrise, index: 21)
        try test(for: .dhuhr, index: 24)
        try test(for: .asr, index: 27)
        try test(for: .maghrib, index: 30)
        try test(for: .isha, index: 33)
        try test(for: .fajr, index: 36)
        try test(for: .sunrise, index: 39)
        try test(for: .dhuhr, index: 42)
        try test(for: .asr, index: 45)
        try test(for: .maghrib, index: 48)
        try test(for: .isha, index: 51)
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

        preferences.iqamaTimerMinutes = 18

        // When
        let (timeline, timeZone) = try await fetchPrayerDay(
            date: "2022/02/22 06:00",
            expanded: expanded,
            limit: 111,
            timeZoneIdentifier: "GMT",
            latitude: 51.509865,
            longitude: -0.118092,
            method: .london
        )

        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
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

        XCTAssertEqual(timeline.count, 111)
        XCTAssertEqual(timeline[0, .fajr]?.dateInterval.start, time("05:21"))
        XCTAssertEqual(timeline[0, .sunrise]?.dateInterval.start, time("06:58"))
        XCTAssertEqual(timeline[0, .dhuhr]?.dateInterval.start, time("12:19"))
        XCTAssertEqual(timeline[0, .asr]?.dateInterval.start, time("14:55"))
        XCTAssertEqual(timeline[0, .maghrib]?.dateInterval.start, time("17:31"))
        XCTAssertEqual(timeline[0, .isha]?.dateInterval.start, time("18:59"))
        XCTAssertEqual(timeline[0, .midnight]?.dateInterval.start, time("23:25"))
        XCTAssertEqual(timeline[0, .lastThird]?.dateInterval.start, time("01:23", on: "2022/02/23"))

        func test(for prayer: Prayer, index: Int) throws {
            let prayerTime = try XCTUnwrap(timeline[index, prayer])
            let date = prayerTime.dateInterval.start
            if preferences.preAdhanMinutes[prayer] != 0 {
                XCTAssertEqual(timeline[index].date, date - .minutes(preferences.preAdhanMinutes[prayer]))
            }
            XCTAssertEqual(timeline[index + 1].date, date)
            if preferences.iqamaTimerMinutes != 0 {
                XCTAssertEqual(timeline[index + 2].date, date + .minutes(preferences.iqamaTimerMinutes))
            }
        }

        try test(for: .fajr, index: 0)
        try test(for: .sunrise, index: 3)
        try test(for: .dhuhr, index: 6)
        try test(for: .asr, index: 9)
        try test(for: .maghrib, index: 12)
        try test(for: .isha, index: 15)
        try test(for: .fajr, index: 18)
        try test(for: .sunrise, index: 21)
        try test(for: .dhuhr, index: 24)
        try test(for: .asr, index: 27)
        try test(for: .maghrib, index: 30)
        try test(for: .isha, index: 33)
        try test(for: .fajr, index: 36)
        try test(for: .sunrise, index: 39)
        try test(for: .dhuhr, index: 42)
        try test(for: .asr, index: 45)
        try test(for: .maghrib, index: 48)
        try test(for: .isha, index: 51)
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
        let (timeline, timeZone) = try await fetchPrayerDay(
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

        XCTAssertEqual(timeline.count, 30)
        XCTAssertEqual(timeline[0, .fajr]?.dateInterval.start, time("05:38"))
        XCTAssertEqual(timeline[0, .sunrise]?.dateInterval.start, time("06:59"))
        XCTAssertEqual(timeline[0, .dhuhr]?.dateInterval.start, time("13:22"))
        XCTAssertEqual(timeline[0, .asr]?.dateInterval.start, time("16:57"))
        XCTAssertEqual(timeline[0, .maghrib]?.dateInterval.start, time("19:44"))
        XCTAssertEqual(timeline[0, .isha]?.dateInterval.start, time("21:06"))
        XCTAssertEqual(timeline[0, .midnight]?.dateInterval.start, time("00:40", on: "2022/04/02"))
        XCTAssertEqual(timeline[0, .lastThird]?.dateInterval.start, time("02:19", on: "2022/04/02"))

        func test(for prayer: Prayer, index: Int) throws {
            let date = try XCTUnwrap(timeline[index, prayer]?.dateInterval.start)
            let date2 = prayer == .isha
                ? try XCTUnwrap(timeline[index + 2, .fajr]?.dateInterval.start)
                : try XCTUnwrap(timeline[index, prayer.next() ?? .fajr]?.dateInterval.start)
            if let safeDate = timeline[safe: index - 1]?.date {
                XCTAssertEqual(safeDate, date - .hours(1))
            }
            XCTAssertEqual(timeline[index].date, date)
            XCTAssertEqual(timeline[index + 1].date, date2 - .hours(1))
            if let safeDate = timeline[safe: index + 2]?.date {
                XCTAssertEqual(safeDate, date2)
            }
        }

        try test(for: .fajr, index: 0)
        try test(for: .sunrise, index: 2)
        try test(for: .dhuhr, index: 4)
        try test(for: .asr, index: 6)
        try test(for: .maghrib, index: 8)
        try test(for: .isha, index: 10)
        try test(for: .fajr, index: 12)
        try test(for: .sunrise, index: 14)
        try test(for: .dhuhr, index: 16)
        try test(for: .asr, index: 18)
        try test(for: .maghrib, index: 20)
        try test(for: .isha, index: 22)
        try test(for: .fajr, index: 24)
        try test(for: .sunrise, index: 26)
        try test(for: .dhuhr, index: 28)
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
    ) async throws -> ([PrayerAPI.TimelineEntry], TimeZone) {
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

        return (try await prayerManager.fetch(from: date, expanded: expanded, limit: limit, with: request), timeZone)
    }
}

private extension Array where Element == PrayerAPI.TimelineEntry {
    subscript(_ index: Int, _ prayer: Prayer) -> PrayerTime? {
        self[index].prayerDay.times[prayer]
    }
}
