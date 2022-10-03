//
//  AdjustmentMinutes.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-06-06.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public struct AdjustmentMinutes: RawRepresentable, Equatable, Codable {
    public var rawValue: [String: Int]

    public var isFajrSunriseRelative: Bool {
        get { (rawValue["is_fajr_sunrise_relative"] ?? 0) == 1 }
        set { rawValue["is_fajr_sunrise_relative"] = newValue ? 1 : 0 }
    }

    public var isIshaMaghribRelative: Bool {
        get { (rawValue["is_isha_maghrib_relative"] ?? 0) == 1 }
        set { rawValue["is_isha_maghrib_relative"] = newValue ? 1 : 0 }
    }

    public init(rawValue: [String: Int]) {
        self.rawValue = rawValue
    }

    public subscript(_ prayer: Prayer) -> Int {
        get { rawValue[prayer.rawValue] ?? 0 }
        set { rawValue[prayer.rawValue] = newValue }
    }

    public var isEmpty: Bool {
        rawValue
            .filter { !["is_fajr_sunrise_relative", "is_isha_maghrib_relative"].contains($0.key) }
            .allSatisfy { $0.value == 0 }
        || rawValue.isEmpty
    }
}
