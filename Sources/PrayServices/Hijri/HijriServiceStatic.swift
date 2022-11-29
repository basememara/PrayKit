//
//  HijriServiceStatic.swift
//  PrayServices
//
//  Created by Basem Emara on 2022-03-17.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation.NSDateInterval
import PrayCore
import ZamzamCore

public struct HijriServiceStatic: HijriService {
    private let prayerManager: PrayerManager
    private let preferences: Preferences

    public init(prayerManager: PrayerManager, preferences: Preferences) {
        self.prayerManager = prayerManager
        self.preferences = preferences
    }
}

public extension HijriServiceStatic {
    static let holidays: [Holiday] = [
        Holiday(id: "new_year", month: 1, day: 1),
        Holiday(id: "ashura", month: 1, day: 10),
        Holiday(id: "ramadan", month: 9, day: 1),
        Holiday(id: "eid_fitr", month: 10, day: 1),
        Holiday(id: "hajj", month: 12, day: 8),
        Holiday(id: "arafah", month: 12, day: 9),
        Holiday(id: "eid_al_adha", month: 12, day: 10)
    ]

    func fetch(with request: HijriAPI.FetchHolidaysRequest) -> [Holiday] {
        Self.holidays
    }
}

public extension HijriServiceStatic {
    func fetchOffset(for time: Date) async throws -> Int {
        guard preferences.autoIncrementHijri, let request = PrayerAPI.Request(from: preferences, filter: .obligation) else {
            return preferences.hijriDayOffset
        }

        do {
            let prayerDay = try await prayerManager.fetch(for: time, with: request)
            return time.hijriDayOffset(for: prayerDay, hijriDayOffset: preferences.hijriDayOffset, autoIncrementHijri: preferences.autoIncrementHijri)
        } catch {
            return preferences.hijriDayOffset
        }
    }
}

public extension HijriServiceStatic {
    func fetch(with request: HijriAPI.FetchTimelineRequest) async throws -> [HijriAPI.TimelineEntry] {
        let startOfDayTimeline: [HijriAPI.TimelineEntry] = await fetch(with: request)
            .map { HijriAPI.TimelineEntry(date: $0, timeZone: request.timeZone, hijriOffset: preferences.hijriDayOffset) }

        guard preferences.autoIncrementHijri,
              let prayerRequest = PrayerAPI.Request(from: preferences, timeZone: request.timeZone, filter: .obligation),
              let startDate = startOfDayTimeline.first?.date,
              let endDate = startOfDayTimeline.prefix(request.limit / 2).last?.date, // Leave room to interlace maghrib dates
              startDate <= endDate
        else {
            return startOfDayTimeline
        }

        do {
            let dateInterval = DateInterval(start: startDate, end: endDate)
            let maghribTimeline = try await prayerManager.fetch(between: dateInterval, with: prayerRequest)
                .compactMap { $0.times[.maghrib]?.dateInterval.start }
                .map { HijriAPI.TimelineEntry(date: $0, timeZone: request.timeZone, hijriOffset: preferences.hijriDayOffset + 1) }
            return (startOfDayTimeline + maghribTimeline).sorted(by: \.date).prefix(request.limit).array
        } catch {
            return startOfDayTimeline
        }
    }
}

// MARK: - Helpers

private extension HijriServiceStatic {
    func fetch(with request: HijriAPI.FetchTimelineRequest) async -> [Date] {
        var calendar = Date.islamicCalendar
        calendar.timeZone = request.timeZone

        let startAfterDate = request.startDate.startOfDay(using: calendar) - .days(1, calendar)
        let dateComponent = calendar.dateComponents([.hour, .minute, .second], from: startAfterDate)

        return await withCheckedContinuation { continuation in
            var elements = [Date]()

            calendar.enumerateDates(startingAfter: startAfterDate, matching: dateComponent, matchingPolicy: .nextTime) { (date, _, stop) in
                guard let date, elements.count < request.limit else {
                    stop = true
                    continuation.resume(returning: elements)
                    return
                }

                elements.append(date)
            }
        }
    }
}
