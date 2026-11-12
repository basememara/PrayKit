//
//  DateHijriTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-09-17.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import PrayMocks
import Testing
import ZamzamCore

struct DateHijriTests {
    /// The Islamic day turns over at maghrib, but only until the location's own midnight, so the
    /// same-day check must use the prayer time zone rather than whatever the host machine is set to.
    @Test
    func autoIncrementFollowsTheLocationDay() throws {
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let noon = try #require(Date(year: 2022, month: 3, day: 16, hour: 12, calendar: calendar))
        let prayerDay = PrayerDay.mock(at: noon, calendar: calendar)

        let afterMaghrib = try #require(Date(year: 2022, month: 3, day: 16, hour: 21, calendar: calendar))
        let beforeMidnight = try #require(Date(year: 2022, month: 3, day: 16, hour: 23, minute: 59, calendar: calendar))
        let afterMidnight = try #require(Date(year: 2022, month: 3, day: 17, hour: 0, minute: 30, calendar: calendar))
        let beforeMaghrib = try #require(Date(year: 2022, month: 3, day: 16, hour: 18, calendar: calendar))

        #expect(afterMaghrib.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: true, timeZone: timeZone) == 3)
        #expect(beforeMidnight.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: true, timeZone: timeZone) == 3)
        #expect(afterMidnight.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: true, timeZone: timeZone) == 2)
        #expect(beforeMaghrib.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: true, timeZone: timeZone) == 2)
        #expect(afterMaghrib.hijriDayOffset(for: prayerDay, hijriDayOffset: 2, autoIncrementHijri: false, timeZone: timeZone) == 2)
    }
}

extension DateHijriTests {
    /// 27 Rajab 1448 reads day first whatever order the locale writes a date in, with the month as it stands alone.
    @Test(arguments: DayAndMonth.all)
    func theHijriDayComesBeforeItsMonth(expected: DayAndMonth) {
        let locale = Locale(identifier: expected.locale)

        #expect(Self.israMiraj.hijriDayAndMonth(timeZone: .gmt, locale: locale) == expected.abbreviated)
        #expect(Self.israMiraj.hijriDayAndMonth(month: .wide, timeZone: .gmt, locale: locale) == expected.wide)
    }

    @Test(arguments: DayAndMonth.twoWordMonth)
    func aTwoWordMonthWrapsOnlyAfterTheDay(expected: DayAndMonth) {
        let locale = Locale(identifier: expected.locale)

        #expect(Self.jumadaII.hijriDayAndMonth(timeZone: .gmt, locale: locale) == expected.abbreviated)
        #expect(Self.jumadaII.hijriDayAndMonth(month: .wide, timeZone: .gmt, locale: locale) == expected.wide)
    }

    /// Arabic and Turkish write the day first already, so through a Hijri year the day-first form is what their own
    /// day-and-month template writes, apart from the no-break spaces inside a month.
    @Test(arguments: ["ar_SA", "ar", "tr_TR"])
    func aDayFirstLocaleKeepsWhatItsOwnTemplateWrites(locale identifier: String) {
        let locale = Locale(identifier: identifier)
        let moved = (0..<355)
            .map { Self.israMiraj + Double($0) * 86_400 }
            .flatMap { day in
                [(HijriMonthWidth.abbreviated, "MMMd"), (.wide, "MMMMd")].compactMap { width, template in
                    let dayFirst = day.hijriDayAndMonth(month: width, timeZone: .gmt, locale: locale).replacing("\u{00A0}", with: " ")
                    let templated = day.hijriString(template: template, timeZone: .gmt, locale: locale)
                    return dayFirst == templated ? nil : "\(dayFirst) vs \(templated)"
                }
            }

        #expect(moved.isEmpty, "first of \(moved.count): \(moved.prefix(3))")
    }
}

// MARK: - Types

extension DateHijriTests {
    struct DayAndMonth: Sendable, CustomTestStringConvertible {
        let locale: String
        let abbreviated: String
        let wide: String

        var testDescription: String { locale }

        static let all = [
            DayAndMonth(locale: "en_US", abbreviated: "27 Raj.", wide: "27 Rajab"),
            DayAndMonth(locale: "en_GB", abbreviated: "27 Raj.", wide: "27 Rajab"),
            DayAndMonth(locale: "ar_SA", abbreviated: "٢٧ رجب", wide: "٢٧ رجب"),
            DayAndMonth(locale: "tr_TR", abbreviated: "27 Recep", wide: "27 Recep")
        ]

        static let twoWordMonth = [
            DayAndMonth(locale: "en_US", abbreviated: "1 Jum.\u{00A0}II", wide: "1 Jumada\u{00A0}II"),
            DayAndMonth(locale: "ar_SA", abbreviated: "١ جمادى\u{00A0}الآخرة", wide: "١ جمادى\u{00A0}الآخرة")
        ]
    }

    /// 5 January 2027 at noon UTC, 27 Rajab 1448.
    static let israMiraj = Date(timeIntervalSince1970: 1_799_150_400)

    static let jumadaII = Date(timeIntervalSince1970: 1_824_984_000)
}
