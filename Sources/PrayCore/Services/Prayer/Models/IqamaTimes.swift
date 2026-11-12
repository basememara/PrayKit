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

public struct IqamaTimes: Equatable, Codable, Sendable {
    public var fajr: IqamaType?
    public var dhuhr: IqamaType?
    public var asr: IqamaType?
    public var maghrib: IqamaType?
    public var isha: IqamaType?
    public var jumuah: IqamaType?

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
    enum IqamaType: Equatable, Codable, Sendable {
        case time(hour: Int, minutes: Int)
        case minutes(Int)
    }
}

public extension IqamaTimes {
    /// The iqama of one of the five daily prayers; any other prayer has none, and setting it changes nothing.
    subscript(prayer: Prayer) -> IqamaType? {
        get {
            switch prayer {
            case .fajr:
                fajr
            case .dhuhr:
                dhuhr
            case .asr:
                asr
            case .maghrib:
                maghrib
            case .isha:
                isha
            default:
                nil
            }
        }
        set {
            switch prayer {
            case .fajr:
                fajr = newValue
            case .dhuhr:
                dhuhr = newValue
            case .asr:
                asr = newValue
            case .maghrib:
                maghrib = newValue
            case .isha:
                isha = newValue
            default:
                break
            }
        }
    }

    subscript(_ prayerTime: PrayerTime, using calendar: Calendar) -> Date? {
        let iqamaType: IqamaType?

        switch prayerTime.type {
        case .fajr:
            iqamaType = fajr
        case .dhuhr:
            iqamaType = prayerTime.isJumuah(using: calendar) ? jumuah : dhuhr
        case .asr:
            iqamaType = asr
        case .maghrib:
            iqamaType = maghrib
        case .isha:
            iqamaType = isha
        default:
            return nil
        }

        return iqamaType?.date(for: prayerTime, using: calendar)
    }

    /// The iqama a timer counts to for a prayer, the khutba for Friday's Dhuhr: `nil` when the iqama timer is off or
    /// the prayer has none.
    func timerIqama(for prayerTime: PrayerTime, isTimerEnabled: Bool, using calendar: Calendar) -> Date? {
        isTimerEnabled ? self[prayerTime, using: calendar] : nil
    }

    /// The soonest iqama still ahead of `date` among the day's prayers, today's and tomorrow's, that `matches` accepts.
    func next(
        in day: PrayerDay,
        after date: Date,
        using calendar: Calendar,
        where matches: (PrayerTime) -> Bool
    ) -> (prayerTime: PrayerTime, date: Date)? {
        (day.times + day.tomorrow)
            .filter(matches)
            .compactMap { prayerTime in self[prayerTime, using: calendar].map { (prayerTime: prayerTime, date: $0) } }
            .filter { $0.date > date }
            .min { $0.date < $1.date }
    }
}

extension IqamaTimes.IqamaType: TimeOrMinutes {
    public var timeOfDay: (hour: Int, minutes: Int)? {
        guard case let .time(hour, minutes) = self else { return nil }
        return (hour, minutes)
    }

    public var minutesAfterStart: Int? {
        guard case let .minutes(minutes) = self else { return nil }
        return minutes
    }
}

public extension IqamaTimes.IqamaType {
    /// Where this iqama falls in a prayer's time, whichever prayer's setting it is: nil when that time can't hold it.
    func date(for prayerTime: PrayerTime, using calendar: Calendar) -> Date? {
        let startTime = prayerTime.dateInterval.start
        let endTime = prayerTime.dateInterval.end

        switch self {
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
