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
    private let preferences: Preferences
    private let hijriService: HijriServiceStatic

    init() {
        let fixture = PrayTestFixture()
        preferences = fixture.preferences
        hijriService = HijriServiceStatic(
            prayerManager: fixture.prayerManager,
            preferences: fixture.preferences
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
        preferences.set(
            manualAddress: Coordinates(
                latitude: 43.651070,
                longitude: -79.347015
            ),
            timeZone: timeZone,
            regionName: nil
        )
        preferences.hijriDayOffset = 2
        preferences.autoIncrementHijri = true

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
        preferences.set(
            manualAddress: Coordinates(
                latitude: 43.651070,
                longitude: -79.347015
            ),
            timeZone: timeZone,
            regionName: nil
        )
        preferences.hijriDayOffset = 1
        preferences.autoIncrementHijri = false

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
        preferences.set(
            manualAddress: Coordinates(
                latitude: 43.651070,
                longitude: -79.347015
            ),
            timeZone: timeZone,
            regionName: nil
        )
        preferences.hijriDayOffset = 2
        preferences.autoIncrementHijri = true

        let timeline = try await hijriService.fetch(with: request)

        // Then
        #expect(timeline.count == request.limit)
        #expect(timeline[0].hijriOffset == 2)
        #expect(timeline[1].hijriOffset == 3)
    }
}
