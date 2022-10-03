//
//  PrayerServiceAdhan.swift
//  PrayServices
//
//  Created by Basem Emara on 2019-06-11.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Adhan
import Foundation
import PrayCore
import ZamzamCore

public struct PrayerServiceAdhan: PrayerService {
    private let log: LogManager

    public init(log: LogManager) {
        self.log = log
    }
}

public extension PrayerServiceAdhan {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func calculate(
        for date: Date,
        using calendar: Calendar,
        with request: PrayerAPI.Request
    ) throws -> [PrayerTime] {
        let coordinates = Adhan.Coordinates(latitude: request.coordinates.latitude, longitude: request.coordinates.longitude)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let parameters = CalculationParameters(from: request)

        guard let prayers = PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: parameters) else {
            log.error("Could not initialize prayer times from adhan library.")
            throw PrayError.invalidParameters
        }

        guard prayers.fajr < prayers.sunrise else {
            log.error("Fajr was invalid due to resulting after sunrise.")
            throw PrayError.invalidTimes
        }

        guard let tomorrowFajrTime = PrayerTimes(
                coordinates: coordinates,
                date: calendar.dateComponents([.year, .month, .day], from: date.tomorrow(using: calendar)),
                calculationParameters: parameters
            )
            .map({ makeFajrPrayerTime(with: request, from: $0) })?
            .dateInterval.start
        else {
            log.error("Could not initialize tomorrow prayer times from adhan library.")
            throw PrayError.invalidParameters
        }

        let fajrPrayerTime = makeFajrPrayerTime(with: request, from: prayers)
        var times = [fajrPrayerTime]

        if [.all, .essential].contains(request.filter) {
            guard prayers.sunrise < prayers.dhuhr else {
                log.error("Sunrise was invalid due to resulting after dhuhr.")
                throw PrayError.invalidTimes
            }

            times.append(
                PrayerTime(
                    type: .sunrise,
                    dateInterval: .init(
                        start: prayers.sunrise,
                        end: prayers.dhuhr
                    )
                )
            )
        }

        guard prayers.dhuhr < prayers.asr else {
            log.error("Dhuhr was invalid due to resulting after asr.")
            throw PrayError.invalidElevation
        }

        guard prayers.asr < prayers.maghrib else {
            log.error("Asr was invalid due to resulting after maghrib.")
            throw PrayError.invalidElevation
        }

        guard prayers.maghrib < prayers.isha else {
            log.error("Maghrib was invalid due to resulting after isha.")
            throw PrayError.invalidElevation
        }

        guard prayers.isha < tomorrowFajrTime else {
            log.error("Isha was invalid due to resulting after tomorrow's fajr.")
            throw PrayError.invalidElevation
        }

        times.append(contentsOf: [
            PrayerTime(
                type: .dhuhr,
                dateInterval: .init(
                    start: prayers.dhuhr,
                    end: prayers.asr
                )
            ),
            PrayerTime(
                type: .asr,
                dateInterval: .init(
                    start: prayers.asr,
                    end: prayers.maghrib
                )
            ),
            PrayerTime(
                type: .maghrib,
                dateInterval: .init(
                    start: prayers.maghrib,
                    end: prayers.isha
                )
            ),
            PrayerTime(
                type: .isha,
                dateInterval: .init(
                    start: {
                        if let adjustments = request.adjustments, adjustments.isha != 0, adjustments.isIshaMaghribRelative {
                            let isha = prayers.maghrib + .minutes(adjustments.isha)
                            return isha < tomorrowFajrTime ? isha : prayers.isha
                        }

                        guard request.method == .ummAlQuraRamadan,
                              date.isRamadan(timeZone: request.timeZone),
                              request.adjustments?.isha ?? 0 == 0
                        else {
                            return prayers.isha
                        }

                        let isha = prayers.isha + .minutes(30)
                        return isha < tomorrowFajrTime ? isha : prayers.isha
                    }(),
                    end: tomorrowFajrTime
                )
            )
        ])

        if [.all, .sunnah].contains(request.filter), let sunnahTimes = SunnahTimes(from: prayers) {
            guard sunnahTimes.middleOfTheNight < sunnahTimes.lastThirdOfTheNight,
                  sunnahTimes.lastThirdOfTheNight < tomorrowFajrTime
            else {
                log.error("Sunnah prayers were invalid due to resulting after tomorrow's fajr.")
                throw PrayError.invalidTimes
            }

            times.append(contentsOf: [
                PrayerTime(
                    type: .midnight,
                    dateInterval: .init(
                        start: sunnahTimes.middleOfTheNight,
                        end: sunnahTimes.lastThirdOfTheNight
                    )
                ),
                PrayerTime(
                    type: .lastThird,
                    dateInterval: .init(
                        start: sunnahTimes.lastThirdOfTheNight,
                        end: tomorrowFajrTime
                    )
                )
            ])
        }

        return times
    }
}

// MARK: - Helpers

private extension PrayerServiceAdhan {
    func makeFajrPrayerTime(with request: PrayerAPI.Request, from prayers: PrayerTimes) -> PrayerTime {
        PrayerTime(
            type: .fajr,
            dateInterval: .init(
                start: {
                    guard let adjustments = request.adjustments, adjustments.fajr != 0, adjustments.isFajrSunriseRelative else { return prayers.fajr }
                    let fajr = prayers.sunrise + .minutes(adjustments.fajr)
                    return fajr < prayers.sunrise ? fajr : prayers.fajr
                }(),
                end: prayers.sunrise
            )
        )
    }
}
