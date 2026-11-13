//
//  PrayerServiceLondonTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices
import Testing
import ZamzamCore

/// The timetable is bundled a year at a time. A year past the bundle, and Dec 31 of the last bundled year (which needs the
/// next year's first Fajr), come from the API, which answers a year it hasn't published yet with a timetable of no days.
///
/// The parsed timetables are cached for the whole process, so each test reads years no other test loads.
struct PrayerServiceLondonTests {
    private let log = LogManager(services: [LogServiceConsole(minLevel: .none, subsystem: "PrayKitTests")])
}

extension PrayerServiceLondonTests {
    @Test
    func aSavedEmptyYearNeverHidesTheBundledOne() async throws {
        // Given
        let year = try #require(PrayerServiceLondon.lastYear) - 1
        let place = london(year)
        let defaults = UserDefaults.makeTest()
        defaults.set(Data(TimetableAPI.unpublished.utf8), forKey: PrayerServiceLondon.cacheKey(forYear: year))
        let service = PrayerServiceLondon(networkManager: NetworkManager(service: TimetableAPI()), apiKey: "", log: log, defaults: defaults)

        // When
        let times = try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())

        // Then
        #expect(times.contains { $0.type == .fajr })
        #expect(times.contains { $0.type == .isha })
    }

    @Test
    func anUnpublishedYearIsAskedForAgainOnceItIsOut() async throws {
        // Given
        let lastYear = try #require(PrayerServiceLondon.lastYear)
        let place = london(lastYear)
        let api = TimetableAPI()
        let defaults = UserDefaults.makeTest()
        defaults.set(Data(TimetableAPI.unpublished.utf8), forKey: PrayerServiceLondon.cacheKey(forYear: lastYear + 1))
        let service = PrayerServiceLondon(networkManager: NetworkManager(service: api), apiKey: "", log: log, defaults: defaults)
        let yearsEnd = try place.date(lastYear, 12, 31)

        // When
        await #expect(throws: PrayError.self) {
            try await service.calculate(for: yearsEnd, using: try place.calendar(), with: try place.request())
        }

        // Then
        #expect(defaults.object(forKey: PrayerServiceLondon.cacheKey(forYear: lastYear + 1)) == nil, "A year with no days must not stay saved")

        // When
        await api.publish(lastYear + 1)
        let times = try await service.calculate(for: yearsEnd, using: try place.calendar(), with: try place.request())

        // Then
        let isha = try #require(times.first { $0.type == .isha })
        let nextFajr = try place.date(lastYear + 1, 1, 1, 6, 26)
        #expect(isha.dateInterval.end == nextFajr)
        #expect(defaults.object(forKey: PrayerServiceLondon.cacheKey(forYear: lastYear + 1)) != nil, "A published year is saved")
    }

    /// A year the app doesn't bundle yet comes from the API once it's published, so January never goes blank.
    @Test
    func aYearPastTheBundleIsFetchedOnceItIsOut() async throws {
        // Given
        let year = try #require(PrayerServiceLondon.lastYear) + 2
        let place = london(year)
        let api = TimetableAPI()
        let defaults = UserDefaults.makeTest()
        let service = PrayerServiceLondon(networkManager: NetworkManager(service: api), apiKey: "", log: log, defaults: defaults)
        let newYearsDay = try place.date(year, 1, 1, 12)

        // When
        await #expect(throws: PrayError.self) {
            try await service.calculate(for: newYearsDay, using: try place.calendar(), with: try place.request())
        }

        await api.publish(year)
        let times = try await service.calculate(for: newYearsDay, using: try place.calendar(), with: try place.request())

        // Then
        let fajr = try #require(times.first { $0.type == .fajr })
        #expect(fajr.dateInterval.start == (try place.date(year, 1, 1, 6, 26)))
        #expect(defaults.object(forKey: PrayerServiceLondon.cacheKey(forYear: year)) != nil, "The fetched year is saved")
    }

    @Test
    func aYearThatCantBeFetchedHasNoTimes() async throws {
        // Given
        let year = try #require(PrayerServiceLondon.lastYear) + 3
        let place = london(year)
        let service = PrayerServiceLondon(networkManager: NetworkManager(service: OfflineAPI()), apiKey: "", log: log, defaults: .makeTest())

        // When
        let error = await #expect(throws: PrayError.self) {
            try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())
        }

        // Then
        guard case .invalidTimes = error else {
            Issue.record("Expected invalid times, got \(String(describing: error))")
            return
        }
    }

    @Test
    func aYearThatIsNotBundledIsAskedForWithTheKeyAndTheYear() async throws {
        // Given
        let place = london(2019)
        let api = TimetableAPI()
        let service = PrayerServiceLondon(networkManager: NetworkManager(service: api), apiKey: "abc-123_XYZ", log: log, defaults: .makeTest())

        // When
        await #expect(throws: PrayError.self) {
            try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())
        }

        // Then
        #expect(await api.requestedURLs == ["https://www.londonprayertimes.com/api/times/?key=abc-123_XYZ&year=2019&24hours=true&format=json"])
    }
}

// MARK: - Helpers

private extension PrayerServiceLondonTests {
    func london(_ year: Int) -> DayFixture {
        DayFixture("London timetable", 51.5074, -0.1278, "Europe/London", .london, year, 6, 1)
    }
}

/// The London Prayer Times API: a year is empty until it is published, then holds its first day.
private actor TimetableAPI: NetworkService {
    static let unpublished = #"{"city":"london","times":{}}"#

    private var published: Int?
    private(set) var requestedURLs = [String]()

    func publish(_ year: Int) {
        published = year
    }

    func send(_ request: URLRequest) async throws -> NetworkResponse {
        requestedURLs.append(request.url?.absoluteString ?? "")

        let body = published.map { year in
            #"""
            {"city":"london","times":{"\#(year)-01-01":{"date":"\#(year)-01-01",
            "fajr":"06:26","fajr_jamat":"06:46","sunrise":"08:03","dhuhr":"12:09","dhuhr_jamat":"12:45",
            "asr":"13:46","asr_2":"14:17","asr_jamat":"14:45","magrib":"16:05","magrib_jamat":"16:12",
            "isha":"17:42","isha_jamat":"19:30"},
            "\#(year)-01-02":{"date":"\#(year)-01-02",
            "fajr":"06:26","fajr_jamat":"06:46","sunrise":"08:03","dhuhr":"12:10","dhuhr_jamat":"12:45",
            "asr":"13:47","asr_2":"14:18","asr_jamat":"14:45","magrib":"16:06","magrib_jamat":"16:13",
            "isha":"17:43","isha_jamat":"19:30"}}}
            """#
        } ?? Self.unpublished

        return NetworkResponse(data: Data(body.utf8), headers: [:], statusCode: 200, request: request, response: URLResponse())
    }
}

/// A device with no connection.
private struct OfflineAPI: NetworkService {
    func send(_ request: URLRequest) async throws -> NetworkResponse {
        throw URLError(.notConnectedToInternet)
    }
}
