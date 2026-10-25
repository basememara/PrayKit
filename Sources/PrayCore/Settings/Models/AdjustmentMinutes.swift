//
//  AdjustmentMinutes.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-06-06.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public struct AdjustmentMinutes: RawRepresentable, Equatable, Codable, Sendable {
    public var rawValue: [String: Int]

    /// Fajr counted back from sunrise, so its minutes are at least one before it; zero would leave fajr on its angle,
    /// so a choice saved without minutes reads as off, as the engine treats it. Turning it off puts fajr back on its method.
    public var isFajrSunriseRelative: Bool {
        get { rawValue["is_fajr_sunrise_relative"] == 1 && self[.fajr] < 0 }
        set {
            let wasRelative = isFajrSunriseRelative
            rawValue["is_fajr_sunrise_relative"] = newValue ? 1 : 0
            if newValue {
                self[.fajr] = -max(abs(self[.fajr]), 1)
            } else if wasRelative {
                self[.fajr] = 0
            }
        }
    }

    /// Isha counted on from Maghrib, so its minutes are at least one after it; zero would leave isha on its angle,
    /// so a choice saved without minutes reads as off, as the engine treats it. Turning it off puts isha back on its method.
    public var isIshaMaghribRelative: Bool {
        get { rawValue["is_isha_maghrib_relative"] == 1 && self[.isha] > 0 }
        set {
            let wasRelative = isIshaMaghribRelative
            rawValue["is_isha_maghrib_relative"] = newValue ? 1 : 0
            if newValue {
                self[.isha] = max(abs(self[.isha]), 1)
            } else if wasRelative {
                self[.isha] = 0
            }
        }
    }

    public init(rawValue: [String: Int]) {
        self.rawValue = rawValue
    }

    public subscript(_ prayer: Prayer) -> Int {
        get { rawValue[prayer.rawValue] ?? 0 }
        set { rawValue[prayer.rawValue] = newValue }
    }

    /// The minutes a prayer may move: a minute to five hours on the relative side of Fajr and Isha, up to two hours otherwise.
    public func range(for prayer: Prayer) -> ClosedRange<Int> {
        switch prayer {
        case .fajr where isFajrSunriseRelative:
            -300...(-1)
        case .isha where isIshaMaghribRelative:
            1...300
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
