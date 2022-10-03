//
//  PrayerDay.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-14.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate
import Foundation.NSTimeZone

public struct PrayerDay: Equatable, Codable {
    public let date: Date
    public let times: [PrayerTime]
    public let yesterday: [PrayerTime]
    public let tomorrow: [PrayerTime]

    public init(
        date: Date,
        times: [PrayerTime],
        yesterday: [PrayerTime],
        tomorrow: [PrayerTime]
    ) {
        self.date = date
        self.times = times
        self.yesterday = yesterday
        self.tomorrow = tomorrow
    }
}

public extension PrayerDay {
    func current(at time: Date = .now) -> PrayerTime? {
        times.first { time.isBetween($0.dateInterval.start, $0.dateInterval.end) && $0.type.isEssential }
            ?? yesterday[.isha]
    }

    func next(at time: Date = .now, sunriseAfterIsha: Bool = false) -> PrayerTime? {
        let predicate: (PrayerTime) -> Bool = { $0.dateInterval.start > time && $0.type.isEssential && (sunriseAfterIsha ? $0.type != .fajr : true) }
        return times.first(where: predicate) ?? tomorrow.first(where: predicate)
    }
}
