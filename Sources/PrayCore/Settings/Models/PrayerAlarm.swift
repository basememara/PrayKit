//
//  PrayerAlarm.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-11-02.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate

public struct PrayerAlarm: Hashable, Sendable {
    public let prayer: Prayer
    public let date: Date

    public init(prayer: Prayer, date: Date) {
        self.prayer = prayer
        self.date = date
    }
}
