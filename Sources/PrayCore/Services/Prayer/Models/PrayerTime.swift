//
//  PrayerTime.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-11.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSCalendar
import Foundation.NSDateInterval
import ZamzamCore

public struct PrayerTime: Equatable, Codable, Sendable {
    public let type: Prayer
    public let dateInterval: DateInterval
    /// Where the time was borrowed from on a day that can't be calculated at the place, near the polar circles.
    public let borrowed: PolarResolution?

    public init(type: Prayer, dateInterval: DateInterval, borrowed: PolarResolution? = nil) {
        self.type = type
        self.dateInterval = dateInterval
        self.borrowed = borrowed
    }
}

public extension PrayerTime {
    /// Whether this is a Friday's Dhuhr, by its own date in the place's calendar.
    func isJumuah(using calendar: Calendar) -> Bool {
        type == .dhuhr && dateInterval.start.isJumuah(using: calendar)
    }
}

// MARK: - Helpers

public extension Array where Element == PrayerTime {
    subscript(type: Prayer) -> Element? { first { $0.type == type } }
}
