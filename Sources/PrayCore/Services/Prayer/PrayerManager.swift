//
//  PrayerManager.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-02-26.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import ZamzamCore

public struct PrayerManager: Sendable {
    private let service: PrayerService
    private let londonService: PrayerService
    private let log: LogManager

    public init(service: PrayerService, londonService: PrayerService, log: LogManager) {
        self.service = service
        self.londonService = londonService
        self.log = log
    }
}

public extension PrayerManager {
    func fetch(for date: Date, with request: PrayerAPI.Request) async throws -> PrayerDay {
        let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone, locale: .posix)
        async let result = fetch(for: date, using: calendar, with: request)
        return try await result
    }
}

public extension PrayerManager {
    /// The prayer day an instant belongs to: the one whose Fajr has begun and whose Isha hasn't ended at the next Fajr.
    /// Midnight is not a prayer boundary, so before Fajr this is the previous calendar day's.
    ///
    /// - Throws: `PrayError.invalidTimes` when no day's times contain the instant.
    func fetch(at instant: Date, with request: PrayerAPI.Request) async throws -> PrayerDay {
        let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone, locale: .posix)
        return try await day(containing: instant, from: instant, steps: 2, using: calendar, with: request)
    }

    /// The prayer day an instant belongs to, at the device's place with its settings.
    ///
    /// - Throws: `PrayError.locationFailure` before the device has a place.
    func fetch(at instant: Date, state: DeviceState, filter: PrayerFilter = .all) async throws -> PrayerDay {
        guard let request = PrayerAPI.Request(settings: state.document.settings, place: state.place, filter: filter) else {
            throw PrayError.locationFailure
        }

        return try await fetch(at: instant, with: request)
    }
}

public extension PrayerManager {
    /// The prayers of the day a date falls on, at the device's place with its settings.
    ///
    /// - Throws: `PrayError.locationFailure` before the device has a place.
    func fetch(for date: Date, state: DeviceState, filter: PrayerFilter = .all) async throws -> PrayerDay {
        guard let request = PrayerAPI.Request(settings: state.document.settings, place: state.place, filter: filter) else {
            throw PrayError.locationFailure
        }

        return try await fetch(for: date, with: request)
    }
}

public extension PrayerManager {
    enum Expanded: Sendable {
        case finalHour
        case hourly
        case intervals(TimeInterval)
        case none
    }

    /// The timeline built from settings, with timers counting in the place's time zone.
    func fetch(
        from date: Date,
        expanded: Expanded = .none,
        limit: Int,
        with request: PrayerAPI.Request,
        settings: Settings,
        timeZone: TimeZone
    ) async throws -> [PrayerTimer] {
        try await fetch(from: date, expanded: expanded, limit: limit, with: request, context: TimerContext(settings: settings, timeZone: timeZone))
    }
}

public extension PrayerManager {
    /// The prayer days holding the interval's moments, starting with the one holding its first, which before Fajr is
    /// the previous calendar day's. `fetch(between:)` takes the interval's calendar days instead.
    func fetch(spanning dateInterval: DateInterval, with request: PrayerAPI.Request) async throws -> [PrayerDay] {
        let firstDay = try await fetch(at: dateInterval.start, with: request)
        return try await fetch(between: DateInterval(start: firstDay.date, end: dateInterval.end), with: request)
    }

    /// The prayer days of each calendar day from the interval's start to its end.
    func fetch(between dateInterval: DateInterval, with request: PrayerAPI.Request) async throws -> [PrayerDay] {
        let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone, locale: .posix)
        let startAfterDate = dateInterval.start - .days(1, calendar)
        let dateComponent = calendar.dateComponents([.hour, .minute, .second], from: startAfterDate)
        var prayerDays = [PrayerDay]()

        try await withThrowingTaskGroup(of: PrayerDay.self) { group in
            calendar.enumerateDates(startingAfter: startAfterDate, matching: dateComponent, matchingPolicy: .nextTime) { (date, _, stop) in
                guard let date else { return }

                guard date <= dateInterval.end else {
                    stop = true
                    return
                }

                group.addTask {
                    try await fetch(for: date, with: request)
                }
            }

            for try await element in group {
                prayerDays.append(element)
            }
        }

        return prayerDays.sorted(by: \.date)
    }
}

// MARK: - Helpers

/// How a timeline builds its timers from the settings.
private struct TimerContext: Sendable {
    let settings: Settings
    let timeZone: TimeZone

    func timer(_ date: Date, _ prayerDay: PrayerDay) -> PrayerTimer? {
        PrayerTimer(at: date, using: prayerDay, settings: settings, timeZone: timeZone)
    }

    /// A timer from whichever day holds the moment, since a reminder before Fajr belongs to the night before.
    func timer(_ date: Date, in days: [PrayerDay]) -> PrayerTimer? {
        days.first { $0.contains(date) }.flatMap { timer(date, $0) }
    }

    func expandedTimeline(_ prayerTime: PrayerTime, _ calendar: Calendar) -> [Date] {
        settings.expandedTimeline(for: prayerTime, using: calendar)
    }
}

private extension PrayerManager {
    func fetch(
        from date: Date,
        expanded: Expanded,
        limit: Int,
        with request: PrayerAPI.Request,
        context: TimerContext
    ) async throws -> [PrayerTimer] {
        let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone, locale: .posix)
        let firstDay = try await fetch(at: date, with: request)
        let previousDay = try? await fetch(for: firstDay.date.yesterday(using: calendar), using: calendar, with: request)

        var entries = try await calculate(
            day: firstDay,
            from: date,
            after: previousDay,
            expanded: expanded,
            limit: limit,
            using: calendar,
            with: request,
            context: context,
            seed: []
        )

        // The requested moment goes after the last entry before it, unless one already starts then
        if !entries.contains(where: { $0.date == date }),
           let lastIndex = entries.lastIndex(where: { $0.date < date }),
           let newEntry = context.timer(date, firstDay) {
            entries.insert(newEntry, at: lastIndex + 1)
        }

        return entries
    }
}

private extension PrayerManager {
    /// Steps from a calendar day toward the one whose span holds the instant: back while it's before that day's Fajr,
    /// forward once its Isha has ended. A Fajr adjustment or a distant time zone can put a day's Fajr before midnight.
    func day(
        containing instant: Date,
        from date: Date,
        steps: Int,
        using calendar: Calendar,
        with request: PrayerAPI.Request
    ) async throws -> PrayerDay {
        let day = try await fetch(for: date, using: calendar, with: request)

        guard let fajr = day.times[.fajr], let isha = day.times[.isha] else {
            log.error("Could not find the prayer day for \(instant, formatter: .zuluFormatter) without its Fajr and Isha")
            throw PrayError.invalidTimes
        }

        if steps > 0, instant < fajr.dateInterval.start {
            return try await self.day(containing: instant, from: date.yesterday(using: calendar), steps: steps - 1, using: calendar, with: request)
        }

        if steps > 0, instant >= isha.dateInterval.end {
            return try await self.day(containing: instant, from: date.tomorrow(using: calendar), steps: steps - 1, using: calendar, with: request)
        }

        guard day.contains(instant) else {
            log.error("Could not find the prayer day for \(instant, formatter: .zuluFormatter)")
            throw PrayError.invalidTimes
        }

        return day
    }
}

private extension PrayerManager {
    func fetch(for date: Date, using calendar: Calendar, with request: PrayerAPI.Request) async throws -> PrayerDay {
        let prayerService = request.method == .london ? londonService : service

        return PrayerDay(
            date: date.startOfDay(using: calendar),
            times: try await prayerService.calculate(for: date, using: calendar, with: request),
            yesterday: try await prayerService.calculate(for: date.yesterday(using: calendar), using: calendar, with: request),
            tomorrow: try await prayerService.calculate(for: date.tomorrow(using: calendar), using: calendar, with: request)
        )
    }
}

private extension PrayerManager {
    /// The timers of one prayer day from a moment in it, then of each day after it until the limit.
    func calculate(
        day prayerDay: PrayerDay,
        from date: Date,
        after previousDay: PrayerDay?,
        expanded: Expanded,
        limit: Int,
        using calendar: Calendar,
        with request: PrayerAPI.Request,
        context: TimerContext,
        seed: [PrayerTimer]
    ) async throws -> [PrayerTimer] {
        let days = [previousDay, prayerDay].compactMap { $0 }

        guard let currentPrayer = prayerDay.current(at: date) else {
            log.error("Could not retrieve current prayer from prayer day for \(date, formatter: .zuluFormatter)")
            return seed
        }

        guard let currentEntry = context.timer(currentPrayer.dateInterval.start, prayerDay) else {
            log.error("Could not initialize prayer timer from prayer day for \(date, formatter: .zuluFormatter)")
            return seed
        }

        var entries = prayerDay.times
            .filter { $0.dateInterval.start >= currentPrayer.dateInterval.end }
            .reduce(into: [currentEntry]) { result, next in
                guard let entry = context.timer(next.dateInterval.start, prayerDay) else { return }
                result.append(entry)
            }

        switch expanded {
        case .finalHour:
            entries = entries.expandedWithFinalHour(using: context, in: days, calendar: calendar)
        case .hourly:
            entries = entries.expandedHourly(using: context, in: days, calendar: calendar)
        case let .intervals(progress):
            entries = entries.expanded(using: context, in: days, calendar: calendar, progressIntervals: progress)
        case .none:
            break
        }

        // Midnight changes no prayer, but it turns the calendar date and, without auto-increment, the Hijri date the
        // faces show. It goes in date order, since the expanded entries can already reach past it.
        let midnight = prayerDay.date.tomorrow(using: calendar)
        if prayerDay.contains(midnight), !entries.contains(where: { $0.date == midnight }), let entry = context.timer(midnight, prayerDay) {
            entries.insert(entry, at: entries.firstIndex { $0.date > midnight } ?? entries.endIndex)
        }

        let resultSeed = seed + entries
        guard resultSeed.count < limit else { return resultSeed.prefix(limit).array }

        let nextDay: PrayerDay

        do {
            nextDay = try await fetch(for: prayerDay.date.tomorrow(using: calendar), using: calendar, with: request)
        } catch {
            log.error("Could not fetch prayers for the day after \(prayerDay.date, formatter: .zuluFormatter)", error: error)
            return resultSeed.prefix(limit).array
        }

        guard let nextFajr = nextDay.times[.fajr]?.dateInterval.start else { return resultSeed.prefix(limit).array }

        // Recursively call until all prayers retrieved for limit
        return try await calculate(
            day: nextDay,
            from: nextFajr,
            after: prayerDay,
            expanded: expanded,
            limit: limit,
            using: calendar,
            with: request,
            context: context,
            seed: resultSeed
        )
    }
}

// MARK: - Extensions

private extension Array where Element == PrayerTimer {
    func expanded(using context: TimerContext, in days: [PrayerDay], calendar: Calendar, progressIntervals: TimeInterval) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            // Add entries to update progress at intervals
            if progressIntervals > 0 {
                result += stride(
                    from: currentPrayer.dateInterval.start.timeIntervalSince1970,
                    to: currentPrayer.dateInterval.end.timeIntervalSince1970,
                    by: currentPrayer.dateInterval.duration / progressIntervals
                ).compactMap { timeInterval in
                    context.timer(Date(timeIntervalSince1970: timeInterval), in: days)
                }
            } else if let prayerTimer = context.timer(currentPrayer.dateInterval.start, in: days) {
                result.append(prayerTimer)
            }

            result += context
                .expandedTimeline(currentPrayer, calendar)
                .compactMap { context.timer($0, in: days) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}

private extension Array where Element == PrayerTimer {
    func expandedWithFinalHour(using context: TimerContext, in days: [PrayerDay], calendar: Calendar) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            result += [
                context.timer(currentPrayer.dateInterval.start, in: days),
                context.timer(currentPrayer.dateInterval.end - .hours(1), in: days)
            ].compactMap { $0 }

            result += context
                .expandedTimeline(currentPrayer, calendar)
                .compactMap { context.timer($0, in: days) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}

private extension Array where Element == PrayerTimer {
    func expandedHourly(using context: TimerContext, in days: [PrayerDay], calendar: Calendar) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            result += [
                context.timer(currentPrayer.dateInterval.start, in: days),
                context.timer(currentPrayer.dateInterval.end - .hours(1), in: days)
            ].compactMap { $0 }

            result += stride(
                from: currentPrayer.dateInterval.start.timeIntervalSince1970,
                to: currentPrayer.dateInterval.end.timeIntervalSince1970,
                by: 3600
            ).compactMap { timeInterval in
                context.timer(Date(timeIntervalSince1970: timeInterval), in: days)
            }

            result += context
                .expandedTimeline(currentPrayer, calendar)
                .compactMap { context.timer($0, in: days) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}
