//
//  PrayerDayRuleTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

/// A prayer day runs from its Fajr to the next Fajr: its essential prayers tile that span, and the days tile in turn.
struct PrayerDayRuleTests {
    private let fixture = PrayTestFixture()
}

extension PrayerDayRuleTests {
    @Test(arguments: DayFixture.all)
    func essentialPrayersTileEachDayAndTheDaysTileInTurn(place: DayFixture) async throws {
        let days = try await place.days(4, using: fixture.prayerManager)

        for (day, next) in zip(days, days.dropFirst()) {
            let essentials = day.times.filter(\.type.isEssential)
            #expect(essentials.map(\.type) == [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])

            for (prayer, following) in zip(essentials, essentials.dropFirst()) {
                #expect(prayer.dateInterval.end == following.dateInterval.start, "\(prayer.type) ends where \(following.type) begins")
            }

            #expect(day.times[.isha]?.dateInterval.end == next.times[.fajr]?.dateInterval.start, "Isha ends at the next Fajr")
        }
    }
}

// MARK: - Fixtures

/// A place, a method and a first calendar day, chosen for the edge it exercises.
struct DayFixture: Sendable, CustomTestStringConvertible {
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String
    let method: CalculationMethod
    let adjustments: PrayerAdjustments?
    let year: Int
    let month: Int
    let day: Int

    var testDescription: String { name }

    init(
        _ name: String,
        _ latitude: Double,
        _ longitude: Double,
        _ timeZoneIdentifier: String,
        _ method: CalculationMethod,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        adjustments: PrayerAdjustments? = nil
    ) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.method = method
        self.adjustments = adjustments
        self.year = year
        self.month = month
        self.day = day
    }

    func request() throws -> PrayerAPI.Request {
        PrayerAPI.Request(
            coordinates: Coordinates(latitude: latitude, longitude: longitude),
            timeZone: try #require(TimeZone(identifier: timeZoneIdentifier)),
            method: method,
            adjustments: adjustments
        )
    }

    func calendar() throws -> Calendar {
        Calendar(identifier: .gregorian, timeZone: try request().timeZone)
    }

    /// Noon on the fixture's first day, in the place's zone.
    func firstNoon() throws -> Date {
        try #require(try calendar().date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    /// The calendar days from the fixture's first, each fetched on its own.
    func days(_ count: Int, using prayerManager: PrayerManager) async throws -> [PrayerDay] {
        let request = try request()
        let calendar = try calendar()
        let noon = try firstNoon()
        var days = [PrayerDay]()

        for offset in 0..<count {
            let date = try #require(calendar.date(byAdding: .day, value: offset, to: noon))
            days.append(try await prayerManager.fetch(for: date, with: request))
        }

        return days
    }
}

extension DayFixture {
    static let all: [DayFixture] = [
        DayFixture("Toronto in winter", 43.6510, -79.3470, "America/Toronto", .northAmerica, 2021, 1, 2),
        DayFixture("San Francisco in June", 37.773972, -122.431297, "America/Los_Angeles", .northAmerica, 2019, 6, 14),
        DayFixture("Paris on France 18, Isha after midnight", 48.8566, 2.3522, "Europe/Paris", .france18, 2026, 6, 20),
        DayFixture("Reykjavik, Maghrib after midnight", 64.1466, -21.9426, "Atlantic/Reykjavik", .moonsightingCommittee, 2026, 6, 20),
        DayFixture("A Coruña, Isha after midnight", 43.3623, -8.4115, "Europe/Madrid", .muslimWorldLeague, 2026, 7, 4),
        DayFixture("Makkah in Ramadan, Isha 30 minutes later", 21.4225, 39.8262, "Asia/Riyadh", .ummAlQuraRamadan, 2026, 3, 1),
        DayFixture(
            "Kuala Lumpur, Isha 60 minutes after Maghrib", 3.1390, 101.6869, "Asia/Kuala_Lumpur", .jakim, 2026, 10, 12,
            adjustments: .relative(isha: 60)
        ),
        DayFixture(
            "Kuala Lumpur, Isha 120 minutes after Maghrib", 3.1390, 101.6869, "Asia/Kuala_Lumpur", .jakim, 2026, 10, 12,
            adjustments: .relative(isha: 120)
        ),
        DayFixture(
            "Toronto, Fajr 90 minutes before sunrise", 43.6510, -79.3470, "America/Toronto", .moonsightingCommittee, 2026, 10, 12,
            adjustments: .relative(fajr: -90)
        ),
        DayFixture("London timetable", 51.5074, -0.1278, "Europe/London", .london, 2022, 2, 25),
        DayFixture(
            "London timetable, Fajr 90 minutes before a later sunrise", 51.5074, -0.1278, "Europe/London", .london, 2022, 2, 25,
            adjustments: .relative(fajr: -90, sunrise: 3)
        ),
        DayFixture("Sydney in winter", -33.8688, 151.2093, "Australia/Sydney", .muslimWorldLeague, 2026, 6, 20),
        DayFixture("Tokyo", 35.6762, 139.6503, "Asia/Tokyo", .muslimWorldLeague, 2026, 10, 12),
        DayFixture("New York, clocks forward", 40.7128, -74.0060, "America/New_York", .northAmerica, 2026, 3, 7),
        DayFixture("New York, clocks back", 40.7128, -74.0060, "America/New_York", .northAmerica, 2026, 10, 31),
        DayFixture("Kuala Lumpur", 3.1390, 101.6869, "Asia/Kuala_Lumpur", .jakim, 2026, 10, 12)
    ]
}

private extension PrayerAdjustments {
    static func relative(fajr: Int = 0, sunrise: Int = 0, isha: Int = 0) -> PrayerAdjustments {
        PrayerAdjustments(
            fajr: fajr,
            sunrise: sunrise,
            dhuhr: 0,
            asr: 0,
            maghrib: 0,
            isha: isha,
            isFajrSunriseRelative: fajr != 0,
            isIshaMaghribRelative: isha != 0,
            elevation: nil
        )
    }
}
