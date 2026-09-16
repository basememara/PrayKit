//
//  PrayerManagerTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing
import ZamzamCore

/// Covers `fetch(between:)`, which fans out one task per day through a task group.
///
/// Notification scheduling, the Hijri timeline and the iqama widget all depend on it, and for
/// the London method every one of those concurrent tasks reads the same cached timetable.
struct PrayerManagerTests {
    private let prayerManager = PrayTestFixture().prayerManager
}

extension PrayerManagerTests {
    @Test
    func rangeCoversEveryDayInOrderWithoutDuplicates() async throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone, locale: .posix)
        let start = try #require(Date(year: 2021, month: 1, day: 2, timeZone: timeZone))
        let end = try #require(Date(year: 2021, month: 1, day: 11, timeZone: timeZone))

        // When
        let prayerDays = try await prayerManager.fetch(
            between: DateInterval(start: start, end: end),
            with: .toronto(timeZone: timeZone)
        )

        // Then
        #expect(prayerDays.count == 10)
        #expect(prayerDays == prayerDays.sorted(by: \.date), "The task group must not leak its completion order")

        let days = prayerDays.map { calendar.startOfDay(for: $0.date) }
        #expect(Set(days).count == days.count, "A day was fetched twice")

        let first = try #require(prayerDays.first)
        #expect(first.times[.fajr]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 6, minute: 25, timeZone: timeZone))
        #expect(first.times[.maghrib]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 16, minute: 52, timeZone: timeZone))

        // Every day must carry a full set of times, or a notification silently goes unscheduled
        for prayerDay in prayerDays {
            #expect(prayerDay.times.contains { $0.type == .fajr })
            #expect(prayerDay.times.contains { $0.type == .maghrib })
            #expect(!prayerDay.yesterday.isEmpty)
            #expect(!prayerDay.tomorrow.isEmpty)
        }
    }

    @Test
    func londonRangeIsConsistentUnderConcurrentFanOut() async throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "GMT"))
        let start = try #require(Date(year: 2022, month: 2, day: 25, timeZone: timeZone))
        let end = try #require(Date(year: 2022, month: 3, day: 6, timeZone: timeZone))
        let interval = DateInterval(start: start, end: end)
        let request = PrayerAPI.Request.london(timeZone: timeZone)

        // When: two overlapping ranges race for the same cached year
        async let first = prayerManager.fetch(between: interval, with: request)
        async let second = prayerManager.fetch(between: interval, with: request)
        let (left, right) = try await (first, second)

        // Then
        #expect(left.count == 10)
        #expect(left.map(\.date) == right.map(\.date), "Concurrent fetches disagreed on which days they covered")

        for (lhs, rhs) in zip(left, right) {
            #expect(lhs.times.map(\.dateInterval.start) == rhs.times.map(\.dateInterval.start), "The cached timetable returned different times to concurrent readers")
        }

        let opener = try #require(left.first)
        #expect(opener.times[.fajr]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 5, minute: 15, timeZone: timeZone))
        #expect(opener.times[.maghrib]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 17, minute: 37, timeZone: timeZone))
    }

    @Test
    func londonRangeSpanningAYearBoundaryLoadsBothTimetables() async throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "GMT"))
        let start = try #require(Date(year: 2022, month: 12, day: 29, timeZone: timeZone))
        let end = try #require(Date(year: 2023, month: 1, day: 3, timeZone: timeZone))

        // When
        let prayerDays = try await prayerManager.fetch(
            between: DateInterval(start: start, end: end),
            with: .london(timeZone: timeZone)
        )

        // Then
        #expect(prayerDays.count == 6)

        // Both calendar years have to resolve, which means both years' timetables were cached
        for prayerDay in prayerDays {
            #expect(prayerDay.times.contains { $0.type == .fajr }, "Missing times on \(prayerDay.date)")
            #expect(prayerDay.times.contains { $0.type == .maghrib }, "Missing times on \(prayerDay.date)")
        }
    }
}

// MARK: - Helpers

private extension PrayerAPI.Request {
    static func toronto(timeZone: TimeZone) -> Self {
        Self(
            coordinates: Coordinates(latitude: 43.651070, longitude: -79.347015),
            timeZone: timeZone,
            method: .northAmerica
        )
    }

    static func london(timeZone: TimeZone) -> Self {
        Self(
            coordinates: Coordinates(latitude: 51.509865, longitude: -0.118092),
            timeZone: timeZone,
            method: .london
        )
    }
}
