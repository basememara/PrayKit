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
        let days = DaySource(request: request, calendar: calendar)

        guard let today = days.resolved(on: date) else {
            log.error("Could not initialize prayer times from adhan library.")
            throw PrayError.invalidParameters
        }

        // Each day is resolved on its own, so tonight ends at the very Fajr tomorrow's own day begins with
        guard let tomorrow = days.resolved(on: date.tomorrow(using: calendar)) else {
            log.error("Could not initialize tomorrow prayer times from adhan library.")
            throw PrayError.invalidParameters
        }

        let tomorrowFajrTime = fajrTime(with: request, from: tomorrow.times)
        let (prayers, borrowed) = days.fitted(today, before: tomorrowFajrTime, on: date)

        try PrayerTime.checkOrder(
            fajr: prayers.fajr,
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

        guard let borrowed else { return times }
        return times.map { PrayerTime(type: $0.type, dateInterval: $0.dateInterval, borrowed: borrowed) }
    }
}

// MARK: - Types

private extension PrayerServiceAdhan {
    /// A day's times as computed, before any adjustment relative to sunrise or Maghrib.
    struct RawDay {
        let fajr: Date
        let sunrise: Date
        let dhuhr: Date
        let asr: Date
        let maghrib: Date
        let isha: Date

        /// Another day's times relabelled onto this one, whole UTC days apart, as adhan-swift shifts a nearest day.
        func shifted(days: Int) -> Self {
            let interval = TimeInterval(days) * 86_400
            return Self(
                fajr: fajr + interval,
                sunrise: sunrise + interval,
                dhuhr: dhuhr + interval,
                asr: asr + interval,
                maghrib: maghrib + interval,
                isha: isha + interval
            )
        }

        /// This day's times after the given Fajr, for a day whose Fajr was settled where last night ended.
        func starting(at fajr: Date) -> Self {
            Self(fajr: fajr, sunrise: sunrise, dhuhr: dhuhr, asr: asr, maghrib: maghrib, isha: isha)
        }

        func isOrdered(nextFajr: Date, filter: PrayerFilter) -> Bool {
            PrayerTime.orderFailure(
                fajr: fajr,
                sunrise: sunrise,
                dhuhr: dhuhr,
                asr: asr,
                maghrib: maghrib,
                isha: isha,
                nextFajr: nextFajr,
                filter: filter
            ) == nil
        }
    }

    /// Where a day's times come from: the place's own, or near the polar circles a day borrowed as Polar days says.
    ///
    /// adhan-swift borrows only a day it can't compute at all, and takes the first day it can, even one computed out of
    /// order, which near the midnight sun put a fixed-interval Isha after the next Fajr and failed the day. This takes
    /// the first one in order instead, searching in adhan-swift's own steps, so a day it borrowed in order is unchanged.
    struct DaySource {
        typealias Resolved = (times: RawDay, borrowed: PolarResolution?)

        // adhan-swift's steps: half a degree toward the equator, or a day either side up to half a year
        private static let latitudeStep = 0.5
        private static let furthestDay = 183

        let request: PrayerAPI.Request
        let calendar: Calendar
        private let parameters: CalculationParameters
        /// A day computed but out of order borrows only where Polar days applies; elsewhere the user's own settings
        /// put it out of order, and it fails as before.
        private let canBorrowOutOfOrder: Bool

        init(request: PrayerAPI.Request, calendar: Calendar) {
            self.request = request
            self.calendar = calendar
            var parameters = CalculationParameters(from: request)
            parameters.polarCircleResolution = .unresolved
            self.parameters = parameters
            canBorrowOutOfOrder = PolarResolution.applies(
                latitude: request.coordinates.latitude,
                method: request.method,
                maghribDegrees: request.maghribDegrees
            )
        }

        /// The day's times in order on their own, the place's or else borrowed, and whether they were borrowed. Each
        /// day is judged alone, so the Fajr it begins with is the one the night before ends at.
        func resolved(on date: Date) -> Resolved? {
            let own = day(on: date, at: request.coordinates.latitude)

            if let own, !canBorrowOutOfOrder || own.isOrdered(nextFajr: .distantFuture, filter: request.filter) {
                return (own, nil)
            }

            let borrowed = candidates(on: date).first { $0.isOrdered(nextFajr: .distantFuture, filter: request.filter) }
            return borrowed.map { ($0, request.polarResolution) } ?? own.map { ($0, nil) }
        }

        /// The day as it hands over to tomorrow: kept when its Isha comes before `nextFajr`. Otherwise, where Polar days
        /// applies, the rest of the day is borrowed from the nearest day that fits between its Fajr and `nextFajr`, so
        /// the day still begins where last night ended and ends where tomorrow begins.
        func fitted(_ day: Resolved, before nextFajr: Date, on date: Date) -> Resolved {
            guard canBorrowOutOfOrder, !day.times.isOrdered(nextFajr: nextFajr, filter: request.filter) else { return day }

            let fitting = candidates(on: date).lazy
                .map { $0.starting(at: day.times.fajr) }
                .first { $0.isOrdered(nextFajr: nextFajr, filter: request.filter) }

            return fitting.map { ($0, request.polarResolution) } ?? day
        }
    }
}

// MARK: - Helpers

private extension PrayerServiceAdhan.RawDay {
    init(_ times: PrayerTimes) {
        self.init(fajr: times.fajr, sunrise: times.sunrise, dhuhr: times.dhuhr, asr: times.asr, maghrib: times.maghrib, isha: times.isha)
    }
}

private extension PrayerServiceAdhan.DaySource {
    func day(on date: Date, at latitude: Double) -> PrayerServiceAdhan.RawDay? {
        PrayerTimes(
            coordinates: Coordinates(latitude: latitude, longitude: request.coordinates.longitude),
            date: calendar.dateComponents([.year, .month, .day], from: date),
            calculationParameters: parameters
        )
        .map(PrayerServiceAdhan.RawDay.init)
    }

    /// The days to borrow from, nearest first: lower latitudes on the same date, or the same place on nearby dates
    /// relabelled onto this one.
    func candidates(on date: Date) -> AnySequence<PrayerServiceAdhan.RawDay> {
        switch request.polarResolution {
        case .nearestLatitude:
            let latitudes = sequence(first: Self.step(from: request.coordinates.latitude)) { $0 == 0 ? nil : Self.step(from: $0) }
            return AnySequence(latitudes.lazy.compactMap { day(on: date, at: $0) })
        case .nearestDay:
            let offsets = (1...Self.furthestDay).lazy.flatMap { [$0, -$0] }
            return AnySequence(offsets.compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: date)
                    .flatMap { day(on: $0, at: request.coordinates.latitude) }?
                    .shifted(days: -offset)
            })
        }
    }

    static func step(from latitude: Double) -> Double {
        Double(signOf: latitude, magnitudeOf: max(0, abs(latitude) - latitudeStep))
    }
}

private extension PrayerServiceAdhan {
    func fajrTime(with request: PrayerAPI.Request, from prayers: RawDay) -> Date {
        guard let adjustments = request.adjustments, adjustments.fajr != 0, adjustments.isFajrSunriseRelative else { return prayers.fajr }
        return PrayerTime.relativeFajr(minutes: adjustments.fajr, sunrise: prayers.sunrise, otherwise: prayers.fajr)
    }
}
