//
//  PrayerDayAdhanTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import XCTest
import PrayCore

final class PrayerDayAdhanTests: TestCase {}

extension PrayerDayAdhanTests {
    func testToronto() async throws {
        // Given
        let (prayerDay, timeZone) = try await fetchPrayerDay(
            for: "2021/01/02",
            timeZoneIdentifier: "America/New_York",
            latitude: 43.651070,
            longitude: -79.347015,
            method: .northAmerica
        )

        // Then
        XCTAssertEqual(prayerDay.times[.fajr]?.dateInterval.start, Date(year: 2021, month: 1, day: 2, hour: 6, minute: 25, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.sunrise]?.dateInterval.start, Date(year: 2021, month: 1, day: 2, hour: 7, minute: 51, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.dhuhr]?.dateInterval.start, Date(year: 2021, month: 1, day: 2, hour: 12, minute: 23, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.asr]?.dateInterval.start, Date(year: 2021, month: 1, day: 2, hour: 14, minute: 35, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.maghrib]?.dateInterval.start, Date(year: 2021, month: 1, day: 2, hour: 16, minute: 52, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.isha]?.dateInterval.start, Date(year: 2021, month: 1, day: 2, hour: 18, minute: 19, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.midnight]?.dateInterval.start, Date(year: 2021, month: 1, day: 2, hour: 23, minute: 39, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.lastThird]?.dateInterval.start, Date(year: 2021, month: 1, day: 3, hour: 1, minute: 54, timeZone: timeZone))

        let startDate = (prayerDay.times[.fajr]?.dateInterval.start ?? .now) - 60
        XCTAssertEqual(prayerDay.current(at: startDate)?.type, .isha)
        XCTAssertEqual(prayerDay.current(at: startDate)?.dateInterval.start, prayerDay.yesterday[.isha]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: startDate)?.type, .fajr)
        XCTAssertEqual(prayerDay.next(at: startDate)?.dateInterval.start, prayerDay.times[.fajr]?.dateInterval.start)

        let fajrDate = (prayerDay.times[.fajr]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: fajrDate)?.type, .fajr)
        XCTAssertEqual(prayerDay.current(at: fajrDate)?.dateInterval.start, prayerDay.times[.fajr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: fajrDate)?.type, .sunrise)
        XCTAssertEqual(prayerDay.next(at: fajrDate)?.dateInterval.start, prayerDay.times[.sunrise]?.dateInterval.start)

        XCTAssertEqual(prayerDay.next(at: fajrDate - 60)?.type, .fajr)
        XCTAssertEqual(prayerDay.next(at: fajrDate - 60)?.dateInterval.start, prayerDay.times[.fajr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: fajrDate - 60, sunriseAfterIsha: true)?.type, .sunrise)
        XCTAssertEqual(prayerDay.next(at: fajrDate - 60, sunriseAfterIsha: true)?.dateInterval.start, prayerDay.times[.sunrise]?.dateInterval.start)

        let dhuhrDate = (prayerDay.times[.dhuhr]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: dhuhrDate)?.type, .dhuhr)
        XCTAssertEqual(prayerDay.current(at: dhuhrDate)?.dateInterval.start, prayerDay.times[.dhuhr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: dhuhrDate)?.type, .asr)
        XCTAssertEqual(prayerDay.next(at: dhuhrDate)?.dateInterval.start, prayerDay.times[.asr]?.dateInterval.start)

        let asrDate = (prayerDay.times[.asr]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: asrDate)?.type, .asr)
        XCTAssertEqual(prayerDay.current(at: asrDate)?.dateInterval.start, prayerDay.times[.asr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: asrDate)?.type, .maghrib)
        XCTAssertEqual(prayerDay.next(at: asrDate)?.dateInterval.start, prayerDay.times[.maghrib]?.dateInterval.start)

        let maghribDate = (prayerDay.times[.maghrib]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: maghribDate)?.type, .maghrib)
        XCTAssertEqual(prayerDay.current(at: maghribDate)?.dateInterval.start, prayerDay.times[.maghrib]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: maghribDate)?.type, .isha)
        XCTAssertEqual(prayerDay.next(at: maghribDate)?.dateInterval.start, prayerDay.times[.isha]?.dateInterval.start)

        let ishaDate = (prayerDay.times[.isha]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: ishaDate)?.type, .isha)
        XCTAssertEqual(prayerDay.current(at: ishaDate)?.dateInterval.start, prayerDay.times[.isha]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: ishaDate)?.type, .fajr)
        XCTAssertEqual(prayerDay.next(at: ishaDate)?.dateInterval.start, prayerDay.tomorrow[.fajr]?.dateInterval.start)

        let endDate = prayerDay.times[.isha]?.dateInterval.start ?? .now
        XCTAssertEqual(prayerDay.next(at: endDate)?.type, .fajr)
        XCTAssertEqual(prayerDay.next(at: endDate)?.dateInterval.start, prayerDay.tomorrow[.fajr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: endDate, sunriseAfterIsha: true)?.dateInterval.start, prayerDay.tomorrow[.sunrise]?.dateInterval.start)
    }
}

extension PrayerDayAdhanTests {
    func testLondon() async throws {
        // Given
        let (prayerDay, timeZone) = try await fetchPrayerDay(
            for: "2022/02/25",
            timeZoneIdentifier: "GMT",
            latitude: 51.509865,
            longitude: -0.118092,
            method: .london
        )

        // Then
        XCTAssertEqual(prayerDay.times[.fajr]?.dateInterval.start, Date(year: 2022, month: 2, day: 25, hour: 5, minute: 15, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.sunrise]?.dateInterval.start, Date(year: 2022, month: 2, day: 25, hour: 6, minute: 52, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.dhuhr]?.dateInterval.start, Date(year: 2022, month: 2, day: 25, hour: 12, minute: 19, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.asr]?.dateInterval.start, Date(year: 2022, month: 2, day: 25, hour: 14, minute: 59, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.maghrib]?.dateInterval.start, Date(year: 2022, month: 2, day: 25, hour: 17, minute: 37, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.isha]?.dateInterval.start, Date(year: 2022, month: 2, day: 25, hour: 19, minute: 4, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.midnight]?.dateInterval.start, Date(year: 2022, month: 2, day: 25, hour: 23, minute: 25, timeZone: timeZone))
        XCTAssertEqual(prayerDay.times[.lastThird]?.dateInterval.start, Date(year: 2022, month: 2, day: 26, hour: 1, minute: 20, timeZone: timeZone))

        let startDate = (prayerDay.times[.fajr]?.dateInterval.start ?? .now) - 60
        XCTAssertEqual(prayerDay.current(at: startDate)?.type, .isha)
        XCTAssertEqual(prayerDay.current(at: startDate)?.dateInterval.start, prayerDay.yesterday[.isha]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: startDate)?.type, .fajr)
        XCTAssertEqual(prayerDay.next(at: startDate)?.dateInterval.start, prayerDay.times[.fajr]?.dateInterval.start)

        let fajrDate = (prayerDay.times[.fajr]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: fajrDate)?.type, .fajr)
        XCTAssertEqual(prayerDay.current(at: fajrDate)?.dateInterval.start, prayerDay.times[.fajr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: fajrDate)?.type, .sunrise)
        XCTAssertEqual(prayerDay.next(at: fajrDate)?.dateInterval.start, prayerDay.times[.sunrise]?.dateInterval.start)

        XCTAssertEqual(prayerDay.next(at: fajrDate - 60)?.type, .fajr)
        XCTAssertEqual(prayerDay.next(at: fajrDate - 60)?.dateInterval.start, prayerDay.times[.fajr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: fajrDate - 60, sunriseAfterIsha: true)?.type, .sunrise)
        XCTAssertEqual(prayerDay.next(at: fajrDate - 60, sunriseAfterIsha: true)?.dateInterval.start, prayerDay.times[.sunrise]?.dateInterval.start)

        let dhuhrDate = (prayerDay.times[.dhuhr]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: dhuhrDate)?.type, .dhuhr)
        XCTAssertEqual(prayerDay.current(at: dhuhrDate)?.dateInterval.start, prayerDay.times[.dhuhr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: dhuhrDate)?.type, .asr)
        XCTAssertEqual(prayerDay.next(at: dhuhrDate)?.dateInterval.start, prayerDay.times[.asr]?.dateInterval.start)

        let asrDate = (prayerDay.times[.asr]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: asrDate)?.type, .asr)
        XCTAssertEqual(prayerDay.current(at: asrDate)?.dateInterval.start, prayerDay.times[.asr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: asrDate)?.type, .maghrib)
        XCTAssertEqual(prayerDay.next(at: asrDate)?.dateInterval.start, prayerDay.times[.maghrib]?.dateInterval.start)

        let maghribDate = (prayerDay.times[.maghrib]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: maghribDate)?.type, .maghrib)
        XCTAssertEqual(prayerDay.current(at: maghribDate)?.dateInterval.start, prayerDay.times[.maghrib]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: maghribDate)?.type, .isha)
        XCTAssertEqual(prayerDay.next(at: maghribDate)?.dateInterval.start, prayerDay.times[.isha]?.dateInterval.start)

        let ishaDate = (prayerDay.times[.isha]?.dateInterval.start ?? .now)
        XCTAssertEqual(prayerDay.current(at: ishaDate)?.type, .isha)
        XCTAssertEqual(prayerDay.current(at: ishaDate)?.dateInterval.start, prayerDay.times[.isha]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: ishaDate)?.type, .fajr)
        XCTAssertEqual(prayerDay.next(at: ishaDate)?.dateInterval.start, prayerDay.tomorrow[.fajr]?.dateInterval.start)

        let endDate = prayerDay.times[.isha]?.dateInterval.start ?? .now
        XCTAssertEqual(prayerDay.next(at: endDate)?.type, .fajr)
        XCTAssertEqual(prayerDay.next(at: endDate)?.dateInterval.start, prayerDay.tomorrow[.fajr]?.dateInterval.start)
        XCTAssertEqual(prayerDay.next(at: endDate, sunriseAfterIsha: true)?.dateInterval.start, prayerDay.tomorrow[.sunrise]?.dateInterval.start)
    }
}

// MARK: - Helpers

private extension PrayerDayAdhanTests {
    func fetchPrayerDay(
        for dateString: String,
        timeZoneIdentifier: String,
        latitude: Double,
        longitude: Double,
        method: CalculationMethod,
        jurisprudence: Madhab = .standard,
        elevation: ElevationRule? = nil,
        filter: PrayerFilter = .all
    ) async throws -> (PrayerDay, TimeZone) {
        let coordinates = Coordinates(
            latitude: latitude,
            longitude: longitude
        )

        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { throw PrayError.invalidTimes }
        let dateFormatter = DateFormatter(dateFormat: "yyyy/MM/dd", timeZone: timeZone)
        guard let date = dateFormatter.date(from: dateString) else { throw PrayError.invalidTimes }

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

        return (try await prayerManager.fetch(for: date, with: request), timeZone)
    }
}
