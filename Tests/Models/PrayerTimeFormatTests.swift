//
//  PrayerTimeFormatTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing
import ZamzamCore

struct PrayerTimeFormatTests {}

// MARK: - Equivalence

extension PrayerTimeFormatTests {
    @Test(arguments: localeIdentifiers)
    func aLocaleWritesEveryTimeAsTheFormattersReplacedWroteItApartFromTheSpaceAHiddenPeriodLeft(identifier: String) throws {
        let differences = try differences(locale: Locale(identifier: identifier))
        #expect(differences.isEmpty, "\(differences.joined(separator: "\n"))")
    }

    /// The app passes no locale, and the formatters replaced never set one.
    @Test
    func withoutALocaleEveryTimeIsWrittenAsTheFormattersReplacedWroteItOnThisDeviceApartFromThatSpace() throws {
        let differences = try differences(locale: nil)
        #expect(differences.isEmpty, "\(differences.joined(separator: "\n"))")
    }
}

// MARK: - Literals

extension PrayerTimeFormatTests {
    @Test(arguments: [
        Written(locale: "en_US", twentyFourHour: "15:43", twelveHour: "3:43\u{202F}PM", withoutPeriod: "3:43"),
        Written(locale: "en_GB", twentyFourHour: "15:43", twelveHour: "3:43\u{202F}pm", withoutPeriod: "3:43"),
        Written(locale: "fr_FR", twentyFourHour: "15:43", twelveHour: "3:43\u{202F}PM", withoutPeriod: "3:43"),
        Written(locale: "ar_SA", twentyFourHour: "١٥:٤٣", twelveHour: "٣:٤٣\u{A0}م", withoutPeriod: "٣:٤٣"),
        Written(locale: "tr_TR", twentyFourHour: "15:43", twelveHour: "ÖS\u{202F}3:43", withoutPeriod: "3:43"),
        Written(locale: "ja_JP", twentyFourHour: "15:43", twelveHour: "午後3:43", withoutPeriod: "3:43"),
        // Chinese writes a time of day (下午, afternoon) in place of AM and PM, which hiding the period leaves
        Written(locale: "zh_CN", twentyFourHour: "15:43", twelveHour: "下午3:43", withoutPeriod: "下午3:43")
    ])
    func aTimeIsWrittenAsItsLocaleWritesOne(written: Written) throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let locale = Locale(identifier: written.locale)
        let date = try date(hour: 15, minute: 43, in: timeZone)

        #expect(DateFormatter.prayerTime(is24Hour: true, using: timeZone, locale: locale).string(from: date) == written.twentyFourHour)
        #expect(DateFormatter.prayerTime(is24Hour: true, showsPeriod: false, using: timeZone, locale: locale).string(from: date) == written.twentyFourHour)
        #expect(DateFormatter.prayerTime(is24Hour: false, using: timeZone, locale: locale).string(from: date) == written.twelveHour)
        #expect(DateFormatter.prayerTime(is24Hour: false, showsPeriod: false, using: timeZone, locale: locale).string(from: date) == written.withoutPeriod)
    }

    /// The narrow no-break space (U+202F) US English writes before AM and PM goes with them.
    @Test
    func aUSEnglishTimeWithoutItsPeriodIsItsHourAndMinuteAlone() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let formatter = DateFormatter.prayerTime(is24Hour: false, showsPeriod: false, using: timeZone, locale: Locale(identifier: "en_US"))
        let morning = try date(hour: 8, minute: 0, in: timeZone)
        let noon = try date(hour: 12, minute: 0, in: timeZone)
        let midnight = try date(hour: 0, minute: 0, in: timeZone)

        #expect(formatter.string(from: morning) == "8:00")
        #expect(formatter.string(from: noon) == "12:00")
        #expect(formatter.string(from: midnight) == "12:00")
    }
}

// MARK: - Types

extension PrayerTimeFormatTests {
    struct Written: Sendable, CustomTestStringConvertible {
        let locale: String
        let twentyFourHour: String
        let twelveHour: String
        let withoutPeriod: String

        var testDescription: String { locale }
    }

    /// Each way a call site asks for a time, beside the formatter that wrote it before `prayerTime`.
    private enum Mode: CaseIterable {
        case twentyFourHour
        case twentyFourHourWithoutPeriod
        case twelveHour
        case twelveHourWithoutPeriod

        func formatter(using timeZone: TimeZone, locale: Locale?) -> DateFormatter {
            let is24Hour = self == .twentyFourHour || self == .twentyFourHourWithoutPeriod
            let showsPeriod = self == .twentyFourHour || self == .twelveHour

            guard let locale else { return .prayerTime(is24Hour: is24Hour, showsPeriod: showsPeriod, using: timeZone) }
            return .prayerTime(is24Hour: is24Hour, showsPeriod: showsPeriod, using: timeZone, locale: locale)
        }

        func replacedFormatter(using timeZone: TimeZone, locale: Locale?) -> DateFormatter {
            switch self {
            case .twentyFourHour, .twentyFourHourWithoutPeriod: .time24Hrs(using: timeZone, locale: locale)
            case .twelveHour: .timeAMPM(using: timeZone, locale: locale)
            case .twelveHourWithoutPeriod: .timeShort(using: timeZone, locale: locale)
            }
        }

        /// What `prayerTime` writes for a string of the formatter it replaced: the same string, except that a 12-hour
        /// time without its period has none of the whitespace that formatter left where it blanked AM and PM.
        func expected(from replaced: String) -> String {
            self == .twelveHourWithoutPeriod ? replaced.trimmingCharacters(in: .whitespacesAndNewlines) : replaced
        }
    }
}

// MARK: - Helpers

private extension PrayerTimeFormatTests {
    static let localeIdentifiers = Locale.availableIdentifiers.sorted()
    static let timeZoneIdentifiers = ["UTC", "America/Los_Angeles", "Asia/Kuala_Lumpur", "Asia/Kathmandu", "Pacific/Auckland"]

    /// A morning, noon exactly, an afternoon, midnight exactly and the day's last minute, on each time zone's own clock.
    static let clockTimes = [(hour: 5, minute: 7), (hour: 12, minute: 0), (hour: 15, minute: 43), (hour: 0, minute: 0), (hour: 23, minute: 59)]

    /// Every string `prayerTime` writes differently from what the formatter it replaced gives (`Mode.expected`), over
    /// the time zones, clock times and modes. A `nil` locale leaves both on the device's.
    func differences(locale: Locale?) throws -> [String] {
        try Self.timeZoneIdentifiers.flatMap { identifier in
            let timeZone = try #require(TimeZone(identifier: identifier))
            let dates = try Self.clockTimes.map { try date(hour: $0.hour, minute: $0.minute, in: timeZone) }

            return Mode.allCases.flatMap { mode in
                let formatter = mode.formatter(using: timeZone, locale: locale)
                let replaced = mode.replacedFormatter(using: timeZone, locale: locale)

                return dates.compactMap { date in
                    let written = formatter.string(from: date)
                    let expected = mode.expected(from: replaced.string(from: date))
                    return written == expected ? nil : "\(mode) in \(identifier): \(written.debugDescription) was \(expected.debugDescription)"
                }
            }
        }
    }

    func date(hour: Int, minute: Int, in timeZone: TimeZone) throws -> Date {
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        return try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: hour, minute: minute)))
    }
}

/// The three formatters `prayerTime` replaced, with their bodies as they were. The locale stands in for the device's,
/// which was the only one they wrote in.
private extension DateFormatter {
    static func time24Hrs(using timeZone: TimeZone, locale: Locale?) -> DateFormatter {
        DateFormatter(dateFormatTemplate: "Hmm", timeZone: timeZone, locale: locale)
    }

    static func timeShort(using timeZone: TimeZone, locale: Locale?) -> DateFormatter {
        DateFormatter(dateFormatTemplate: "hmm", timeZone: timeZone, locale: locale).apply {
            $0.amSymbol = ""
            $0.pmSymbol = ""
        }
    }

    static func timeAMPM(using timeZone: TimeZone, locale: Locale?) -> DateFormatter {
        DateFormatter(dateFormatTemplate: "hmm", timeZone: timeZone, locale: locale)
    }
}
