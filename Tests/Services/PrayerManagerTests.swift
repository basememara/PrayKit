//
//  PrayerManagerTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import PrayServices
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
        let start = try #require(Date(year: 2021, month: 1, day: 2, calendar: calendar))
        let end = try #require(Date(year: 2021, month: 1, day: 11, calendar: calendar))

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
        #expect(first.times[.fajr]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 6, minute: 25, calendar: calendar))
        #expect(first.times[.maghrib]?.dateInterval.start == Date(year: 2021, month: 1, day: 2, hour: 16, minute: 52, calendar: calendar))

        // Every day must carry a full set of times, or a notification silently goes unscheduled
        for prayerDay in prayerDays {
            #expect(prayerDay.times.contains { $0.type == .fajr })
            #expect(prayerDay.times.contains { $0.type == .maghrib })
            #expect(!prayerDay.tomorrow.isEmpty)
        }
    }

    @Test
    func londonRangeIsConsistentUnderConcurrentFanOut() async throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "GMT"))
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let start = try #require(Date(year: 2022, month: 2, day: 25, calendar: calendar))
        let end = try #require(Date(year: 2022, month: 3, day: 6, calendar: calendar))
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
        #expect(opener.times[.fajr]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 5, minute: 15, calendar: calendar))
        #expect(opener.times[.maghrib]?.dateInterval.start == Date(year: 2022, month: 2, day: 25, hour: 17, minute: 37, calendar: calendar))
    }

    @Test
    func londonRangeSpanningAYearBoundaryLoadsBothTimetables() async throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "GMT"))
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let start = try #require(Date(year: 2022, month: 12, day: 29, calendar: calendar))
        let end = try #require(Date(year: 2023, month: 1, day: 3, calendar: calendar))

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

    /// May 26 puts Fajr past sunrise, so May 25, whose Isha ends at May 26's Fajr, can't be calculated.
    @Test
    func aDayThatCantBeCalculatedEndsTheRangeThere() async throws {
        // Given
        let place = edinburghFajrPastSunriseByMay26()
        let start = try place.date(2026, 5, 20)
        let end = try place.date(2026, 5, 30)

        // When
        let prayerDays = try await prayerManager.fetch(between: DateInterval(start: start, end: end), with: try place.request())

        // Then
        let calendar = try place.calendar()
        #expect(prayerDays.map { calendar.component(.day, from: $0.date) } == [20, 21, 22, 23, 24])
    }

    @Test
    func aRangeWhoseFirstDayCantBeCalculatedThrows() async throws {
        // Given
        let place = edinburghFajrPastSunriseByMay26()
        let start = try place.date(2026, 5, 25)
        let end = try place.date(2026, 5, 30)

        // Then
        await #expect(throws: PrayError.self) {
            try await prayerManager.fetch(between: DateInterval(start: start, end: end), with: try place.request())
        }
    }

    /// London's timetable ends with its last bundled year, past which a day comes back with no times.
    @Test
    func aDayPastTheTimetableEndsTheRangeThere() async throws {
        // Given
        let place = edinburghInLateDecember()
        let prayerManager = timetablePrayerManager(endingAfter: try place.date(2026, 12, 31))
        let start = try place.date(2026, 12, 29)
        let end = try place.date(2027, 1, 3)

        // When
        let prayerDays = try await prayerManager.fetch(between: DateInterval(start: start, end: end), with: try place.request())

        // Then
        let calendar = try place.calendar()
        #expect(prayerDays.map { calendar.component(.day, from: $0.date) } == [29, 30, 31])
    }

    @Test
    func aDayPastTheTimetableThrows() async throws {
        // Given
        let place = edinburghInLateDecember()
        let prayerManager = timetablePrayerManager(endingAfter: try place.date(2026, 12, 31))
        let date = try place.date(2027, 1, 2)

        // Then
        await #expect(throws: PrayError.self) {
            try await prayerManager.fetch(for: date, with: try place.request())
        }
    }
}

// MARK: - Helpers

private extension PrayerManagerTests {
    func edinburghInLateDecember() -> DayFixture {
        DayFixture("Edinburgh in late December", 55.9533, -3.1883, "Europe/London", .muslimWorldLeague, 2026, 12, 29)
    }

    func timetablePrayerManager(endingAfter lastDay: Date) -> PrayerManager {
        let fixture = PrayTestFixture()
        let service = TimetableService(lastDay: lastDay, service: PrayerServiceAdhan(log: fixture.log))
        return PrayerManager(service: service, londonService: service, log: fixture.log)
    }

    func edinburghFajrPastSunriseByMay26() -> DayFixture {
        DayFixture(
            "Edinburgh, Fajr 60 minutes later, past sunrise by May 26", 55.9533, -3.1883, "Europe/London", .muslimWorldLeague, 2026, 5, 17,
            adjustments: .absolute(fajr: 60)
        )
    }
}

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

/// A timetable that answers a day after its last with no times, as London's does past its last bundled year.
private struct TimetableService: PrayerService {
    let lastDay: Date
    let service: PrayerService

    func calculate(for date: Date, using calendar: Calendar, with request: PrayerAPI.Request) async throws -> [PrayerTime] {
        date > lastDay ? [] : try await service.calculate(for: date, using: calendar, with: request)
    }
}
