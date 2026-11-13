//
//  PrayerTimetableSourceLondonTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
@testable import PrayServices
import Testing

/// London's own part of its timetable: how a response from londonprayertimes.com reads.
struct PrayerTimetableSourceLondonTests {
    private let source = PrayerTimetableSourceLondon(apiKey: "")
}

extension PrayerTimetableSourceLondonTests {
    @Test
    func everyBundledYearReadsInFull() throws {
        // Given
        let london = try #require(PrayerTimetableStore.bundledDirectory).appending(path: "london")
        let files = try FileManager.default.contentsOfDirectory(at: london, includingPropertiesForKeys: nil)
        let calendar = Calendar(identifier: .gregorian)

        // Then
        #expect(files.count >= 5)

        try files.forEach { file in
            let year = try #require(Int(file.deletingPathExtension().lastPathComponent))
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
        let days = try source.days(from: Data(Self.response(asr2: "14:17").utf8))

        // Then
        let day = try #require(days[TimetableDate(year: 2031, month: 1, day: 1)])
        #expect(day.asr == TimetableClock(hour: 13, minute: 46))
        #expect(day.asrHanafi == TimetableClock(hour: 14, minute: 17))
        #expect(day.maghrib == TimetableClock(hour: 16, minute: 5))
    }

    @Test
    func aDayWithATimeThatCantBeReadIsLeftOut() throws {
        // When
        let days = try source.days(from: Data(Self.response(fajr: "6.26").utf8))

        // Then
        #expect(days.keys.map(\.day) == [2])
    }

    @Test
    func aYearNotYetPublishedHasNoDays() throws {
        #expect(try source.days(from: Data(#"{"city":"london","times":{}}"#.utf8)).isEmpty)
    }
}

// MARK: - Helpers

private extension PrayerTimetableSourceLondonTests {
    /// Two days as the API writes them, the first with the given Fajr and second Asr.
    static func response(fajr: String = "06:26", asr2: String = "14:17") -> String {
        #"""
        {"city":"london","times":{"2031-01-01":{"date":"2031-01-01",
        "fajr":"\#(fajr)","fajr_jamat":"06:46","sunrise":"08:03","dhuhr":"12:09","dhuhr_jamat":"12:45",
        "asr":"13:46","asr_2":"\#(asr2)","asr_jamat":"14:45","magrib":"16:05","magrib_jamat":"16:12",
        "isha":"17:42","isha_jamat":"19:30"},
        "2031-01-02":{"date":"2031-01-02",
        "fajr":"06:26","fajr_jamat":"06:46","sunrise":"08:03","dhuhr":"12:10","dhuhr_jamat":"12:45",
        "asr":"13:47","asr_2":"14:18","asr_jamat":"14:45","magrib":"16:06","magrib_jamat":"16:13",
        "isha":"17:43","isha_jamat":"19:30"}}}
        """#
    }
}
