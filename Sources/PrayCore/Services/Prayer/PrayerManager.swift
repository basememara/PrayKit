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
    let timer: @Sendable (Date, PrayerDay) -> PrayerTimer?
    let expandedTimeline: @Sendable (PrayerTime, Calendar) -> [Date]

    init(settings: Settings, timeZone: TimeZone) {
        timer = { PrayerTimer(at: $0, using: $1, settings: settings, timeZone: timeZone) }
        expandedTimeline = { settings.expandedTimeline(for: $0, using: $1) }
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

        // Insert specified date into timeline
        if let insertIndex = entries.lastIndex(where: { $0.date < date }),
           let newEntry = context.timer(date, entries[insertIndex].prayerDay) {
            entries.insert(newEntry, at: insertIndex)
        }

        return entries
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

        let tomorrowStartOfDay = date.tomorrow(using: calendar).startOfDay
        if let entry = context.timer(tomorrowStartOfDay, prayerDay) {
            entries.append(entry)
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
