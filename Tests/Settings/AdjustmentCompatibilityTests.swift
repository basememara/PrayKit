//
//  AdjustmentCompatibilityTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-25.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

/// Whatever adjustments a user saved, in any app version, keep their prayer times now that a relative Fajr or Isha
/// is read from its minutes: only a relative choice saved with zero minutes reads differently, and the engine gave
/// it the method's own time either way.
struct AdjustmentCompatibilityTests {
    private let fixture = PrayTestFixture()
    private static let minutes = [-300, -90, -1, 0, 1, 2, 90]

    @Test(arguments: [
        CalculationPlace(latitude: 3.1390, longitude: 101.6869, timeZone: "Asia/Kuala_Lumpur", method: .jakim),
        CalculationPlace(latitude: 51.5074, longitude: -0.1278, timeZone: "Europe/London", method: .muslimWorldLeague)
    ])
    func everySavedAdjustmentCalculatesTheSameTimesAsBefore(place: CalculationPlace) async throws {
        let timeZone = try #require(TimeZone(identifier: place.timeZone))
        let date = try #require(Calendar(identifier: .gregorian, timeZone: timeZone).date(from: DateComponents(year: 2026, month: 3, day: 21, hour: 12)))

        for fajr in Self.minutes {
            for isha in Self.minutes {
                for isFajrRelative in [false, true] {
                    for isIshaRelative in [false, true] {
                        let saved = AdjustmentMinutes(rawValue: [
                            "fajr": fajr,
                            "isha": isha,
                            "is_fajr_sunrise_relative": isFajrRelative ? 1 : 0,
                            "is_isha_maghrib_relative": isIshaRelative ? 1 : 0
                        ])

                        // As every version read it before: the saved flag alone
                        let before = PrayerAdjustments(
                            fajr: fajr,
                            sunrise: 0,
                            dhuhr: 0,
                            asr: 0,
                            maghrib: 0,
                            isha: isha,
                            isFajrSunriseRelative: isFajrRelative,
                            isIshaMaghribRelative: isIshaRelative,
                            elevation: nil
                        )
                        let now = PrayerAdjustments(adjustmentMinutes: saved, adjustmentElevation: nil)
                        let label = "fajr \(fajr) relative \(isFajrRelative), isha \(isha) relative \(isIshaRelative)"

                        #expect(now.isFajrSunriseRelative == (isFajrRelative && fajr != 0), "\(label)")
                        #expect(now.isIshaMaghribRelative == (isIshaRelative && isha != 0), "\(label)")
                        let timesNow = await times(at: date, in: place, timeZone: timeZone, adjustments: now)
                        let timesBefore = await times(at: date, in: place, timeZone: timeZone, adjustments: before)
                        #expect(timesNow == timesBefore, "\(label)")
                    }
                }
            }
        }
    }
}

extension AdjustmentCompatibilityTests {
    @Test
    func aRelativeIshaBeforeMaghribKeepsTheMethodsIsha() async throws {
        // No version could save one, but a day that can't be laid out would trap rather than throw
        let place = CalculationPlace(latitude: 3.1390, longitude: 101.6869, timeZone: "Asia/Kuala_Lumpur", method: .jakim)
        let timeZone = try #require(TimeZone(identifier: place.timeZone))
        let date = try #require(Calendar(identifier: .gregorian, timeZone: timeZone).date(from: DateComponents(year: 2026, month: 3, day: 21, hour: 12)))
        let beforeMaghrib = PrayerAdjustments(fajr: 0, sunrise: 0, dhuhr: 0, asr: 0, maghrib: 0, isha: -30, isFajrSunriseRelative: false, isIshaMaghribRelative: true, elevation: nil)
        let none = PrayerAdjustments(adjustmentMinutes: nil, adjustmentElevation: nil)

        let timesBeforeMaghrib = await times(at: date, in: place, timeZone: timeZone, adjustments: beforeMaghrib)
        let timesWithNone = await times(at: date, in: place, timeZone: timeZone, adjustments: none)
        #expect(timesBeforeMaghrib == timesWithNone)
    }
}

// MARK: - Helpers

struct CalculationPlace: Sendable, CustomTestStringConvertible {
    let latitude: Double
    let longitude: Double
    let timeZone: String
    let method: CalculationMethod

    var testDescription: String { timeZone }
}

private extension AdjustmentCompatibilityTests {
    /// The day's times, or the error when the adjustments leave the day impossible, so failures compare too.
    func times(at date: Date, in place: CalculationPlace, timeZone: TimeZone, adjustments: PrayerAdjustments) async -> String {
        let request = PrayerAPI.Request(
            coordinates: Coordinates(latitude: place.latitude, longitude: place.longitude),
            timeZone: timeZone,
            method: place.method,
            adjustments: adjustments
        )

        do {
            let day = try await fixture.prayerManager.fetch(for: date, with: request)
            return day.times.map { "\($0.type) \($0.dateInterval.start.timeIntervalSince1970)" }.joined(separator: ", ")
        } catch {
            return "\(error)"
        }
    }
}
