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
    public let jumuah: IqamaType?

    public init(
        fajr: IqamaType?,
        dhuhr: IqamaType?,
        asr: IqamaType?,
        maghrib: IqamaType?,
        isha: IqamaType?,
        jumuah: IqamaType?
    ) {
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.jumuah = jumuah
    }

    public init() {
        self.init(
            fajr: nil,
            dhuhr: nil,
            asr: nil,
            maghrib: nil,
            isha: nil,
            jumuah: nil
        )
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
        let startTime = prayerTime.dateInterval.start
        let endTime = prayerTime.dateInterval.end
        let iqamaType: IqamaType?

        switch prayerTime.type {
        case .fajr:
            iqamaType = fajr
        case .dhuhr:
            iqamaType = startTime.isJumuah(using: calendar) ? jumuah : dhuhr
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
            guard var iqamaTime = calendar.date(bySettingHour: hour, minute: minutes, second: 0, of: startTime) else { return nil }

            // Consider when prayer time near midnight
            if iqamaTime < startTime, prayerTime.type == .isha {
                iqamaTime += .days(1, calendar)
            }

            return iqamaTime.isBetween(startTime, endTime) ? iqamaTime : nil
        case let .minutes(minutes) where minutes > 0:
            let iqamaTime = startTime + .minutes(minutes)
            return iqamaTime < endTime ? iqamaTime : nil
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
            && [.minutes(0), nil].contains(jumuah)
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
            isha: \(String(describing: isha)),
            jumuah: \(String(describing: jumuah))
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
