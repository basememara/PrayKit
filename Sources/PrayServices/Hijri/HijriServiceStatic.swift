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
    private let storage: SettingsStorage

    public init(prayerManager: PrayerManager, storage: SettingsStorage) {
        self.prayerManager = prayerManager
        self.storage = storage
    }
}

public extension HijriServiceStatic {
    static let holidays: [Holiday] = [
        Holiday(id: "new_year", month: 1, day: 1),
        Holiday(id: "ashura", month: 1, day: 10),
        Holiday(id: "isra_miraj", month: 7, day: 27),
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
        let state = storage.load()
        let settings = state.document.settings

        guard settings.autoIncrementHijri, let request = PrayerAPI.Request(settings: settings, place: state.place, filter: .obligation) else {
            return settings.hijriDayOffset
        }

        do {
            let prayerDay = try await prayerManager.fetch(at: time, with: request)
            return time.hijriDayOffset(
                for: prayerDay,
                hijriDayOffset: settings.hijriDayOffset,
                autoIncrementHijri: settings.autoIncrementHijri,
                timeZone: request.timeZone
            )
        } catch {
            return settings.hijriDayOffset
        }
    }
}

public extension HijriServiceStatic {
    func fetch(with request: HijriAPI.FetchTimelineRequest) async throws -> [HijriAPI.TimelineEntry] {
        let state = storage.load()
        let settings = state.document.settings

        let startOfDayTimeline: [HijriAPI.TimelineEntry] = await fetch(with: request)
            .map { HijriAPI.TimelineEntry(date: $0, timeZone: request.timeZone, hijriOffset: settings.hijriDayOffset) }

        guard settings.autoIncrementHijri,
              let prayerRequest = PrayerAPI.Request(settings: settings, place: state.place, timeZone: request.timeZone, filter: .obligation),
              let startDate = startOfDayTimeline.first?.date,
              let endDate = startOfDayTimeline.prefix(request.limit / 2).last?.date, // Leave room to interlace maghrib dates
              startDate <= endDate
        else {
            return startOfDayTimeline
        }

        do {
            // From the day before, which holds the first midnight until its Fajr
            let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone)
            let dateInterval = DateInterval(start: startDate.yesterday(using: calendar), end: endDate)
            let prayerDays = try await prayerManager.fetch(between: dateInterval, with: prayerRequest)
            let maghribs = prayerDays
                .compactMap { $0.times[.maghrib]?.dateInterval.start }
                .filter { $0 >= startDate }

            return (startOfDayTimeline.map(\.date) + maghribs)
                .sorted()
                .map { date in
                    HijriAPI.TimelineEntry(
                        date: date,
                        timeZone: request.timeZone,
                        hijriOffset: date.hijriDayOffset(
                            for: prayerDays.first { $0.contains(date) },
                            hijriDayOffset: settings.hijriDayOffset,
                            autoIncrementHijri: true,
                            timeZone: request.timeZone
                        )
                    )
                }
                .prefix(request.limit)
                .array
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

        // `enumerateDates` runs its block synchronously, so no continuation is needed.
        // The previous one resumed only from the guard branch and would strand the
        // caller forever if enumeration ended on its own.
        var elements = [Date]()

        calendar.enumerateDates(startingAfter: startAfterDate, matching: dateComponent, matchingPolicy: .nextTime) { date, _, stop in
            guard let date, elements.count < request.limit else {
                stop = true
                return
            }

            elements.append(date)
        }

        return elements
    }
}
