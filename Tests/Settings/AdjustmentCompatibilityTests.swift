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

    private static let places = [
        DayFixture("Kuala Lumpur", 3.1390, 101.6869, "Asia/Kuala_Lumpur", .jakim, 2026, 3, 21),
        DayFixture("London", 51.5074, -0.1278, "Europe/London", .muslimWorldLeague, 2026, 3, 21)
    ]

    /// Every Fajr and Isha a user may have saved: either side of zero, zero itself, relative or not.
    private static let saved: [AdjustmentMinutes] = {
        let minutes = [-300, -90, -1, 0, 1, 2, 90]
        return minutes.flatMap { fajr in
            minutes.flatMap { isha in
                [0, 1].flatMap { isFajrRelative in
                    [0, 1].map { isIshaRelative in
                        AdjustmentMinutes(rawValue: [
                            "fajr": fajr,
                            "isha": isha,
                            "is_fajr_sunrise_relative": isFajrRelative,
                            "is_isha_maghrib_relative": isIshaRelative
                        ])
                    }
                }
            }
        }
    }()

    @Test(arguments: places, saved)
    func everySavedAdjustmentCalculatesTheSameTimesAsBefore(place: DayFixture, saved: AdjustmentMinutes) async throws {
        // As every version read it before: the saved flag alone
        let before = PrayerAdjustments.saved(
            fajr: saved[.fajr],
            isha: saved[.isha],
            isFajrRelative: saved.rawValue["is_fajr_sunrise_relative"] == 1,
            isIshaRelative: saved.rawValue["is_isha_maghrib_relative"] == 1
        )
        let now = PrayerAdjustments(adjustmentMinutes: saved, adjustmentElevation: nil)

        #expect(try await times(in: place, adjustments: now) == times(in: place, adjustments: before))
    }

    @Test
    func aRelativeIshaBeforeMaghribKeepsTheMethodsIsha() async throws {
        // No version could save one, but a day that can't be laid out would trap rather than throw
        let place = Self.places[0]
        #expect(try await times(in: place, adjustments: .relative(isha: -30)) == times(in: place, adjustments: nil))
    }
}

// MARK: - Helpers

private extension AdjustmentCompatibilityTests {
    /// The day's times, or why it couldn't be calculated, so a day both readings reject compares equal.
    func times(in place: DayFixture, adjustments: PrayerAdjustments?) async throws -> Result<[PrayerTime], DescribedError> {
        let request = try DayFixture(
            place.name,
            place.latitude,
            place.longitude,
            place.timeZoneIdentifier,
            place.method,
            place.year,
            place.month,
            place.day,
            adjustments: adjustments
        ).request()

        do {
            return .success(try await fixture.prayerManager.fetch(for: try place.firstNoon(), with: request).times)
        } catch {
            return .failure(DescribedError(description: "\(error)"))
        }
    }
}

/// An error compared by what it says, since PrayError carries an underlying error and isn't Equatable.
private struct DescribedError: Error, Equatable {
    let description: String
}

private extension PrayerAdjustments {
    static func saved(fajr: Int, isha: Int, isFajrRelative: Bool, isIshaRelative: Bool) -> PrayerAdjustments {
        PrayerAdjustments(
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
    }
}
