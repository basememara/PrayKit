//
//  PrayerTimelineAdhanTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2022-04-02.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import Testing
import CoreLocation
import PrayCore
import PrayServices
import ZamzamCore

struct PrayerTimelineAdhanTests {
    private let preferences: Preferences
    private let prayerManager: PrayerManager

    init() {
        let fixture = PrayTestFixture()
        preferences = fixture.preferences
        prayerManager = fixture.prayerManager
    }
}

extension PrayerTimelineAdhanTests {
    // swiftlint:disable:next function_body_length
    @Test
    func toronto() async throws {
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
                    try #require(entry.prayerDay.current(at: entry.date)).type.rawValue,
                    timeFormatter.string(for: try #require(entry.prayerDay.current(at: entry.date)).dateInterval.start)
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            )
        }

        func time(_ timeString: String, on dateString: String = "2022/02/22") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        #expect(timeline.count == 112)
        #expect(timeline[0, .fajr]?.dateInterval.start == time("05:46"))
        #expect(timeline[0, .sunrise]?.dateInterval.start == time("07:05"))
        #expect(timeline[0, .dhuhr]?.dateInterval.start == time("12:32"))
        #expect(timeline[0, .asr]?.dateInterval.start == time("15:29"))
        #expect(timeline[0, .maghrib]?.dateInterval.start == time("17:57"))
        #expect(timeline[0, .isha]?.dateInterval.start == time("19:16"))
        #expect(timeline[0, .midnight]?.dateInterval.start == time("23:51"))
        #expect(timeline[0, .lastThird]?.dateInterval.start == time("01:49", on: "2022/02/23"))

        try Prayer.allCases.filter(\.isEssential).forEach {
            let prayer = try #require(timeline[0, $0])

            let stopwatchTime = prayer.dateInterval.start + .minutes(preferences.stopwatchMinutes)
            if stopwatchTime > date {
                #expect(timeline.contains { $0.date == stopwatchTime })
            }

            let preAdhanTime = prayer.dateInterval.start - .minutes(preferences.preAdhanMinutes[$0])
            if preAdhanTime > date {
                #expect(timeline.contains { $0.date == preAdhanTime })
            }

            let iqamaTime = preferences.iqamaTimes[prayer, using: calendar]
            if let iqamaTime, iqamaTime > date {
                #expect(timeline.contains { $0.date == iqamaTime })
            }
        }
    }
}

extension PrayerTimelineAdhanTests {
    // swiftlint:disable:next function_body_length
    @Test
    func london() async throws {
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
                    try #require(entry.prayerDay.current(at: entry.date)).type.rawValue,
                    timeFormatter.string(for: try #require(entry.prayerDay.current(at: entry.date)).dateInterval.start)
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            )
        }

        func time(_ timeString: String, on dateString: String = "2022/02/22") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        #expect(timeline.count == 112)
        #expect(timeline[0, .fajr]?.dateInterval.start == time("05:21"))
        #expect(timeline[0, .sunrise]?.dateInterval.start == time("06:58"))
        #expect(timeline[0, .dhuhr]?.dateInterval.start == time("12:19"))
        #expect(timeline[0, .asr]?.dateInterval.start == time("14:55"))
        #expect(timeline[0, .maghrib]?.dateInterval.start == time("17:31"))
        #expect(timeline[0, .isha]?.dateInterval.start == time("18:59"))
        #expect(timeline[0, .midnight]?.dateInterval.start == time("23:25"))
        #expect(timeline[0, .lastThird]?.dateInterval.start == time("01:23", on: "2022/02/23"))

        try Prayer.allCases.filter(\.isEssential).forEach {
            let prayer = try #require(timeline[0, $0])

            let stopwatchTime = prayer.dateInterval.start + .minutes(preferences.stopwatchMinutes)
            if stopwatchTime > date {
                #expect(timeline.contains { $0.date == stopwatchTime })
            }

            let preAdhanTime = prayer.dateInterval.start - .minutes(preferences.preAdhanMinutes[$0])
            if preAdhanTime > date {
                #expect(timeline.contains { $0.date == preAdhanTime })
            }
        }
    }
}

extension PrayerTimelineAdhanTests {
    // swiftlint:disable:next function_body_length
    @Test
    func finalHour() async throws {
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
                    try #require(entry.prayerDay.current(at: entry.date)).type.rawValue,
                    timeFormatter.string(for: try #require(entry.prayerDay.current(at: entry.date)).dateInterval.start)
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            )
        }

        func time(_ timeString: String, on dateString: String = "2022/04/01") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        #expect(timeline.count == 31)
        #expect(timeline[0, .fajr]?.dateInterval.start == time("05:38"))
        #expect(timeline[0, .sunrise]?.dateInterval.start == time("06:59"))
        #expect(timeline[0, .dhuhr]?.dateInterval.start == time("13:22"))
        #expect(timeline[0, .asr]?.dateInterval.start == time("16:57"))
        #expect(timeline[0, .maghrib]?.dateInterval.start == time("19:44"))
        #expect(timeline[0, .isha]?.dateInterval.start == time("21:06"))
        #expect(timeline[0, .midnight]?.dateInterval.start == time("00:40", on: "2022/04/02"))
        #expect(timeline[0, .lastThird]?.dateInterval.start == time("02:19", on: "2022/04/02"))

        try Prayer.allCases.filter(\.isEssential).forEach {
            let prayer = try #require(timeline[0, $0])

            let finalHour = prayer.dateInterval.start - .hours(1)
            if finalHour > date {
                #expect(timeline.contains { $0.date == finalHour })
            }

            let preAdhanTime = prayer.dateInterval.start - .minutes(preferences.preAdhanMinutes[$0])
            if preAdhanTime > date {
                #expect(timeline.contains { $0.date == preAdhanTime })
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
