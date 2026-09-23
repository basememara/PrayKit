//
//  PrayerDayAdhanTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation
import Testing
import PrayCore

struct PrayerDayAdhanTests {
    private let prayerManager = PrayTestFixture().prayerManager
}

extension PrayerDayAdhanTests {
    @Test
    func toronto() async throws {
        // Given
        let (prayerDay, timeZone) = try await fetchPrayerDay(
            for: "2021/01/02",
            timeZoneIdentifier: "America/New_York",
            latitude: 43.651070,
            longitude: -79.347015,
            method: .northAmerica
        )

        // Then
        #expect(prayerDay.times[.fajr]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 6, minute: 25, timeZone: timeZone))
        #expect(prayerDay.times[.sunrise]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 7, minute: 51, timeZone: timeZone))
        #expect(prayerDay.times[.dhuhr]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 12, minute: 23, timeZone: timeZone))
        #expect(prayerDay.times[.asr]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 14, minute: 35, timeZone: timeZone))
        #expect(prayerDay.times[.maghrib]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 16, minute: 52, timeZone: timeZone))
        #expect(prayerDay.times[.isha]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 18, minute: 19, timeZone: timeZone))
        #expect(prayerDay.times[.midnight]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 23, minute: 39, timeZone: timeZone))
        #expect(prayerDay.times[.lastThird]?.dateInterval.start == Date(year: 2021, month: 1, day: 3, hour: 1, minute: 54, timeZone: timeZone))

        let startDate = (prayerDay.times[.fajr]?.dateInterval.start ?? .now) - 60
        #expect(prayerDay.current(at: startDate)?.type == .isha)
        #expect(prayerDay.current(at: startDate)?.dateInterval.start == prayerDay.yesterday[.isha]?.dateInterval.start)
        #expect(prayerDay.next(at: startDate)?.type == .fajr)
        #expect(prayerDay.next(at: startDate)?.dateInterval.start == prayerDay.times[.fajr]?.dateInterval.start)

        let fajrDate = (prayerDay.times[.fajr]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: fajrDate)?.type == .fajr)
        #expect(prayerDay.current(at: fajrDate)?.dateInterval.start == prayerDay.times[.fajr]?.dateInterval.start)
        #expect(prayerDay.next(at: fajrDate)?.type == .sunrise)
        #expect(prayerDay.next(at: fajrDate)?.dateInterval.start == prayerDay.times[.sunrise]?.dateInterval.start)

        #expect(prayerDay.next(at: fajrDate - 60)?.type == .fajr)
        #expect(prayerDay.next(at: fajrDate - 60)?.dateInterval.start == prayerDay.times[.fajr]?.dateInterval.start)
        #expect(prayerDay.next(at: fajrDate - 60, sunriseAfterIsha: true)?.type == .sunrise)
        #expect(prayerDay.next(at: fajrDate - 60, sunriseAfterIsha: true)?.dateInterval.start == prayerDay.times[.sunrise]?.dateInterval.start)

        let dhuhrDate = (prayerDay.times[.dhuhr]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: dhuhrDate)?.type == .dhuhr)
        #expect(prayerDay.current(at: dhuhrDate)?.dateInterval.start == prayerDay.times[.dhuhr]?.dateInterval.start)
        #expect(prayerDay.next(at: dhuhrDate)?.type == .asr)
        #expect(prayerDay.next(at: dhuhrDate)?.dateInterval.start == prayerDay.times[.asr]?.dateInterval.start)

        let asrDate = (prayerDay.times[.asr]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: asrDate)?.type == .asr)
        #expect(prayerDay.current(at: asrDate)?.dateInterval.start == prayerDay.times[.asr]?.dateInterval.start)
        #expect(prayerDay.next(at: asrDate)?.type == .maghrib)
        #expect(prayerDay.next(at: asrDate)?.dateInterval.start == prayerDay.times[.maghrib]?.dateInterval.start)

        let maghribDate = (prayerDay.times[.maghrib]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: maghribDate)?.type == .maghrib)
        #expect(prayerDay.current(at: maghribDate)?.dateInterval.start == prayerDay.times[.maghrib]?.dateInterval.start)
        #expect(prayerDay.next(at: maghribDate)?.type == .isha)
        #expect(prayerDay.next(at: maghribDate)?.dateInterval.start == prayerDay.times[.isha]?.dateInterval.start)

        let ishaDate = (prayerDay.times[.isha]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: ishaDate)?.type == .isha)
        #expect(prayerDay.current(at: ishaDate)?.dateInterval.start == prayerDay.times[.isha]?.dateInterval.start)
        #expect(prayerDay.next(at: ishaDate)?.type == .fajr)
        #expect(prayerDay.next(at: ishaDate)?.dateInterval.start == prayerDay.tomorrow[.fajr]?.dateInterval.start)

        let endDate = prayerDay.times[.isha]?.dateInterval.start ?? .now
        #expect(prayerDay.next(at: endDate)?.type == .fajr)
        #expect(prayerDay.next(at: endDate)?.dateInterval.start == prayerDay.tomorrow[.fajr]?.dateInterval.start)
        #expect(prayerDay.next(at: endDate, sunriseAfterIsha: true)?.dateInterval.start == prayerDay.tomorrow[.sunrise]?.dateInterval.start)
    }
}

extension PrayerDayAdhanTests {
    @Test
    func london() async throws {
        // Given
        let (prayerDay, timeZone) = try await fetchPrayerDay(
            for: "2022/02/25",
            timeZoneIdentifier: "GMT",
            latitude: 51.509865,
            longitude: -0.118092,
            method: .london
        )

        // Then
        #expect(prayerDay.times[.fajr]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 5, minute: 15, timeZone: timeZone))
        #expect(prayerDay.times[.sunrise]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 6, minute: 52, timeZone: timeZone))
        #expect(prayerDay.times[.dhuhr]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 12, minute: 19, timeZone: timeZone))
        #expect(prayerDay.times[.asr]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 14, minute: 59, timeZone: timeZone))
        #expect(prayerDay.times[.maghrib]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 17, minute: 37, timeZone: timeZone))
        #expect(prayerDay.times[.isha]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 19, minute: 4, timeZone: timeZone))
        #expect(prayerDay.times[.midnight]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 23, minute: 25, timeZone: timeZone))
        #expect(prayerDay.times[.lastThird]?.dateInterval.start == Date(year: 2022, month: 2, day: 26, hour: 1, minute: 20, timeZone: timeZone))

        let startDate = (prayerDay.times[.fajr]?.dateInterval.start ?? .now) - 60
        #expect(prayerDay.current(at: startDate)?.type == .isha)
        #expect(prayerDay.current(at: startDate)?.dateInterval.start == prayerDay.yesterday[.isha]?.dateInterval.start)
        #expect(prayerDay.next(at: startDate)?.type == .fajr)
        #expect(prayerDay.next(at: startDate)?.dateInterval.start == prayerDay.times[.fajr]?.dateInterval.start)

        let fajrDate = (prayerDay.times[.fajr]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: fajrDate)?.type == .fajr)
        #expect(prayerDay.current(at: fajrDate)?.dateInterval.start == prayerDay.times[.fajr]?.dateInterval.start)
        #expect(prayerDay.next(at: fajrDate)?.type == .sunrise)
        #expect(prayerDay.next(at: fajrDate)?.dateInterval.start == prayerDay.times[.sunrise]?.dateInterval.start)

        #expect(prayerDay.next(at: fajrDate - 60)?.type == .fajr)
        #expect(prayerDay.next(at: fajrDate - 60)?.dateInterval.start == prayerDay.times[.fajr]?.dateInterval.start)
        #expect(prayerDay.next(at: fajrDate - 60, sunriseAfterIsha: true)?.type == .sunrise)
        #expect(prayerDay.next(at: fajrDate - 60, sunriseAfterIsha: true)?.dateInterval.start == prayerDay.times[.sunrise]?.dateInterval.start)

        let dhuhrDate = (prayerDay.times[.dhuhr]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: dhuhrDate)?.type == .dhuhr)
        #expect(prayerDay.current(at: dhuhrDate)?.dateInterval.start == prayerDay.times[.dhuhr]?.dateInterval.start)
        #expect(prayerDay.next(at: dhuhrDate)?.type == .asr)
        #expect(prayerDay.next(at: dhuhrDate)?.dateInterval.start == prayerDay.times[.asr]?.dateInterval.start)

        let asrDate = (prayerDay.times[.asr]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: asrDate)?.type == .asr)
        #expect(prayerDay.current(at: asrDate)?.dateInterval.start == prayerDay.times[.asr]?.dateInterval.start)
        #expect(prayerDay.next(at: asrDate)?.type == .maghrib)
        #expect(prayerDay.next(at: asrDate)?.dateInterval.start == prayerDay.times[.maghrib]?.dateInterval.start)

        let maghribDate = (prayerDay.times[.maghrib]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: maghribDate)?.type == .maghrib)
        #expect(prayerDay.current(at: maghribDate)?.dateInterval.start == prayerDay.times[.maghrib]?.dateInterval.start)
        #expect(prayerDay.next(at: maghribDate)?.type == .isha)
        #expect(prayerDay.next(at: maghribDate)?.dateInterval.start == prayerDay.times[.isha]?.dateInterval.start)

        let ishaDate = (prayerDay.times[.isha]?.dateInterval.start ?? .now)
        #expect(prayerDay.current(at: ishaDate)?.type == .isha)
        #expect(prayerDay.current(at: ishaDate)?.dateInterval.start == prayerDay.times[.isha]?.dateInterval.start)
        #expect(prayerDay.next(at: ishaDate)?.type == .fajr)
        #expect(prayerDay.next(at: ishaDate)?.dateInterval.start == prayerDay.tomorrow[.fajr]?.dateInterval.start)

        let endDate = prayerDay.times[.isha]?.dateInterval.start ?? .now
        #expect(prayerDay.next(at: endDate)?.type == .fajr)
        #expect(prayerDay.next(at: endDate)?.dateInterval.start == prayerDay.tomorrow[.fajr]?.dateInterval.start)
        #expect(prayerDay.next(at: endDate, sunriseAfterIsha: true)?.dateInterval.start == prayerDay.tomorrow[.sunrise]?.dateInterval.start)
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

        let timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
        let dateFormatter = DateFormatter(dateFormat: "yyyy/MM/dd", timeZone: timeZone)
        let date = try #require(dateFormatter.date(from: dateString))

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
