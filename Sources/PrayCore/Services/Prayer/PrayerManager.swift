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

    func fetch(from date: Date, expanded: Expanded = .none, limit: Int, with request: PrayerAPI.Request) async throws -> [PrayerTimer] {
        let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone, locale: .posix)
        var entries = try await calculate(from: date, expanded: expanded, limit: limit, using: calendar, with: request, seed: [])

        // Insert specified date into timeline
        if let insertIndex = entries.lastIndex(where: { $0.date < date }),
           let newEntry = PrayerTimer(at: date, using: entries[insertIndex].prayerDay, preferences: preferences) {
            entries.insert(newEntry, at: insertIndex)
        }

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

        guard let currentEntry = PrayerTimer(at: currentPrayer.dateInterval.start, using: prayerDay, preferences: preferences) else {
            log.error("Could not initialize prayer timer from prayer day for \(date, formatter: .zuluFormatter)")
            return seed
        }

        var entries = prayerDay.times
            .filter { $0.dateInterval.start >= currentPrayer.dateInterval.end }
            .reduce(into: [currentEntry]) { result, next in
                guard let entry = PrayerTimer(at: next.dateInterval.start, using: prayerDay, preferences: preferences) else { return }
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
            seed: resultSeed
        )
    }
}

// MARK: - Extensions

private extension Array where Element == PrayerTimer {
    func expanded(using preferences: Preferences, calendar: Calendar, progressIntervals: TimeInterval) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            // Add entries to update progress at intervals
            if progressIntervals > 0 {
                result += stride(
                    from: currentPrayer.dateInterval.start.timeIntervalSince1970,
                    to: currentPrayer.dateInterval.end.timeIntervalSince1970,
                    by: currentPrayer.dateInterval.duration / progressIntervals
                ).compactMap { timeInterval in
                    PrayerTimer(
                        at: Date(timeIntervalSince1970: timeInterval),
                        using: entry.prayerDay,
                        preferences: preferences
                    )
                }
            } else if let prayerTimer = PrayerTimer(at: currentPrayer.dateInterval.start, using: entry.prayerDay, preferences: preferences) {
                result.append(prayerTimer)
            }

            result += preferences
                .expandedTimeline(for: currentPrayer, using: calendar)
                .compactMap { PrayerTimer(at: $0, using: entry.prayerDay, preferences: preferences) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}

private extension Array where Element == PrayerTimer {
    func expandedWithFinalHour(using preferences: Preferences, calendar: Calendar) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            result += [
                PrayerTimer(
                    at: currentPrayer.dateInterval.start,
                    using: entry.prayerDay,
                    preferences: preferences
                ),
                PrayerTimer(
                    at: currentPrayer.dateInterval.end - .hours(1),
                    using: entry.prayerDay,
                    preferences: preferences
                )
            ].compactMap { $0 }

            result += preferences
                .expandedTimeline(for: currentPrayer, using: calendar)
                .compactMap { PrayerTimer(at: $0, using: entry.prayerDay, preferences: preferences) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}

private extension Array where Element == PrayerTimer {
    func expandedHourly(using preferences: Preferences, calendar: Calendar) -> Self {
        reduce(into: []) { result, entry in
            guard let currentPrayer = entry.prayerDay.current(at: entry.date) else { return }

            result += [
                PrayerTimer(
                    at: currentPrayer.dateInterval.start,
                    using: entry.prayerDay,
                    preferences: preferences
                ),
                PrayerTimer(
                    at: currentPrayer.dateInterval.end - .hours(1),
                    using: entry.prayerDay,
                    preferences: preferences
                )
            ].compactMap { $0 }

            result += stride(
                from: currentPrayer.dateInterval.start.timeIntervalSince1970,
                to: currentPrayer.dateInterval.end.timeIntervalSince1970,
                by: 3600
            ).compactMap { timeInterval in
                PrayerTimer(
                    at: Date(timeIntervalSince1970: timeInterval),
                    using: entry.prayerDay,
                    preferences: preferences
                )
            }

            result += preferences
                .expandedTimeline(for: currentPrayer, using: calendar)
                .compactMap { PrayerTimer(at: $0, using: entry.prayerDay, preferences: preferences) }
        }
        .removeDuplicates()
        .sorted(by: \.date)
    }
}
