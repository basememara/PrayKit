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
        var parameters = CalculationParameters(from: request)
        parameters.polarCircleResolution = PolarCircleResolution(request.polarResolution)

        guard let day = prayerTimes(at: coordinates, on: dateComponents, with: parameters, borrowingFrom: request.polarResolution) else {
            log.error("Could not initialize prayer times from adhan library.")
            throw PrayError.invalidParameters
        }

        let prayers = day.times

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

        let ishaTime: Date = {
            if let adjustments = request.adjustments, adjustments.isha != 0, adjustments.isIshaMaghribRelative {
                // Like a relative Fajr past sunrise, one outside Maghrib to the next Fajr keeps the method's time
                let isha = prayers.maghrib + .minutes(adjustments.isha)
                return prayers.maghrib < isha && isha < tomorrowFajrTime ? isha : prayers.isha
            }

            guard request.method == .ummAlQuraRamadan,
                  date.isRamadan(timeZone: request.timeZone),
                  request.adjustments?.isha ?? 0 == 0
            else {
                return prayers.isha
            }

            let isha = prayers.isha + .minutes(30)
            return isha < tomorrowFajrTime ? isha : prayers.isha
        }()

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
                    end: ishaTime
                )
            ),
            PrayerTime(
                type: .isha,
                dateInterval: .init(
                    start: ishaTime,
                    end: tomorrowFajrTime
                )
            )
        ])

        if [.all, .sunnah].contains(request.filter) {
            times.append(contentsOf: PrayerTime.night(from: prayers.maghrib, to: tomorrowFajrTime))
        }

        guard let borrowed = day.borrowed else { return times }
        return times.map { PrayerTime(type: $0.type, dateInterval: $0.dateInterval, borrowed: borrowed) }
    }
}

// MARK: - Helpers

private extension PrayerServiceAdhan {
    /// The day's times, and where they were borrowed from when the day can't be calculated at the place itself.
    func prayerTimes(
        at coordinates: Adhan.Coordinates,
        on date: DateComponents,
        with parameters: CalculationParameters,
        borrowingFrom resolution: PolarResolution
    ) -> (times: PrayerTimes, borrowed: PolarResolution?)? {
        var ownParameters = parameters
        ownParameters.polarCircleResolution = .unresolved

        if let times = PrayerTimes(coordinates: coordinates, date: date, calculationParameters: ownParameters) {
            return (times, nil)
        }

        return PrayerTimes(coordinates: coordinates, date: date, calculationParameters: parameters).map { ($0, resolution) }
    }

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
