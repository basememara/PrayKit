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
            .map({ fajrTime(with: request, from: $0) })
        else {
            log.error("Could not initialize tomorrow prayer times from adhan library.")
            throw PrayError.invalidParameters
        }

        try PrayerTime.checkOrder(
            sunrise: prayers.sunrise,
            dhuhr: prayers.dhuhr,
            asr: prayers.asr,
            maghrib: prayers.maghrib,
            isha: prayers.isha,
            nextFajr: tomorrowFajrTime,
            filter: request.filter,
            log: log
        )

        let ishaTime: Date = {
            if let adjustments = request.adjustments, adjustments.isha != 0, adjustments.isIshaMaghribRelative {
                // Like a relative Fajr past sunrise, one outside Maghrib to the next Fajr keeps the method's time
                return PrayerTime.relativeIsha(
                    minutes: adjustments.isha,
                    maghrib: prayers.maghrib,
                    nextFajr: tomorrowFajrTime,
                    otherwise: prayers.isha
                )
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

        let times = PrayerTime.day(
            fajr: fajrTime(with: request, from: prayers),
            sunrise: prayers.sunrise,
            dhuhr: prayers.dhuhr,
            asr: prayers.asr,
            maghrib: prayers.maghrib,
            isha: ishaTime,
            nextFajr: tomorrowFajrTime,
            filter: request.filter
        )

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

    func fajrTime(with request: PrayerAPI.Request, from prayers: PrayerTimes) -> Date {
        guard let adjustments = request.adjustments, adjustments.fajr != 0, adjustments.isFajrSunriseRelative else { return prayers.fajr }
        return PrayerTime.relativeFajr(minutes: adjustments.fajr, sunrise: prayers.sunrise, otherwise: prayers.fajr)
    }
}
