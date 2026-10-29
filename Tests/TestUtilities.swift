//
//  TestUtilities.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore

extension UserDefaults {
    /// Returns a defaults suite private to the caller.
    ///
    /// Swift Testing builds a fresh suite instance for every test and runs tests in
    /// parallel, so each one gets its own store instead of sharing a process-wide
    /// suite that has to be reset between runs.
    static func makeTest() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString) ?? .standard
    }
}

/// A seeded generator, so a failing randomized case reproduces.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

extension PrayerTime {
    /// A synthetic day's essential prayers from `start`, each running until the next begins and Isha until the next
    /// day's Fajr, 29 hours in.
    static func day(from start: Date, ishaAt ishaHour: Double = 19.5) -> [PrayerTime] {
        let hours: [(Prayer, Double)] = [(.fajr, 5), (.sunrise, 6.5), (.dhuhr, 12), (.asr, 15.5), (.maghrib, 18), (.isha, ishaHour)]
        return hours.enumerated().map { index, entry in
            let end = index + 1 < hours.count ? hours[index + 1].1 : 29
            return PrayerTime(type: entry.0, dateInterval: DateInterval(start: start + entry.1 * 3600, end: start + end * 3600))
        }
    }
}
