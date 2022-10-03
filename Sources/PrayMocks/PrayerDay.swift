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
    static func mock(at date: Date = .now, calendar: Calendar = .current, filter: PrayerFilter = .all) -> PrayerDay {
        // swiftlint:disable:previous function_body_length
        PrayerDay(
            date: date.startOfDay(using: calendar),
            times: [
                PrayerTime(
                    type: .fajr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: 5, minute: 53, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .sunrise,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 5, minute: 53, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: 13, minute: 14, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .dhuhr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 13, minute: 14, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: 17, minute: 8, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .asr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 17, minute: 8, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: 20, minute: 33, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .maghrib,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 20, minute: 33, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: 22, minute: 4, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .isha,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 22, minute: 4, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .midnight,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 00, minute: 28, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .lastThird,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 01, minute: 46, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
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
                        start: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 5, minute: 53, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .sunrise,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 5, minute: 53, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 13, minute: 14, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .dhuhr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 13, minute: 14, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 17, minute: 8, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .asr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 17, minute: 8, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 20, minute: 33, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .maghrib,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 20, minute: 33, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 22, minute: 4, second: 0, of: date.yesterday(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .isha,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 22, minute: 4, second: 0, of: date.yesterday(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .midnight,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 00, minute: 28, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .lastThird,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 01, minute: 46, second: 0, of: date) ?? .distantPast,
                        end: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date) ?? .distantFuture
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
                        start: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 5, minute: 53, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .sunrise,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 5, minute: 53, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 13, minute: 14, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .dhuhr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 13, minute: 14, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 17, minute: 8, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .asr,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 17, minute: 8, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 20, minute: 33, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .maghrib,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 20, minute: 33, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 22, minute: 4, second: 0, of: date.tomorrow(using: calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .isha,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 22, minute: 4, second: 0, of: date.tomorrow(using: calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .midnight,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 00, minute: 28, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantFuture
                    )
                ),
                PrayerTime(
                    type: .lastThird,
                    dateInterval: DateInterval(
                        start: calendar.date(bySettingHour: 01, minute: 46, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantPast,
                        end: calendar.date(bySettingHour: 4, minute: 22, second: 0, of: date.tomorrow(using: calendar) + .days(1, calendar)) ?? .distantFuture
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
