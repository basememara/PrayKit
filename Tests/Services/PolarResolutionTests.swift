//
//  PolarResolutionTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import PrayServices
import Testing
import ZamzamCore

/// A day near the poles that can't be calculated at the place takes its times from the nearest latitude or the nearest
/// day, marked as borrowed; every other day is the place's own.
struct PolarResolutionTests {
    private let fixture = PrayTestFixture()
    private let tromso = Coordinates(latitude: 69.6492, longitude: 18.9553)
    private let london = Coordinates(latitude: 51.5074, longitude: -0.1278)
    private let utc: TimeZone

    init() throws {
        utc = try #require(TimeZone(identifier: "UTC"))
    }
}

extension PolarResolutionTests {
    @Test
    func aMidnightSunDayBorrowsFromTheChosenSource() async throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/Oslo"))
        let day = try #require(Date(year: 2026, month: 6, day: 21, hour: 12, calendar: Calendar(identifier: .gregorian, timeZone: timeZone)))

        let nearestLatitude = try await fixture.prayerManager.fetch(for: day, with: request(at: tromso, in: timeZone, method: .northAmerica))
        let nearestDay = try await fixture.prayerManager.fetch(
            for: day,
            with: request(at: tromso, in: timeZone, method: .northAmerica, polarResolution: .nearestDay)
        )

        #expect(nearestLatitude.borrowed == .nearestLatitude)
        #expect(nearestDay.borrowed == .nearestDay)
        #expect(nearestLatitude.times[.maghrib] != nearestDay.times[.maghrib])
    }

    @Test
    func aDayThePlaceCanCalculateIsItsOwn() async throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let day = try await fixture.prayerManager.fetch(
            for: try #require(Date(year: 2026, month: 6, day: 21, hour: 12, calendar: Calendar(identifier: .gregorian, timeZone: timeZone))),
            with: request(at: london, in: timeZone, method: .moonsightingCommittee, polarResolution: .nearestDay)
        )

        #expect(day.borrowed == nil)
    }

    @Test
    func theRequestCarriesTheSetting() {
        var settings = Settings()
        settings.polarResolution = .nearestDay

        #expect(PrayerAPI.Request(settings: settings, place: .zone(utc, at: tromso))?.polarResolution == .nearestDay)
    }
}

// MARK: - Where it applies

extension PolarResolutionTests {
    @Test
    func everyMethodCanBorrowFrom65AndAHalfDegrees() {
        var settings = Settings()
        settings.calculationMethod = .muslimWorldLeague

        #expect(PolarResolution.applies(at: place(latitude: 65.5), with: settings))
        #expect(PolarResolution.applies(at: place(latitude: -69.6), with: settings))
        #expect(!PolarResolution.applies(at: place(latitude: 65.4), with: settings))
    }

    @Test(arguments: [CalculationMethod.tehran, .shia])
    func aMaghribByAngleCanBorrowFrom57Degrees(method: CalculationMethod) {
        var settings = Settings()
        settings.pickMethod(method, at: nil)

        #expect(PolarResolution.applies(at: place(latitude: 59.3), with: settings))
        #expect(!PolarResolution.applies(at: place(latitude: 56.9), with: settings))
    }

    @Test
    func aCustomMaghribAngleCountsAsTimingMaghribByAngle() {
        var settings = Settings()
        settings.pickMethod(.custom, at: nil)
        #expect(!PolarResolution.applies(at: place(latitude: 59.3), with: settings))

        settings.maghribDegrees = 4
        #expect(PolarResolution.applies(at: place(latitude: 59.3), with: settings))
    }

    /// The thresholds hold: a year just below them never borrows a day.
    @Test(arguments: [
        (CalculationMethod.muslimWorldLeague, 65.4),
        (.northAmerica, 65.4),
        (.moonsightingCommittee, 65.4),
        (.tehran, 56.9),
        (.shia, 56.9)
    ])
    func noDayBorrowsBelowWhereItApplies(method: CalculationMethod, latitude: Double) throws {
        let service = PrayerServiceAdhan(log: fixture.log)
        let calendar = Calendar(identifier: .gregorian, timeZone: utc)
        let start = try #require(Date(year: 2026, month: 1, day: 1, hour: 12, calendar: calendar))
        let request = request(at: Coordinates(latitude: latitude, longitude: 18.9553), in: utc, method: method)

        let borrowed = (0..<365)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            .filter { (try? service.calculate(for: $0, using: calendar, with: request))?.first?.borrowed != nil }

        #expect(borrowed.isEmpty)
    }
}

// MARK: - Days computed out of order

extension PolarResolutionTests {
    // Near the edge of the midnight sun and the polar night the Moonsighting Committee's times can be computed but come
    // out of order, which failed the day where a day that couldn't be computed at all borrowed
    @Test(arguments: PolarResolution.allCases)
    func aDayComputedOutOfOrderBorrowsLikeOneThatCantBeComputed(resolution: PolarResolution) async throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/Oslo"))
        let date = try #require(Date(year: 2026, month: 5, day: 16, hour: 12, calendar: Calendar(identifier: .gregorian, timeZone: timeZone)))

        let day = try await fixture.prayerManager.fetch(
            for: date,
            with: request(at: tromso, in: timeZone, method: .moonsightingCommittee, polarResolution: resolution)
        )

        #expect(day.borrowed == resolution)
    }

    // Every day has times, and each hands over to the next at the very Fajr that day begins with, so the days tile
    @Test(arguments: [
        (Coordinates(latitude: 69.6492, longitude: 18.9553), "Europe/Oslo"),
        (Coordinates(latitude: 68.9585, longitude: 33.0827), "Europe/Moscow")
    ], PolarResolution.allCases)
    func everyDayOfTheYearHasTimesAndMeetsTheNextNearThePolarCircle(place: (Coordinates, String), resolution: PolarResolution) throws {
        let service = PrayerServiceAdhan(log: fixture.log)
        let timeZone = try #require(TimeZone(identifier: place.1))
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let start = try #require(Date(year: 2026, month: 1, day: 1, hour: 12, calendar: calendar))
        let dates = (0...365).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let label = Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()

        CalculationMethod.allCases.filter { ![.custom, .london].contains($0) }.forEach { method in
            let request = request(at: place.0, in: timeZone, method: method, polarResolution: resolution)
            let days = dates.map { try? service.calculate(for: $0, using: calendar, with: request) }
            let missing = zip(dates, days).filter { $0.1 == nil }.map { $0.0.formatted(label) }
            let gaps = zip(dates, zip(days, days.dropFirst())).compactMap { date, pair -> String? in
                guard let end = pair.0?.map(\.dateInterval.end).max(),
                      let fajr = pair.1?.first(where: { $0.type == .fajr })?.dateInterval.start,
                      end != fajr
                else { return nil }

                return date.formatted(label)
            }

            #expect(missing.isEmpty, "\(method.rawValue) has no times on \(missing)")
            #expect(gaps.isEmpty, "\(method.rawValue) misses the next Fajr after \(gaps)")
        }
    }
}

// MARK: - Helpers

private extension PolarResolutionTests {
    func request(
        at coordinates: Coordinates,
        in timeZone: TimeZone,
        method: CalculationMethod,
        polarResolution: PolarResolution = .nearestLatitude
    ) -> PrayerAPI.Request {
        PrayerAPI.Request(coordinates: coordinates, timeZone: timeZone, method: method, polarResolution: polarResolution)
    }

    func place(latitude: Double) -> Place {
        .zone(utc, at: Coordinates(latitude: latitude, longitude: 18.9553))
    }
}
