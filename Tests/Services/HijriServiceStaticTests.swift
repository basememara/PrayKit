//
//  HijriServiceStaticTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2022-03-17.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import PrayServices
import Testing
import ZamzamCore

struct HijriServiceStaticTests {
    private let storage: SettingsStorage
    private let hijriService: HijriServiceStatic

    init() {
        let fixture = PrayTestFixture()
        storage = fixture.storage
        hijriService = HijriServiceStatic(
            prayerManager: fixture.prayerManager,
            storage: fixture.storage
        )
    }
}

extension HijriServiceStaticTests {
    @Test
    func offsetIncrementsAfterMaghribWhenAutoIncrementIsOn() async throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let beforeMaghrib = try #require(Date(year: 2022, month: 03, day: 16, hour: 2, timeZone: timeZone))
        let afterMaghrib = try #require(Date(year: 2022, month: 03, day: 16, hour: 20, timeZone: timeZone))

        // When
        saveManualAddress(
            Coordinates(latitude: 43.651070, longitude: -79.347015),
            timeZone: timeZone,
            hijriDayOffset: 2,
            autoIncrementHijri: true
        )

        // Then
        let offsetBeforeMaghrib = try await hijriService.fetchOffset(for: beforeMaghrib)
        #expect(offsetBeforeMaghrib == 2)

        let offsetAfterMaghrib = try await hijriService.fetchOffset(for: afterMaghrib)
        #expect(offsetAfterMaghrib == 3)
    }

    @Test
    func offsetHoldsAllDayWhenAutoIncrementIsOff() async throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let beforeMaghrib = try #require(Date(year: 2022, month: 03, day: 16, hour: 2, timeZone: timeZone))
        let afterMaghrib = try #require(Date(year: 2022, month: 03, day: 16, hour: 20, timeZone: timeZone))

        // When
        saveManualAddress(
            Coordinates(latitude: 43.651070, longitude: -79.347015),
            timeZone: timeZone,
            hijriDayOffset: 1,
            autoIncrementHijri: false
        )

        // Then
        #expect(try await hijriService.fetchOffset(for: beforeMaghrib) == 1)
        #expect(try await hijriService.fetchOffset(for: afterMaghrib) == 1)
    }
}

extension HijriServiceStaticTests {
    @Test
    func timelineIncrementsAtTheFirstMaghrib() async throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let startDate = try #require(Date(year: 2022, month: 3, day: 16, hour: 2, timeZone: timeZone))

        let request = HijriAPI.FetchTimelineRequest(
            startDate: startDate,
            timeZone: timeZone,
            limit: 30
        )

        // When
        saveManualAddress(
            Coordinates(latitude: 43.651070, longitude: -79.347015),
            timeZone: timeZone,
            hijriDayOffset: 2,
            autoIncrementHijri: true
        )

        let timeline = try await hijriService.fetch(with: request)

        // Then
        #expect(timeline.count == request.limit)
        #expect(timeline[0].hijriOffset == 2)
        #expect(timeline[1].hijriOffset == 3)
    }
}

extension HijriServiceStaticTests {
    @Test
    func timelineWaitsForAMaghribAfterMidnight() async throws {
        // Given: Reykjavik in June, where each day's Maghrib begins just after the next midnight
        let timeZone = try #require(TimeZone(identifier: "Atlantic/Reykjavik"))
        let startDate = try #require(Date(year: 2026, month: 6, day: 21, hour: 12, timeZone: timeZone))
        let request = HijriAPI.FetchTimelineRequest(startDate: startDate, timeZone: timeZone, limit: 8)

        // When
        saveManualAddress(
            Coordinates(latitude: 64.1466, longitude: -21.9426),
            timeZone: timeZone,
            hijriDayOffset: 2,
            autoIncrementHijri: true
        )

        let timeline = try await hijriService.fetch(with: request)

        // Then: each midnight holds the previous Hijri day until that Maghrib turns it
        let midnight = try #require(Date(year: 2026, month: 6, day: 21, hour: 0, timeZone: timeZone))
        #expect(timeline.prefix(4).map(\.hijriOffset) == [1, 2, 1, 2])
        #expect(timeline.first?.date == midnight)
        #expect(zip(timeline, timeline.dropFirst()).allSatisfy { $0.date < $1.date })
    }
}

// MARK: - Helpers

private extension HijriServiceStaticTests {
    func saveManualAddress(_ coordinates: Coordinates, timeZone: TimeZone, hijriDayOffset: Int, autoIncrementHijri: Bool) {
        storage.setManualPlace(coordinates, timeZone: timeZone, regionName: nil)
        storage.edit {
            $0.hijriDayOffset = hijriDayOffset
            $0.autoIncrementHijri = autoIncrementHijri
        }
    }
}
