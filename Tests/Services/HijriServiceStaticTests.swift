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

// MARK: - Helpers

private extension HijriServiceStaticTests {
    /// A manual address also switches to the time zone's recommended method.
    func saveManualAddress(_ coordinates: Coordinates, timeZone: TimeZone, hijriDayOffset: Int, autoIncrementHijri: Bool) {
        storage.update { state in
            DeviceState(
                document: state.document.editing(at: .now) {
                    $0.calculationMethod = .recommended(for: timeZone) ?? .moonsightingCommittee
                    $0.hijriDayOffset = hijriDayOffset
                    $0.autoIncrementHijri = autoIncrementHijri
                },
                place: Place(coordinates: coordinates, timeZone: timeZone, regionName: nil, fixedAt: .now)
            )
        }
    }
}
