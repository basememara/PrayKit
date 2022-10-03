//
//  PrayerTime.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-11.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSDateInterval

public struct PrayerTime: Equatable, Codable {
    public let type: Prayer
    public let dateInterval: DateInterval

    public init(type: Prayer, dateInterval: DateInterval) {
        self.type = type
        self.dateInterval = dateInterval
    }
}

// MARK: - Helpers

public extension Array where Element == PrayerTime {
    subscript(type: Prayer) -> Element? { first { $0.type == type } }
}
