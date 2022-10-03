//
//  NotificationAdhan.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-06-06.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public struct NotificationAdhan: RawRepresentable, Equatable, Codable {
    public var rawValue: [String: AdhanSound]

    public init(rawValue: [String: AdhanSound]) {
        self.rawValue = rawValue
    }

    public subscript(_ prayer: Prayer) -> AdhanSound? {
        get { rawValue[prayer.rawValue] }
        set { rawValue[prayer.rawValue] = newValue }
    }
}
