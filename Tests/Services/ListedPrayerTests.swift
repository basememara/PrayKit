//
//  ListedPrayerTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import PrayMocks
import Testing

/// What a list's rows show: a day's times in time order, and where each stands at a moment.
struct ListedPrayerTests {
    private let fixture = PrayTestFixture()
}

// MARK: - Order

extension ListedPrayerTests {
    @Test(arguments: DayFixture.all)
    func aDaysTimesAreListedOnceEachInTimeOrder(place: DayFixture) async throws {
        let day = try await day(of: place)
        let listed = day.listed(at: try place.firstNoon())
        let starts = listed.map(\.prayerTime.dateInterval.start)

        #expect(listed.map(\.prayerTime) == day.times)
        #expect(starts == starts.sorted())
        #expect(listed.map(\.id).filter(\.isEssential) == [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])
    }

    @Test
    func aDayBuiltOutOfOrderIsStillListedInTimeOrder() throws {
        let place = try #require(DayFixture.all.first)
        let calendar = try place.calendar()
        let day = PrayerDay.mock(at: try place.firstNoon(), calendar: calendar)
        let reversed = PrayerDay(date: day.date, times: day.times.reversed(), tomorrow: day.tomorrow)

        #expect(reversed.listed(at: day.date).map(\.prayerTime) == day.times)
    }
}

// MARK: - Stage

extension ListedPrayerTests {
    /// A second before each prayer begins and as it begins: the times ahead are upcoming, the one prayer under way is
    /// current, and everything else that has begun is passed, the night's markers included.
    @Test(arguments: DayFixture.all)
    func aPrayerIsCurrentFromItsFirstSecondUntilTheNextBegins(place: DayFixture) async throws {
        let day = try await day(of: place)
        let essentials = day.times.filter(\.type.isEssential)
        let moments = essentials.map(\.dateInterval.start).flatMap { [$0 - 1, $0] }

        let problems = moments.flatMap { moment in
            let underWay = essentials.last { $0.dateInterval.start <= moment }

            return day.listed(at: moment).compactMap { row in
                let expected = Self.stage(of: row.prayerTime, at: moment, underWay: underWay)
                return row.stage == expected ? nil : "\(row.id) at \(moment.formatted(.iso8601)): \(row.stage), not \(expected)"
            }
        }

        #expect(moments.count == 12)
        #expect(problems.isEmpty, "first problems: \(problems.prefix(5))")
    }

    /// A second before the turnover a timer lists its own day with the prayer under way current. At the turnover it
    /// lists the next day, where nothing has begun, unless the turnover is the next Fajr, which begins that day.
    @Test(arguments: DayFixture.all)
    func aTimersListTurnsToTheNextDayAtTheTurnover(place: DayFixture) async throws {
        let days = try await place.days(2, using: fixture.prayerManager)
        let calendar = try place.calendar()
        let settings = Settings()
        let turnover = try #require(days[0].turnover(settings: settings, using: calendar))

        let before = try #require(timer(at: turnover - 1, in: days, settings: settings, using: calendar))
        let after = try #require(timer(at: turnover, in: days, settings: settings, using: calendar))
        let listedBefore = before.listed
        let listedAfter = after.listed

        #expect(listedBefore == before.listedDay.listed(at: before.date))
        #expect(listedBefore.map(\.prayerTime) == days[0].times)
        #expect(listedBefore.filter { $0.stage == .current }.map(\.prayerTime) == [days[0].current(at: turnover - 1)].compactMap(\.self))
        #expect(listedAfter.map(\.prayerTime) == days[1].times)
        #expect(listedAfter.filter { $0.stage != .upcoming }.map(\.id) == (days[0].contains(turnover) ? [] : [.fajr]))
    }

    /// Past the turnover the listed day is tomorrow's: every row is still to come until its Fajr, which is then
    /// under way. The day that was turned over, asked about that same Fajr, reads it as passed, so a row's stage
    /// comes from the day being listed.
    @Test(arguments: DayFixture.all)
    func aListedTomorrowPicksOutNothingBeforeItsFajr(place: DayFixture) async throws {
        let day = try await day(of: place)
        let calendar = try place.calendar()
        let settings = Settings()
        let turnover = try #require(day.turnover(settings: settings, using: calendar))
        let nextFajr = try #require(day.tomorrow[.fajr])
        let fajrBegins = nextFajr.dateInterval.start

        let beforeFajr = [turnover, fajrBegins - 1].filter { turnover <= $0 && $0 < fajrBegins }.map { moment in
            day.listedDay(at: moment, settings: settings, using: calendar).listed(at: moment)
        }
        let atFajr = day.listedDay(at: fajrBegins, settings: settings, using: calendar).listed(at: fajrBegins)

        #expect(beforeFajr.allSatisfy { rows in rows.map(\.prayerTime) == day.tomorrow })
        #expect(beforeFajr.allSatisfy { rows in rows.allSatisfy { $0.stage == .upcoming } })
        #expect(atFajr.map(\.prayerTime) == day.tomorrow)
        #expect(atFajr.filter { $0.stage != .upcoming }.map(\.stage) == [.current])
        #expect(atFajr.first { $0.stage == .current }?.id == .fajr)
        #expect(day.stage(of: nextFajr, at: fajrBegins) == .passed)
    }
}

// MARK: - Helpers

private extension ListedPrayerTests {
    func day(of place: DayFixture) async throws -> PrayerDay {
        try #require(try await place.days(1, using: fixture.prayerManager).first)
    }

    /// A timer from whichever day holds the moment, as a timeline builds one.
    func timer(at moment: Date, in days: [PrayerDay], settings: Settings, using calendar: Calendar) -> PrayerTimer? {
        days.first { $0.contains(moment) }.flatMap { PrayerTimer(at: moment, using: $0, settings: settings, timeZone: calendar.timeZone) }
    }

    static func stage(of prayerTime: PrayerTime, at moment: Date, underWay: PrayerTime?) -> PrayerStage {
        guard prayerTime.dateInterval.start <= moment else { return .upcoming }
        return prayerTime == underWay ? .current : .passed
    }
}
