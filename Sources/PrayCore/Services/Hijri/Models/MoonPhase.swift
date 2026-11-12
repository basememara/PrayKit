//
//  MoonPhase.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-11-08.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

/// The moon on a day of the Hijri month, which begins with the new crescent.
public struct MoonPhase: Equatable, Sendable {
    private static let synodicMonth = 29.53

    /// Days since the new moon.
    private let age: Double

    public init(hijriDay: Int) {
        age = Double(hijriDay)
    }
}

public extension MoonPhase {
    /// The share of the disc lit, 0 at the new moon and 1 at the full moon.
    var illumination: Double {
        (1 - cos(2 * .pi * age / Self.synodicMonth)) / 2
    }

    /// Whether the lit side grows night to night, until the full moon.
    var isWaxing: Bool {
        age < Self.synodicMonth / 2
    }
}
