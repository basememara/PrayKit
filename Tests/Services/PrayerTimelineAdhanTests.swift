//
//  PrayerTimelineAdhanTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2022-04-02.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import CoreLocation
import Foundation
import PrayCore
import PrayServices
import Testing
import ZamzamCore

struct PrayerTimelineAdhanTests {
    private let prayerManager = PrayTestFixture().prayerManager
}

extension PrayerTimelineAdhanTests {
    @Test
    func toronto() async throws {
        // Given
        let expanded = PrayerManager.Expanded.intervals(0)
        var settings = Settings()

        settings.preAdhanMinutes = PreAdhanMinutes(
            rawValue: [
                Prayer.fajr.rawValue: 34,
                Prayer.sunrise.rawValue: 27,
                Prayer.dhuhr.rawValue: 14,
                Prayer.asr.rawValue: 16,
                Prayer.maghrib.rawValue: 22,
                Prayer.isha.rawValue: 9
            ]
        )

        settings.iqamaTimes = IqamaTimes(
            fajr: .time(hour: 6, minutes: 31),
            dhuhr: .minutes(12),
            asr: .time(hour: 16, minutes: 38),
            maghrib: .minutes(8),
            isha: nil,
            jumuah: .time(hour: 13, minutes: 30)
        )

        settings.isIqamaTimerEnabled = true
        settings.stopwatchMinutes = 18

        // When
        let (timeline, timeZone, date) = try await fetchPrayerDay(
            settings: settings,
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
                .compactMap(\.self)
                .joined(separator: " ")
            )
        }

        func time(_ timeString: String, on dateString: String = "2022/02/22") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        #expect(timeline.count == 113)
        #expect(timeline[dayOf: date, .fajr]?.dateInterval.start == time("05:46"))
        #expect(timeline[dayOf: date, .sunrise]?.dateInterval.start == time("07:05"))
        #expect(timeline[dayOf: date, .dhuhr]?.dateInterval.start == time("12:32"))
        #expect(timeline[dayOf: date, .asr]?.dateInterval.start == time("15:29"))
        #expect(timeline[dayOf: date, .maghrib]?.dateInterval.start == time("17:57"))
        #expect(timeline[dayOf: date, .isha]?.dateInterval.start == time("19:16"))
        #expect(timeline[dayOf: date, .midnight]?.dateInterval.start == time("23:51"))
        #expect(timeline[dayOf: date, .lastThird]?.dateInterval.start == time("01:49", on: "2022/02/23"))

        try Prayer.allCases.filter(\.isEssential).forEach {
            let prayer = try #require(timeline[dayOf: date, $0])

            let stopwatchTime = prayer.dateInterval.start + .minutes(settings.stopwatchMinutes)
            if stopwatchTime > date {
                #expect(timeline.contains { $0.date == stopwatchTime })
            }

            let preAdhanTime = prayer.dateInterval.start - .minutes(settings.preAdhanMinutes[$0])
            if preAdhanTime > date {
                #expect(timeline.contains { $0.date == preAdhanTime })
            }

            let iqamaTime = settings.iqamaTimes[prayer, using: calendar]
            if let iqamaTime, iqamaTime > date {
                #expect(timeline.contains { $0.date == iqamaTime })
            }
        }
    }
}

extension PrayerTimelineAdhanTests {
    @Test
    func london() async throws {
        // Given
        let expanded = PrayerManager.Expanded.intervals(0)
        var settings = Settings()

        settings.preAdhanMinutes = PreAdhanMinutes(
            rawValue: [
                Prayer.fajr.rawValue: 34,
                Prayer.sunrise.rawValue: 27,
                Prayer.dhuhr.rawValue: 14,
                Prayer.asr.rawValue: 16,
                Prayer.maghrib.rawValue: 22,
                Prayer.isha.rawValue: 9
            ]
        )

        settings.iqamaTimes = IqamaTimes(
            fajr: .time(hour: 6, minutes: 1),
            dhuhr: .minutes(12),
            asr: .time(hour: 16, minutes: 38),
            maghrib: .minutes(8),
            isha: nil,
            jumuah: .time(hour: 13, minutes: 30)
        )

        settings.isIqamaTimerEnabled = false
        settings.stopwatchMinutes = 18

        // When
        let (timeline, timeZone, date) = try await fetchPrayerDay(
            settings: settings,
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
                .compactMap(\.self)
                .joined(separator: " ")
            )
        }

        func time(_ timeString: String, on dateString: String = "2022/02/22") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        #expect(timeline.count == 112)
        #expect(timeline[dayOf: date, .fajr]?.dateInterval.start == time("05:21"))
        #expect(timeline[dayOf: date, .sunrise]?.dateInterval.start == time("06:58"))
        #expect(timeline[dayOf: date, .dhuhr]?.dateInterval.start == time("12:19"))
        #expect(timeline[dayOf: date, .asr]?.dateInterval.start == time("14:55"))
        #expect(timeline[dayOf: date, .maghrib]?.dateInterval.start == time("17:31"))
        #expect(timeline[dayOf: date, .isha]?.dateInterval.start == time("18:59"))
        #expect(timeline[dayOf: date, .midnight]?.dateInterval.start == time("23:25"))
        #expect(timeline[dayOf: date, .lastThird]?.dateInterval.start == time("01:23", on: "2022/02/23"))

        try Prayer.allCases.filter(\.isEssential).forEach {
            let prayer = try #require(timeline[dayOf: date, $0])

            let stopwatchTime = prayer.dateInterval.start + .minutes(settings.stopwatchMinutes)
            if stopwatchTime > date {
                #expect(timeline.contains { $0.date == stopwatchTime })
            }

            let preAdhanTime = prayer.dateInterval.start - .minutes(settings.preAdhanMinutes[$0])
            if preAdhanTime > date {
                #expect(timeline.contains { $0.date == preAdhanTime })
            }
        }
    }
}

extension PrayerTimelineAdhanTests {
    @Test
    func finalHour() async throws {
        // Given
        let expanded = PrayerManager.Expanded.finalHour
        var settings = Settings()

        settings.preAdhanMinutes = PreAdhanMinutes(
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
            settings: settings,
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
                .compactMap(\.self)
                .joined(separator: " ")
            )
        }

        func time(_ timeString: String, on dateString: String = "2022/04/01") -> Date? {
            dateTimeFormatter.date(from: "\(dateString) \(timeString)")
        }

        #expect(timeline.count == 33)
        #expect(timeline[dayOf: date, .fajr]?.dateInterval.start == time("05:38"))
        #expect(timeline[dayOf: date, .sunrise]?.dateInterval.start == time("06:59"))
        #expect(timeline[dayOf: date, .dhuhr]?.dateInterval.start == time("13:22"))
        #expect(timeline[dayOf: date, .asr]?.dateInterval.start == time("16:57"))
        #expect(timeline[dayOf: date, .maghrib]?.dateInterval.start == time("19:44"))
        #expect(timeline[dayOf: date, .isha]?.dateInterval.start == time("21:06"))
        #expect(timeline[dayOf: date, .midnight]?.dateInterval.start == time("00:40", on: "2022/04/02"))
        #expect(timeline[dayOf: date, .lastThird]?.dateInterval.start == time("02:19", on: "2022/04/02"))

        try Prayer.allCases.filter(\.isEssential).forEach {
            let prayer = try #require(timeline[dayOf: date, $0])

            let finalHour = prayer.dateInterval.start - .hours(1)
            if finalHour > date {
                #expect(timeline.contains { $0.date == finalHour })
            }

            let preAdhanTime = prayer.dateInterval.start - .minutes(settings.preAdhanMinutes[$0])
            if preAdhanTime > date {
                #expect(timeline.contains { $0.date == preAdhanTime })
            }
        }
    }
}

extension PrayerTimelineAdhanTests {
    @Test
    func hourlyCountsTheLastHourDownInFiveMinuteSteps() async throws {
        let (timeline, _, date) = try await fetchPrayerDay(
            settings: Settings(),
            date: "2022/04/01 06:00",
            expanded: .hourly,
            limit: 200,
            timeZoneIdentifier: "America/New_York",
            latitude: 43.651070,
            longitude: -79.347015,
            method: .northAmerica
        )

        let dates = Set(timeline.map(\.date))
        try [Prayer.dhuhr, .asr, .maghrib, .isha].forEach {
            let start = try #require(timeline[dayOf: date, $0]).dateInterval.start
            let steps = stride(from: 60, to: 0, by: -5).map { start - .minutes($0) }
            #expect(steps.allSatisfy(dates.contains), "\($0) is missing a five-minute step in its last hour")
        }
    }

    /// A face too small for a live timer shows the hours left to the nearest hour, so a step on each half hour before the
    /// prayer turns it as it changes; steps counted from the prayer before left "2h" up until well past an hour and a half.
    @Test
    func hourlyStepsOnEachHalfHourBeforeThePrayer() async throws {
        let (timeline, _, date) = try await fetchPrayerDay(
            settings: Settings(),
            date: "2022/04/01 06:00",
            expanded: .hourly,
            limit: 200,
            timeZoneIdentifier: "America/New_York",
            latitude: 43.651070,
            longitude: -79.347015,
            method: .northAmerica
        )

        let dates = Set(timeline.map(\.date))
        try zip([Prayer.sunrise, .dhuhr, .asr, .maghrib], [Prayer.dhuhr, .asr, .maghrib, .isha]).forEach { previous, prayer in
            let windowStart = try #require(timeline[dayOf: date, previous]).dateInterval.start
            let start = try #require(timeline[dayOf: date, prayer]).dateInterval.start
            let steps = (1...12).map { start - .hours($0) - .minutes(30) }.filter { $0 > max(windowStart, date) }
            #expect(steps.allSatisfy(dates.contains), "\(prayer) is missing a step on a half hour before it")
        }
    }
}

extension PrayerTimelineAdhanTests {
    /// A face shows a countdown until the entry at its prayer replaces it; a timeline cut short of that entry left the
    /// watch's complications frozen at zero (28.1.0, five-minute steps filling the widget's 15-entry limit).
    @Test
    func aCappedTimelineRunsOnToTheMomentItsCountdownsReach() async throws {
        let (timeline, _, date) = try await fetchPrayerDay(
            settings: Settings(),
            date: "2022/04/01 07:30",
            expanded: .hourly,
            limit: 15,
            timeZoneIdentifier: "America/New_York",
            latitude: 43.651070,
            longitude: -79.347015,
            method: .northAmerica
        )

        let last = try #require(timeline.last)
        let dhuhr = try #require(timeline[dayOf: date, .dhuhr]).dateInterval.start

        #expect(timeline.count >= 15)
        #expect(timeline.contains { $0.date == dhuhr })
        #expect(timeline.dropLast().allSatisfy { $0.countdownDate <= last.date })
    }
}

// MARK: - Helpers

private extension PrayerTimelineAdhanTests {
    func fetchPrayerDay(
        settings: Settings,
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

        let timeline = try await prayerManager.fetch(
            from: date,
            expanded: expanded,
            limit: limit,
            with: request,
            settings: settings,
            timeZone: timeZone
        )

        return (timeline, timeZone, date)
    }
}

private extension Array where Element == PrayerTimer {
    /// A prayer of the day holding the moment, which the timeline's entries carry from that day's Fajr.
    subscript(dayOf date: Date, _ prayer: Prayer) -> PrayerTime? {
        first { $0.prayerDay.contains(date) }?.prayerDay.times[prayer]
    }
}
