//
//  DuhaType.swift
//  PrayCore
//
//  Created by Basem Emara on 2023-07-29.
//  Copyright © 2023 Zamzam Inc. All rights reserved.
//

import Foundation.NSCalendar
import Foundation.NSDate
import ZamzamCore

public enum DuhaType: Equatable, Codable {
    case time(hour: Int, minutes: Int)
    case minutes(Int)
}

public extension DuhaType {
    func date(from sunriseDateInterval: DateInterval, using calendar: Calendar) -> Date? {
        let startTime = sunriseDateInterval.start
        let endTime = sunriseDateInterval.end

        switch self {
        case let .time(hour, minutes):
            guard let duhaTime = calendar.date(bySettingHour: hour, minute: minutes, second: 0, of: startTime) else { return nil }
            return duhaTime.isBetween(startTime, endTime) ? duhaTime : nil
        case let .minutes(minutes) where minutes > 0:
            let duhaTime = startTime + .minutes(minutes)
            return duhaTime < endTime ? duhaTime : nil
        default:
            return nil
        }
    }
}

extension DuhaType: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .time(hour, minutes):
            return "\(String(format: "%02d", hour)):\(String(format: "%02d", minutes))"
        case let .minutes(int):
            return "\(int) mins"
        }
    }
}
