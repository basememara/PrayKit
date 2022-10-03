//
//  HijriServiceStaticTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2022-03-17.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import XCTest
import PrayCore
import PrayServices

final class HijriServiceStaticTests: TestCase {
    private let preferences = Preferences(defaults: .test)

    private lazy var hijriService = HijriServiceStatic(
        prayerManager: prayerManager,
        preferences: preferences
    )
}

extension HijriServiceStaticTests {
    func testOffset() async throws {
        // Given
        guard let timeZone = TimeZone(identifier: "America/New_York"),
              let date1 = Date(year: 2022, month: 03, day: 16, hour: 2, timeZone: timeZone),
              let date2 = Date(year: 2022, month: 03, day: 16, hour: 20, timeZone: timeZone)
        else {
            throw PrayError.invalidTimes
        }

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
        let offset1 = try await hijriService.fetchOffset(for: date1)
        XCTAssertEqual(offset1, 2)

        let offset2 = try await hijriService.fetchOffset(for: date2)
        XCTAssertEqual(offset2, 3)

        // When
        preferences.hijriDayOffset = 1
        preferences.autoIncrementHijri = false

        // Then
        let offset3 = try await hijriService.fetchOffset(for: date1)
        XCTAssertEqual(offset3, 1)

        let offset4 = try await hijriService.fetchOffset(for: date2)
        XCTAssertEqual(offset4, 1)
    }
}

extension HijriServiceStaticTests {
    func testTimeline() async throws {
        // Given
        guard let timeZone = TimeZone(identifier: "America/New_York"),
              let startDate = Date(year: 2022, month: 3, day: 16, hour: 2, timeZone: timeZone)
        else {
            throw PrayError.invalidTimes
        }

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
        let dateFormatter = DateFormatter(dateFormat: "MMM dd, hh:mma")

        // Then
        timeline.forEach { entry in
            print(
                [
                    dateFormatter.string(for: entry.date),
                    "|",
                    "\(entry.hijriOffset)"
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            )
        }

        XCTAssertEqual(timeline.count, request.limit)
        XCTAssertEqual(timeline[0].hijriOffset, 2)
        XCTAssertEqual(timeline[1].hijriOffset, 3)
    }
}
