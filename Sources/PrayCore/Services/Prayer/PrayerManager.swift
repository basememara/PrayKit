//
//  PrayerManager.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-02-26.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import ZamzamCore

public struct PrayerManager {
    private let service: PrayerService
    private let londonService: PrayerService
    private let preferences: Preferences
    private let log: LogManager

    public init(service: PrayerService, londonService: PrayerService, preferences: Preferences, log: LogManager) {
        self.service = service
        self.londonService = londonService
        self.preferences = preferences
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
    enum Expanded {
        case finalHour
        case hourly
        case intervals(TimeInterval)
        case none
    }

    func fetch(from date: Date, expanded: Expanded, limit: Int, with request: PrayerAPI.Request) async throws -> [PrayerAPI.TimelineEntry] {
        let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone, locale: .posix)
        var entries = try await calculate(from: date, expanded: expanded, limit: limit, using: calendar, with: request, seed: [])

        // Insert specified date into timeline
        guard let insertIndex = entries.lastIndex(where: { $0.date < date }) else { return entries }
        let newEntry = PrayerAPI.TimelineEntry(date: date, prayerDay: entries[insertIndex].prayerDay)
        entries.insert(newEntry, at: insertIndex)

        return entries
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
        seed: [PrayerAPI.TimelineEntry]
    ) async throws -> [PrayerAPI.TimelineEntry] {
        let response: PrayerDay

        do {
            response = try await fetch(for: date, using: calendar, with: request)
        } catch {
            log.error("Could not fetch prayers for \(date, formatter: .zuluFormatter)", error: error)
            return seed
        }

        guard let currentPrayer = response.current(at: date) else {
            log.error("Could not retrieve current prayer from prayer day for \(date, formatter: .zuluFormatter)")
            return seed
        }

        let currentEntry = PrayerAPI.TimelineEntry(date: currentPrayer.dateInterval.start, prayerDay: response)
        var entries = response.times
            .filter { $0.dateInterval.start >= currentPrayer.dateInterval.end }
            .reduce(into: [currentEntry]) { result, next in
                let entry = PrayerAPI.TimelineEntry(date: next.dateInterval.start, prayerDay: response)
                result.append(entry)
            }

        switch expanded {
        case .finalHour:
            entries = entries.expandedWithFinalHour(using: preferences, calendar: calendar)
        case .hourly:
            entries = entries.expandedHourly(using: preferences, calendar: calendar)
        case let .intervals(progress):
            entries = entries.expanded(using: preferences, calendar: calendar, progressIntervals: progress)
        case .none:
            break
        }

        let resultSeed = seed + entries
        guard resultSeed.count < limit, let nextDate = response.tomorrow.first?.dateInterval.start else {
            return resultSeed.prefix(limit).array
        }

        // Recursively call until all prayers retrieved for limit
        return try await calculate(
            from: nextDate,
            expanded: expanded,
            limit: limit,
            using: calendar,
            with: request,
            seed: resultSeed
        )
    }
}

// MARK: - Extensions

private extension Array where Element == PrayerAPI.TimelineEntry {
    func expanded(using preferences: Preferences, calendar: Calendar, progressIntervals: TimeInterval) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            // Add entries to update progress at intervals
            if progressIntervals > 0 {
                result += stride(
                    from: currentPrayer.dateInterval.start.timeIntervalSince1970,
                    to: currentPrayer.dateInterval.end.timeIntervalSince1970,
                    by: currentPrayer.dateInterval.duration / progressIntervals
                ).map { timeInterval in
                    PrayerAPI.TimelineEntry(
                        date: Date(timeIntervalSince1970: timeInterval),
                        prayerDay: entry.prayerDay
                    )
                }
            } else {
                result.append(
                    PrayerAPI.TimelineEntry(
                        date: currentPrayer.dateInterval.start,
                        prayerDay: entry.prayerDay
                    )
                )
            }

            result += preferences
                .expandedTimeline(for: currentPrayer, using: calendar)
                .map { PrayerAPI.TimelineEntry(date: $0, prayerDay: entry.prayerDay) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}

private extension Array where Element == PrayerAPI.TimelineEntry {
    func expandedWithFinalHour(using preferences: Preferences, calendar: Calendar) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            result += [
                PrayerAPI.TimelineEntry(
                    date: currentPrayer.dateInterval.start,
                    prayerDay: entry.prayerDay
                ),
                PrayerAPI.TimelineEntry(
                    date: currentPrayer.dateInterval.end - .hours(1),
                    prayerDay: entry.prayerDay
                )
            ]

            result += preferences
                .expandedTimeline(for: currentPrayer, using: calendar)
                .map { PrayerAPI.TimelineEntry(date: $0, prayerDay: entry.prayerDay) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}

private extension Array where Element == PrayerAPI.TimelineEntry {
    func expandedHourly(using preferences: Preferences, calendar: Calendar) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            result += [
                PrayerAPI.TimelineEntry(
                    date: currentPrayer.dateInterval.start,
                    prayerDay: entry.prayerDay
                ),
                PrayerAPI.TimelineEntry(
                    date: currentPrayer.dateInterval.end - .hours(1),
                    prayerDay: entry.prayerDay
                )
            ]

            result += stride(
                from: currentPrayer.dateInterval.start.timeIntervalSince1970,
                to: currentPrayer.dateInterval.end.timeIntervalSince1970,
                by: 3600
            ).map { timeInterval in
                PrayerAPI.TimelineEntry(
                    date: Date(timeIntervalSince1970: timeInterval),
                    prayerDay: entry.prayerDay
                )
            }

            result += preferences
                .expandedTimeline(for: currentPrayer, using: calendar)
                .map { PrayerAPI.TimelineEntry(date: $0, prayerDay: entry.prayerDay) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}
