//
//  PrayerServiceTimetable.swift
//  PrayServices
//
//  Created by Basem Emara on 2022-02-26.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import ZamzamCore

/// Reads prayer times from an authority's published timetable instead of calculating them.
///
/// Each timetable is a `PrayerTimetableSource`; this service keeps its tables and turns a printed day into prayer
/// times, with the user's adjustments, the same way for every source.
public struct PrayerServiceTimetable: PrayerService {
    private let store: PrayerTimetableStore
    private let log: LogManager

    init(
        source: any PrayerTimetableSource,
        networkManager: NetworkManager,
        directory: URL,
        log: LogManager,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.store = PrayerTimetableStore(source: source, networkManager: networkManager, directory: directory, log: log, now: now)
        self.log = log
    }
}

public extension PrayerServiceTimetable {
    /// The London Unified Prayer Timetable.
    ///
    /// - Parameters:
    ///   - apiKey: The key from a londonprayertimes.com account.
    ///   - directory: Where fetched tables are saved, in a folder per timetable. An app passes a folder in its App
    ///     Group, so its widgets and extensions read the same copy.
    static func london(apiKey: String, networkManager: NetworkManager, directory: URL, log: LogManager) -> Self {
        Self(source: PrayerTimetableSourceLondon(apiKey: apiKey), networkManager: networkManager, directory: directory, log: log)
    }
}

public extension PrayerServiceTimetable {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func calculate(
        for date: Date,
        using calendar: Calendar,
        with request: PrayerAPI.Request
    ) async throws -> [PrayerTime] {
        let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone, locale: .posix)
        let today = TimetableDate(date, using: calendar)
        let todaysTable = await store.days(holding: date, using: calendar, for: request)
        let onToday = { (clock: TimetableClock) in clock.date(on: today, using: calendar) }

        guard let prayerTimes = todaysTable[today] else { throw PrayError.invalidTimes }
        let asr = request.jurisprudence == .hanafi ? prayerTimes.asrHanafi ?? prayerTimes.asr : prayerTimes.asr

        guard var fajrTime = onToday(prayerTimes.fajr),
              var sunriseTime = onToday(prayerTimes.sunrise),
              var dhuhrTime = onToday(prayerTimes.dhuhr),
              var asrTime = onToday(asr),
              var magribTime = onToday(prayerTimes.maghrib),
              var ishaTime = onToday(prayerTimes.isha)
        else {
            log.error("Could not initialize prayer times from the timetable.")
            throw PrayError.invalidTimes
        }

        // Tomorrow's Fajr comes from today's table, or from the next one on a table's last day
        let tomorrowDate = date.tomorrow(using: calendar)
        let tomorrow = TimetableDate(tomorrowDate, using: calendar)
        let tomorrowsTable = todaysTable[tomorrow] != nil ? todaysTable : await store.days(holding: tomorrowDate, using: calendar, for: request)

        guard let tomorrowPrayers = tomorrowsTable[tomorrow],
              var tomorrowFajrTime = tomorrowPrayers.fajr.date(on: tomorrow, using: calendar),
              var tomorrowSunriseTime = tomorrowPrayers.sunrise.date(on: tomorrow, using: calendar)
        else {
            log.error("Could not initialize tomorrow prayer times from the timetable.")
            throw PrayError.invalidTimes
        }

        // Apply user adjustments if applicable; tomorrow's are applied the same way, so Isha ends where its Fajr begins
        if let adjustments = request.adjustments, request.adjustments?.isEmpty == false {
            if adjustments.sunrise != 0 {
                sunriseTime = (sunriseTime + .minutes(adjustments.sunrise)).roundedMinute
                tomorrowSunriseTime = (tomorrowSunriseTime + .minutes(adjustments.sunrise)).roundedMinute
            }

            if adjustments.fajr != 0 {
                fajrTime = (fajrTime + .minutes(adjustments.fajr)).roundedMinute
                tomorrowFajrTime = (tomorrowFajrTime + .minutes(adjustments.fajr)).roundedMinute

                if adjustments.isFajrSunriseRelative {
                    fajrTime = PrayerTime.relativeFajr(minutes: adjustments.fajr, sunrise: sunriseTime, otherwise: fajrTime)
                    tomorrowFajrTime = PrayerTime.relativeFajr(
                        minutes: adjustments.fajr,
                        sunrise: tomorrowSunriseTime,
                        otherwise: tomorrowFajrTime
                    )
                }
            }

            if adjustments.dhuhr != 0 {
                dhuhrTime = (dhuhrTime + .minutes(adjustments.dhuhr)).roundedMinute
            }

            if adjustments.asr != 0 {
                asrTime = (asrTime + .minutes(adjustments.asr)).roundedMinute
            }

            if adjustments.maghrib != 0 {
                magribTime = (magribTime + .minutes(adjustments.maghrib)).roundedMinute
            }

            if adjustments.isha != 0 {
                ishaTime = (ishaTime + .minutes(adjustments.isha)).roundedMinute

                if adjustments.isIshaMaghribRelative {
                    ishaTime = PrayerTime.relativeIsha(
                        minutes: adjustments.isha,
                        maghrib: magribTime,
                        nextFajr: tomorrowFajrTime,
                        otherwise: ishaTime
                    )
                }
            }
        }

        try PrayerTime.checkOrder(
            fajr: fajrTime,
            sunrise: sunriseTime,
            dhuhr: dhuhrTime,
            asr: asrTime,
            maghrib: magribTime,
            isha: ishaTime,
            nextFajr: tomorrowFajrTime,
            filter: request.filter,
            log: log
        )

        return PrayerTime.day(
            fajr: fajrTime,
            sunrise: sunriseTime,
            dhuhr: dhuhrTime,
            asr: asrTime,
            maghrib: magribTime,
            isha: ishaTime,
            nextFajr: tomorrowFajrTime,
            filter: request.filter
        )
    }
}
