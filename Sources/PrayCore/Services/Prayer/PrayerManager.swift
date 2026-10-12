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
        var entries = try await calculate(from: date, expanded: expanded, limit: limit, using: calendar, with: request, context: context, seed: [])

        // The requested moment goes after the last entry before it, unless one already starts then
        if !entries.contains(where: { $0.date == date }),
           let lastIndex = entries.lastIndex(where: { $0.date < date }),
           let newEntry = context.timer(date, entries[lastIndex].prayerDay) {
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
    func calculate(
        from date: Date,
        expanded: Expanded,
        limit: Int,
        using calendar: Calendar,
        with request: PrayerAPI.Request,
        context: TimerContext,
        seed: [PrayerTimer]
    ) async throws -> [PrayerTimer] {
        let prayerDay: PrayerDay

        do {
            prayerDay = try await fetch(for: date, using: calendar, with: request)
        } catch {
            log.error("Could not fetch prayers for \(date, formatter: .zuluFormatter)", error: error)
            return seed
        }

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
            entries = entries.expandedWithFinalHour(using: context, calendar: calendar)
        case .hourly:
            entries = entries.expandedHourly(using: context, calendar: calendar)
        case let .intervals(progress):
            entries = entries.expanded(using: context, calendar: calendar, progressIntervals: progress)
        case .none:
            break
        }

        // Midnight goes in date order: the expanded entries can already reach into tomorrow
        let tomorrowStartOfDay = date.tomorrow(using: calendar).startOfDay(using: calendar)
        if !entries.contains(where: { $0.date == tomorrowStartOfDay }), let entry = context.timer(tomorrowStartOfDay, prayerDay) {
            entries.insert(entry, at: entries.firstIndex { $0.date > tomorrowStartOfDay } ?? entries.endIndex)
        }

        let resultSeed = seed + entries
        guard resultSeed.count < limit, let nextDate = prayerDay.tomorrow.first?.dateInterval.start else {
            return resultSeed.prefix(limit).array
        }

        // Recursively call until all prayers retrieved for limit
        return try await calculate(
            from: nextDate,
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
    func expanded(using context: TimerContext, calendar: Calendar, progressIntervals: TimeInterval) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            // Add entries to update progress at intervals
            if progressIntervals > 0 {
                result += stride(
                    from: currentPrayer.dateInterval.start.timeIntervalSince1970,
                    to: currentPrayer.dateInterval.end.timeIntervalSince1970,
                    by: currentPrayer.dateInterval.duration / progressIntervals
                ).compactMap { timeInterval in
                    context.timer(Date(timeIntervalSince1970: timeInterval), entry.prayerDay)
                }
            } else if let prayerTimer = context.timer(currentPrayer.dateInterval.start, entry.prayerDay) {
                result.append(prayerTimer)
            }

            result += context
                .expandedTimeline(currentPrayer, calendar)
                .compactMap { context.timer($0, entry.prayerDay) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}

private extension Array where Element == PrayerTimer {
    func expandedWithFinalHour(using context: TimerContext, calendar: Calendar) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            result += [
                context.timer(currentPrayer.dateInterval.start, entry.prayerDay),
                context.timer(currentPrayer.dateInterval.end - .hours(1), entry.prayerDay)
            ].compactMap { $0 }

            result += context
                .expandedTimeline(currentPrayer, calendar)
                .compactMap { context.timer($0, entry.prayerDay) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}

private extension Array where Element == PrayerTimer {
    func expandedHourly(using context: TimerContext, calendar: Calendar) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            result += [
                context.timer(currentPrayer.dateInterval.start, entry.prayerDay),
                context.timer(currentPrayer.dateInterval.end - .hours(1), entry.prayerDay)
            ].compactMap { $0 }

            result += stride(
                from: currentPrayer.dateInterval.start.timeIntervalSince1970,
                to: currentPrayer.dateInterval.end.timeIntervalSince1970,
                by: 3600
            ).compactMap { timeInterval in
                context.timer(Date(timeIntervalSince1970: timeInterval), entry.prayerDay)
            }

            result += context
                .expandedTimeline(currentPrayer, calendar)
                .compactMap { context.timer($0, entry.prayerDay) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}
