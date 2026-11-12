//
//  PrayerTime+Day.swift
//  PrayServices
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import ZamzamCore

extension PrayerTime {
    /// Fajr the given minutes from sunrise, or `fallback` when that isn't before sunrise.
    static func relativeFajr(minutes: Int, sunrise: Date, otherwise fallback: Date) -> Date {
        let fajr = sunrise + .minutes(minutes)
        return fajr < sunrise ? fajr : fallback
    }

    /// Isha the given minutes from Maghrib, or `fallback` when that isn't between Maghrib and the next Fajr.
    static func relativeIsha(minutes: Int, maghrib: Date, nextFajr: Date, otherwise fallback: Date) -> Date {
        let isha = maghrib + .minutes(minutes)
        return maghrib < isha && isha < nextFajr ? isha : fallback
    }

    /// Throws unless sunrise (when the filter lists it), Dhuhr, Asr, Maghrib and Isha follow one another and Isha
    /// begins before the next Fajr.
    static func checkOrder(
        sunrise: Date,
        dhuhr: Date,
        asr: Date,
        maghrib: Date,
        isha: Date,
        nextFajr: Date,
        filter: PrayerFilter,
        log: LogManager
    ) throws {
        guard let (error, message) = orderFailure(sunrise: sunrise, dhuhr: dhuhr, asr: asr, maghrib: maghrib, isha: isha, nextFajr: nextFajr, filter: filter) else {
            return
        }

        log.error(message)
        throw error
    }

    /// The first time out of order, as `checkOrder` reports it, or `nil` when the day is in order.
    static func orderFailure(
        sunrise: Date,
        dhuhr: Date,
        asr: Date,
        maghrib: Date,
        isha: Date,
        nextFajr: Date,
        filter: PrayerFilter
    ) -> (PrayError, String)? {
        if [.all, .essential].contains(filter), sunrise >= dhuhr {
            return (.invalidTimes, "Sunrise was invalid due to resulting after dhuhr.")
        }

        return if dhuhr >= asr {
            (.invalidElevation, "Dhuhr was invalid due to resulting after asr.")
        } else if asr >= maghrib {
            (.invalidElevation, "Asr was invalid due to resulting after maghrib.")
        } else if maghrib >= isha {
            (.invalidElevation, "Maghrib was invalid due to resulting after isha.")
        } else if isha >= nextFajr {
            (.invalidElevation, "Isha was invalid due to resulting after tomorrow's fajr.")
        } else {
            nil
        }
    }

    /// The day's times, each ending where the next begins and Isha at the next Fajr, with sunrise and the night as
    /// the filter lists them.
    static func day(
        fajr: Date,
        sunrise: Date,
        dhuhr: Date,
        asr: Date,
        maghrib: Date,
        isha: Date,
        nextFajr: Date,
        filter: PrayerFilter
    ) -> [PrayerTime] {
        let sunriseTimes = [.all, .essential].contains(filter)
            ? [PrayerTime(type: .sunrise, dateInterval: DateInterval(start: sunrise, end: dhuhr))]
            : []

        let nightTimes = [.all, .sunnah].contains(filter)
            ? PrayerTime.night(from: maghrib, to: nextFajr)
            : []

        return [PrayerTime(type: .fajr, dateInterval: DateInterval(start: fajr, end: sunrise))]
            + sunriseTimes
            + [
                PrayerTime(type: .dhuhr, dateInterval: DateInterval(start: dhuhr, end: asr)),
                PrayerTime(type: .asr, dateInterval: DateInterval(start: asr, end: maghrib)),
                PrayerTime(type: .maghrib, dateInterval: DateInterval(start: maghrib, end: isha)),
                PrayerTime(type: .isha, dateInterval: DateInterval(start: isha, end: nextFajr))
            ]
            + nightTimes
    }
}
