//
//  AdjustmentMinutes.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-06-06.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public struct AdjustmentMinutes: RawRepresentable, Equatable, Codable, Sendable {
    public var rawValue: [String: Int]

    /// Fajr counted back from sunrise, so its minutes can only be before it.
    public var isFajrSunriseRelative: Bool {
        get { (rawValue["is_fajr_sunrise_relative"] ?? 0) == 1 }
        set {
            rawValue["is_fajr_sunrise_relative"] = newValue ? 1 : 0
            if newValue, self[.fajr] > 0 { self[.fajr].negate() }
        }
    }

    /// Isha counted on from Maghrib, so its minutes can only be after it.
    public var isIshaMaghribRelative: Bool {
        get { (rawValue["is_isha_maghrib_relative"] ?? 0) == 1 }
        set {
            rawValue["is_isha_maghrib_relative"] = newValue ? 1 : 0
            if newValue, self[.isha] < 0 { self[.isha].negate() }
        }
    }

    public init(rawValue: [String: Int]) {
        self.rawValue = rawValue
    }

    public subscript(_ prayer: Prayer) -> Int {
        get { rawValue[prayer.rawValue] ?? 0 }
        set { rawValue[prayer.rawValue] = newValue }
    }

    /// The minutes a prayer may move: up to five hours on the relative side of Fajr and Isha, two hours otherwise.
    public func range(for prayer: Prayer) -> ClosedRange<Int> {
        switch prayer {
        case .fajr where isFajrSunriseRelative:
            -300...0
        case .isha where isIshaMaghribRelative:
            0...300
        default:
            -120...120
        }
    }

    public var isEmpty: Bool {
        rawValue
            .filter { !["is_fajr_sunrise_relative", "is_isha_maghrib_relative"].contains($0.key) }
            .allSatisfy { $0.value == 0 }
        || rawValue.isEmpty
    }
}
