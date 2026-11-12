//
//  SettingsHijriTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing
import ZamzamCore

struct SettingsHijriTests {
    private let fixture = PrayTestFixture()
}

extension SettingsHijriTests {
    /// Every face used to pass the settings' two Hijri values to `Date.hijriDayOffset(for:)` and the offset to
    /// ZamzamKit's `hijriString`. The one function they call now writes the same string, around Maghrib, midnight
    /// and the next Fajr, for the day holding the moment and for days that don't.
    @Test(arguments: DayFixture.all)
    func hijriStringWritesWhatItsCallersSpelledOut(place: DayFixture) async throws {
        let timeZone = try place.request().timeZone
        let calendar = try place.calendar()
        let days = try await place.days(3, using: fixture.prayerManager)
        let day = try #require(days.first)
        let maghrib = try #require(day.times[.maghrib]).dateInterval.start
        let nextFajr = try #require(day.times[.isha]).dateInterval.end
        let midnight = try #require(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: try place.firstNoon())))
        let moments = [maghrib - 1800, maghrib - 1, maghrib, maghrib + 1800, midnight - 1, midnight, midnight + 1800, nextFajr - 1, nextFajr + 1800]
        let inputs = moments.flatMap { moment in days.map { Input(moment: moment, prayerDay: $0) } }

        let comparisons = inputs.flatMap { input in
            Self.settingsRows.flatMap { settings in
                Self.formats.map { format in
                    Comparison(
                        written: settings.hijriString(at: input.moment, in: input.prayerDay, timeZone: timeZone, template: format.template, locale: format.locale),
                        spelledOut: input.moment.hijriString(
                            template: format.template,
                            offset: input.moment.hijriDayOffset(
                                for: input.prayerDay,
                                hijriDayOffset: settings.hijriDayOffset,
                                autoIncrementHijri: settings.autoIncrementHijri,
                                timeZone: timeZone
                            ),
                            timeZone: timeZone,
                            locale: format.locale
                        ),
                        label: "\(input.moment) in the day of \(input.prayerDay.date), \(settings.hijriDayOffset) \(settings.autoIncrementHijri) \(format.template) \(format.locale.identifier)"
                    )
                }
            }
        }

        let mismatches = comparisons.filter { $0.written != $0.spelledOut }
        #expect(comparisons.count == 1_296)
        #expect(mismatches.isEmpty, "first of \(mismatches.count): \(mismatches.prefix(3))")
    }

    /// The sweep above proves nothing unless it crosses the Maghrib turn: with auto-increment the date is a day on
    /// from the plain offset's on one side of Maghrib and not the other.
    @Test(arguments: DayFixture.all)
    func theSweepCrossesTheMaghribTurn(place: DayFixture) async throws {
        let timeZone = try place.request().timeZone
        let day = try #require(try await place.days(1, using: fixture.prayerManager).first)
        let maghrib = try #require(day.times[.maghrib]).dateInterval.start
        let locale = Locale(identifier: "en_US")
        let turns = { (moment: Date) in
            Self.settings(offset: 0, autoIncrement: true).hijriString(at: moment, in: day, timeZone: timeZone, locale: locale)
                != Self.settings(offset: 0, autoIncrement: false).hijriString(at: moment, in: day, timeZone: timeZone, locale: locale)
        }

        #expect(turns(maghrib - 1) != turns(maghrib))
    }

    /// The faces that read day first spelled it out as the day and then the month, from two calls. The one function
    /// they call now writes the same string either side of Maghrib.
    @Test(arguments: DayFixture.all)
    func hijriDayAndMonthWritesWhatTheDayFirstFacesSpelledOut(place: DayFixture) async throws {
        let timeZone = try place.request().timeZone
        let day = try #require(try await place.days(1, using: fixture.prayerManager).first)
        let maghrib = try #require(day.times[.maghrib]).dateInterval.start

        let comparisons = [maghrib - 1, maghrib].flatMap { moment in
            Self.settingsRows.flatMap { settings in
                ["en_US", "ar_SA"].map(Locale.init(identifier:)).map { locale in
                    Comparison(
                        written: settings.hijriDayAndMonth(at: moment, in: day, timeZone: timeZone, locale: locale),
                        spelledOut: ["d", "MMM"]
                            .map { settings.hijriString(at: moment, in: day, timeZone: timeZone, template: $0, locale: locale) }
                            .joined(separator: " "),
                        label: "\(moment), \(settings.hijriDayOffset) \(settings.autoIncrementHijri) \(locale.identifier)"
                    )
                }
            }
        }

        let mismatches = comparisons.filter { $0.written != $0.spelledOut }
        #expect(comparisons.count == 24)
        #expect(mismatches.isEmpty, "first of \(mismatches.count): \(mismatches.prefix(3))")
    }
}

// MARK: - Types

private extension SettingsHijriTests {
    struct Input {
        let moment: Date
        let prayerDay: PrayerDay
    }

    struct Format {
        let template: String
        let locale: Locale
    }

    struct Comparison: CustomStringConvertible {
        let written: String
        let spelledOut: String
        let label: String

        var description: String { "\(label): \(written) vs \(spelledOut)" }
    }

    static let settingsRows: [Settings] = [true, false].flatMap { autoIncrement in
        [-1, 0, 1].map { settings(offset: $0, autoIncrement: autoIncrement) }
    }

    static let formats: [Format] = ["yyyyMMMMd", "MMMd", "MMM", "d"].flatMap { template in
        ["en_US", "ar_SA"].map { Format(template: template, locale: Locale(identifier: $0)) }
    }

    static func settings(offset: Int, autoIncrement: Bool) -> Settings {
        var settings = Settings()
        settings.hijriDayOffset = offset
        settings.autoIncrementHijri = autoIncrement
        return settings
    }
}
