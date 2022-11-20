//
//  IqamaTimes.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation.NSCalendar
import Foundation.NSDate
import ZamzamCore

public struct IqamaTimes: Equatable, Codable {
    public let fajr: IqamaType?
    public let dhuhr: IqamaType?
    public let asr: IqamaType?
    public let maghrib: IqamaType?
    public let isha: IqamaType?

    public init(
        fajr: IqamaType?,
        dhuhr: IqamaType?,
        asr: IqamaType?,
        maghrib: IqamaType?,
        isha: IqamaType?
    ) {
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
    }

    public init() {
        self.init(fajr: nil, dhuhr: nil, asr: nil, maghrib: nil, isha: nil)
    }
}

public extension IqamaTimes {
    enum IqamaType: Equatable, Codable {
        case time(hour: Int, minutes: Int)
        case minutes(Int)
    }
}

public extension IqamaTimes {
    subscript(_ prayerTime: PrayerTime, using calendar: Calendar) -> Date? {
        let iqamaType: IqamaType?

        switch prayerTime.type {
        case .fajr:
            iqamaType = fajr
        case .dhuhr:
            iqamaType = dhuhr
        case .asr:
            iqamaType = asr
        case .maghrib:
            iqamaType = maghrib
        case .isha:
            iqamaType = isha
        default:
            return nil
        }

        switch iqamaType {
        case let .time(hour, minutes):
            guard var iqamaTime = calendar.date(bySettingHour: hour, minute: minutes, second: 0, of: prayerTime.dateInterval.start) else { return nil }

            // Consider when prayer time near midnight
            if iqamaTime < prayerTime.dateInterval.start, prayerTime.type == .isha {
                iqamaTime += .days(1, calendar)
            }

            guard iqamaTime.isBetween(prayerTime.dateInterval.start, prayerTime.dateInterval.end) else { return nil }
            return iqamaTime
        case let .minutes(minutes) where minutes > 0:
            let iqamaTime = prayerTime.dateInterval.start + .minutes(minutes)
            guard iqamaTime < prayerTime.dateInterval.end else { return nil }
            return iqamaTime
        default:
            return nil
        }
    }
}

public extension IqamaTimes {
    var isEmpty: Bool {
        [.minutes(0), nil].contains(fajr)
            && [.minutes(0), nil].contains(dhuhr)
            && [.minutes(0), nil].contains(asr)
            && [.minutes(0), nil].contains(maghrib)
            && [.minutes(0), nil].contains(isha)
    }
}

extension IqamaTimes: CustomStringConvertible {
    public var description: String {
        """
        [
            fajr: \(String(describing: fajr)),
            dhuhr: \(String(describing: dhuhr)),
            asr: \(String(describing: asr)),
            maghrib: \(String(describing: maghrib)),
            isha: \(String(describing: isha))
        ]
        """
    }
}

extension IqamaTimes.IqamaType: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .time(hour, minutes):
            return "\(String(format: "%02d", hour)):\(String(format: "%02d", minutes))"
        case let .minutes(int):
            return "\(int) mins"
        }
    }
}
