//
//  PreAdhanMinutes.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-04-01.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

public struct PreAdhanMinutes: RawRepresentable, Equatable, Codable {
    public var rawValue: [String: Int]

    public var imsak: Int {
        get { rawValue["imsak"] ?? 0 }
        set { rawValue["imsak"] = newValue }
    }

    public var jumuah: Int {
        get { rawValue["jumuah"] ?? 0 }
        set { rawValue["jumuah"] = newValue }
    }

    public init(rawValue: [String: Int]) {
        self.rawValue = rawValue
    }

    public subscript(_ prayer: Prayer) -> Int {
        get { rawValue[prayer.rawValue] ?? 0 }
        set { rawValue[prayer.rawValue] = newValue }
    }
}
