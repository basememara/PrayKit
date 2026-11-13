//
//  PrayerTimetableSourceLondonTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
@testable import PrayServices
import Testing

/// London's own part of its timetable: how a table is asked for and how a response from londonprayertimes.com reads.
struct PrayerTimetableSourceLondonTests {
    private let source = PrayerTimetableSourceLondon(apiKey: "abc-123_XYZ")
}

extension PrayerTimetableSourceLondonTests {
    @Test
    func aTableIsAskedForWithTheKeyAndTheYear() {
        // When
        let request = source.urlRequest(for: PrayerTimetable(start: TimetableDate(year: 2019, month: 1, day: 1), zone: nil))

        // Then
        #expect(request.url?.absoluteString == "https://www.londonprayertimes.com/api/times/?key=abc-123_XYZ&year=2019&24hours=true&format=json")
    }

    @Test
    func everyBundledYearReadsInFull() throws {
        // Given
        let years = try bundledLondonYears()
        let calendar = Calendar(identifier: .gregorian)

        // Then
        #expect(years.count >= 5)

        try years.forEach { year, file in
            let newYear = try #require(calendar.date(from: DateComponents(year: year)))
            let daysInYear = try #require(calendar.range(of: .day, in: .year, for: newYear)).count

            // When
            let days = try source.days(from: Data(contentsOf: file))

            // Then
            #expect(days.count == daysInYear, "\(year)")
            #expect(days.keys.allSatisfy { $0.year == year }, "\(year)")
        }
    }

    @Test
    func theSecondAsrIsTheHanafiOne() throws {
        // When
        let days = try source.days(from: Data(LondonJSON.response([LondonJSON.day("2031-01-01")]).utf8))

        // Then
        let day = try #require(days[TimetableDate(year: 2031, month: 1, day: 1)])
        #expect(day.asr == TimetableClock(hour: 13, minute: 46))
        #expect(day.asrHanafi == TimetableClock(hour: 14, minute: 17))
        #expect(day.maghrib == TimetableClock(hour: 16, minute: 5))
    }

    @Test
    func aDayWithATimeThatCantBeReadIsLeftOut() throws {
        // When
        let response = LondonJSON.response([LondonJSON.day("2031-01-01", fajr: "6.26"), LondonJSON.day("2031-01-02")])
        let days = try source.days(from: Data(response.utf8))

        // Then
        #expect(days.keys.map(\.day) == [2])
    }

    @Test
    func aYearNotYetPublishedHasNoDays() throws {
        #expect(try source.days(from: Data(LondonJSON.unpublished.utf8)).isEmpty)
    }
}

// MARK: - London fixtures

/// The years of London's timetable the package ships, each with its file.
func bundledLondonYears() throws -> [Int: URL] {
    let folder = try #require(PrayerTimetableStore.bundledDirectory).appending(path: "london")

    return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        .reduce(into: [:]) { years, file in
            guard let year = Int(file.deletingPathExtension().lastPathComponent) else { return }
            years[year] = file
        }
}

/// Responses as the London Prayer Times API writes them.
enum LondonJSON {
    /// How the API answers a year it hasn't published.
    static let unpublished = #"{"city":"london","times":{}}"#

    static func response(_ days: [String]) -> String {
        #"{"city":"london","times":{\#(days.joined(separator: ","))}}"#
    }

    /// One day, `yyyy-MM-dd`, with the same times every day but Fajr.
    static func day(_ date: String, fajr: String = "06:26") -> String {
        #"""
        "\#(date)":{"date":"\#(date)",
        "fajr":"\#(fajr)","fajr_jamat":"06:46","sunrise":"08:03","dhuhr":"12:09","dhuhr_jamat":"12:45",
        "asr":"13:46","asr_2":"14:17","asr_jamat":"14:45","magrib":"16:05","magrib_jamat":"16:12",
        "isha":"17:42","isha_jamat":"19:30"}
        """#
    }
}
