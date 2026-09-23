//
//  ReminderSounds.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-08-01.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public struct ReminderSounds: RawRepresentable, Equatable, Codable, Sendable {
    public var rawValue: [String: NotificationSound]

    public init(rawValue: [String: NotificationSound]) {
        self.rawValue = rawValue
    }

    public subscript(_ prayer: Prayer) -> NotificationSound? {
        get { rawValue[prayer.rawValue] }
        set { rawValue[prayer.rawValue] = newValue }
    }
}
