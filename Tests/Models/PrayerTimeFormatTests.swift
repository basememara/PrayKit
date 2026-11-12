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
}

// MARK: - Helpers

private extension PrayerTimeFormatTests {
    func date(hour: Int, minute: Int, in timeZone: TimeZone) throws -> Date {
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        return try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: hour, minute: minute)))
    }
}
