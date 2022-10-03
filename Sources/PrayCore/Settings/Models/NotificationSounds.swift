//
//  NotificationSounds.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-06-06.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public struct NotificationSounds: RawRepresentable, Equatable, Codable {
    public var rawValue: [String: NotificationSound]

    public init(rawValue: [String: NotificationSound]) {
        self.rawValue = rawValue
    }

    public subscript(_ prayer: Prayer) -> NotificationSound? {
        get { rawValue[prayer.rawValue] }
        set { rawValue[prayer.rawValue] = newValue }
    }
}
