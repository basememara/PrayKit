//
//  PrayerDay.swift
//  PrayMocks
//
//  Created by Basem Emara on 2021-06-28.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate
import Foundation.NSCalendar
import PrayCore
import ZamzamCore

public extension PrayerDay {
    static func mock(
        at date: Date = .now,
        times: [(hour: Int, minute: Int)] = [(4, 22), (5, 53), (13, 14), (17, 8), (20, 33), (22, 4), (0, 28), (1, 46)],
        calendar: Calendar = .current,
        filter: PrayerFilter = .all
    ) -> PrayerDay {
        // swiftlint:disable:previous function_body_length
        PrayerDay(
            date: date.startOfDay(using: calendar),
            times: [
                PrayerTime(
                    type: .fajr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[0].hour, minute: times[0].minute, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[1].hour, minute: times[1].minute, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .sunrise,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[1].hour, minute: times[1].minute, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[2].hour, minute: times[2].minute, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .dhuhr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[2].hour, minute: times[2].minute, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[3].hour, minute: times[3].minute, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .asr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[3].hour, minute: times[3].minute, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[4].hour, minute: times[4].minute, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .maghrib,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[4].hour, minute: times[4].minute, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[5].hour, minute: times[5].minute, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .isha,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[5].hour, minute: times[5].minute, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[0].hour, minute: times[0].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .midnight,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[6].hour, minute: times[6].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[7].hour, minute: times[7].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .lastThird,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[7].hour, minute: times[7].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[0].hour, minute: times[0].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                )
            ].filter {
                switch filter {
                case .all:
                    return true
                case .obligation:
                    return $0.type.isObligation
                case .essential:
                    return $0.type.isEssential
                case .sunnah:
                    return !$0.type.isEssential
                }
            },
            yesterday: [
                PrayerTime(
                    type: .fajr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[0].hour, minute: times[0].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[1].hour, minute: times[1].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .sunrise,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[1].hour, minute: times[1].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[2].hour, minute: times[2].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .dhuhr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[2].hour, minute: times[2].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[3].hour, minute: times[3].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .asr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[3].hour, minute: times[3].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[4].hour, minute: times[4].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .maghrib,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[4].hour, minute: times[4].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[5].hour, minute: times[5].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .isha,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[5].hour, minute: times[5].minute, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[0].hour, minute: times[0].minute, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .midnight,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[6].hour, minute: times[6].minute, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[7].hour, minute: times[7].minute, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .lastThird,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[7].hour, minute: times[7].minute, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[0].hour, minute: times[0].minute, second: 0, of: date) ?? .distantFuture
                    )
                )
            ].filter {
                switch filter {
                case .all:
                    return true
                case .obligation:
                    return $0.type.isObligation
                case .essential:
                    return $0.type.isEssential
                case .sunnah:
                    return !$0.type.isEssential
                }
            },
            tomorrow: [
                PrayerTime(
                    type: .fajr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[0].hour, minute: times[0].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[1].hour, minute: times[1].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .sunrise,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[1].hour, minute: times[1].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[2].hour, minute: times[2].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .dhuhr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[2].hour, minute: times[2].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[3].hour, minute: times[3].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .asr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[3].hour, minute: times[3].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[4].hour, minute: times[4].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .maghrib,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[4].hour, minute: times[4].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[5].hour, minute: times[5].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .isha,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[5].hour, minute: times[5].minute, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[0].hour, minute: times[0].minute, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .midnight,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[6].hour, minute: times[6].minute, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[7].hour, minute: times[7].minute, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .lastThird,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: times[7].hour, minute: times[7].minute, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: times[0].hour, minute: times[0].minute, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantFuture
                    )
                )
            ].filter {
                switch filter {
                case .all:
                    return true
                case .obligation:
                    return $0.type.isObligation
                case .essential:
                    return $0.type.isEssential
                case .sunnah:
                    return !$0.type.isEssential
                }
            }
        )
    }
}

public extension PrayerDay {
    func mockDates() -> (
        normal: Date,
        danger: Date,
        distant: Date,
        stopwatch: Date,
        iqama: Date
    ) {
        (
            (current()?.dateInterval.end ?? .now) - .minutes(175),
            (current()?.dateInterval.end ?? .now) - .minutes(5),
            (times[.sunrise]?.dateInterval.start ?? .now) + .minutes(10),
            (current()?.dateInterval.start ?? .now) + .minutes(3),
            (times[.maghrib]?.dateInterval.start ?? .now) + .minutes(19)
        )
    }
}
