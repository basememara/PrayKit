//
//  ManualMethod.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-11-09.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

/// A calculation method picked by hand, which a new place never replaces without asking.
public struct ManualMethod: Codable, Equatable, Sendable {
    /// Where the user kept it over the one most mosques there use: time zone identifiers, split by method where a city's
    /// timetable stops holding (`CalculationMethod.area(at:)`).
    public internal(set) var keptTimeZones: Set<String>

    public init(keptTimeZones: Set<String>) {
        self.keptTimeZones = keptTimeZones
    }

    // Sorted, so two devices encode the same value alike and break a merge tie the same way
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keptTimeZones.sorted(), forKey: .keptTimeZones)
    }
}
