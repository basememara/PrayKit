//
//  PrayerServiceLondon.swift
//  PrayServices
//
//  Created by Basem Emara on 2022-02-26.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import ZamzamCore

/// `UserDefaults` is documented as thread-safe, hence the unchecked conformance.
public struct PrayerServiceLondon: PrayerService, @unchecked Sendable {
    private let networkManager: NetworkManager
    private let defaults: UserDefaults
    private let apiKey: String
    private let log: LogManager
    private let cache = LondonPrayerTimetableCache()

    private static let filePrefix = "london-"

    /// How long a year the API hasn't published waits before it's asked for again, by every process sharing the suite.
    private static let unpublishedRetryInterval: TimeInterval = 6 * 3600

    /// Where a year fetched from the API is kept, apart from the settings that share the suite.
    static func cacheKey(forYear year: Int) -> String {
        "londonTimetable-\(year)"
    }

    /// When the API last answered that a year had no days yet.
    static func askedKey(forYear year: Int) -> String {
        "londonTimetableAsked-\(year)"
    }

    /// The last year the bundled timetables cover, from the newest `london-<year>.json`.
    static let lastYear = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: nil)?
        .compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            return name.hasPrefix(filePrefix) ? Int(name.dropFirst(filePrefix.count)) : nil
        }
        .max()

    public init(
        networkManager: NetworkManager,
        apiKey: String,
        log: LogManager,
        defaults: UserDefaults = UserDefaults(suiteName: "PrayerServiceLondon") ?? .standard
    ) {
        self.networkManager = networkManager
        self.defaults = defaults
        self.apiKey = apiKey
        self.log = log
    }
}

public extension PrayerServiceLondon {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func calculate(
        for date: Date,
        using calendar: Calendar,
        with request: PrayerAPI.Request
    ) async throws -> [PrayerTime] {
        let calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone, locale: .posix)
        let dateFormatter = DateFormatter(dateFormat: "yyyy-MM-dd", calendar: calendar)
        let timeFormatter = DateFormatter(dateFormat: "yyyy-MM-dd HH:mm", calendar: calendar)

        let year = calendar.component(.year, from: date)
        let prayerDays = try await fetch(for: year)

        let dateKey = dateFormatter.string(from: date)
        guard let prayerTimes = prayerDays[dateKey] else { throw PrayError.invalidTimes }

        guard var fajrTime = timeFormatter.date(from: [dateKey, prayerTimes.fajr].joined(separator: " ")),
              var sunriseTime = timeFormatter.date(from: [dateKey, prayerTimes.sunrise].joined(separator: " ")),
              var dhuhrTime = timeFormatter.date(from: [dateKey, prayerTimes.dhuhr].joined(separator: " ")),
              var asrTime = timeFormatter.date(from: [dateKey, request.jurisprudence == .hanafi ? prayerTimes.asr_2 : prayerTimes.asr].joined(separator: " ")),
              var magribTime = timeFormatter.date(from: [dateKey, prayerTimes.magrib].joined(separator: " ")),
              var ishaTime = timeFormatter.date(from: [dateKey, prayerTimes.isha].joined(separator: " "))
        else {
            log.error("Could not initialize prayer times from London prayer response.")
            throw PrayError.invalidTimes
        }

        let tomorrowKey = dateFormatter.string(from: date.tomorrow(using: calendar))
        let tomorrowPrayers: PrayerServiceLondon.LondonPrayerTimes?

        if prayerDays.keys.contains(tomorrowKey) {
            tomorrowPrayers = prayerDays[tomorrowKey]
        } else {
            // Handle end of year cross-over
            let tomorrowYear = calendar.component(.year, from: date.tomorrow(using: calendar))
            tomorrowPrayers = try await fetch(for: tomorrowYear)[tomorrowKey]
        }

        guard let tomorrowPrayers,
              var tomorrowFajrTime = timeFormatter.date(from: [tomorrowKey, tomorrowPrayers.fajr].joined(separator: " ")),
              var tomorrowSunriseTime = timeFormatter.date(from: [tomorrowKey, tomorrowPrayers.sunrise].joined(separator: " "))
        else {
            log.error("Could not initialize tomorrow prayer times from London prayer response.")
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

// MARK: - Helpers

/// The parsed timetables by year. `PrayerManager.fetch(between:)` fans out through a task group, so the days of a year
/// share its one load; a load that fails or finds no days isn't kept, so the year is loaded again next time.
private actor LondonPrayerTimetableCache {
    typealias Timetable = [String: PrayerServiceLondon.LondonPrayerTimes]

    private var loads = [Int: Task<Timetable, Error>]()

    func timetable(for year: Int, load: @escaping @Sendable () async throws -> Timetable) async throws -> Timetable {
        if let task = loads[year] {
            return try await task.value
        }

        let task = Task(operation: load)
        loads[year] = task

        do {
            let timetable = try await task.value
            if timetable.isEmpty {
                loads[year] = nil
            }

            return timetable
        } catch {
            loads[year] = nil
            throw error
        }
    }
}

private extension PrayerServiceLondon {
    func fetch(for year: Int) async throws -> [String: LondonPrayerTimes] {
        try await cache.timetable(for: year) { try await load(year) }
    }

    func load(_ year: Int) async throws -> [String: LondonPrayerTimes] {
        let key = String(year)
        let data: Data

        // The bundle comes first, so a copy saved from the network never hides a year the app ships
        if let url = fileURL(forYear: year),
            let contents = try? Data(contentsOf: url) {
            // Retrieve from embedded file
            log.debug("Fetched Unified London Prayer Timetable for '\(key)' from bundle")
            data = contents
        } else if let value = defaults.data(forKey: Self.cacheKey(forYear: year)) {
            // Retrieve from user defaults
            log.debug("Fetched Unified London Prayer Timetable for '\(key)' from User Defaults")
            data = value
        } else if let asked = defaults.object(forKey: Self.askedKey(forYear: year)) as? Date,
                  Date.now.timeIntervalSince(asked) < Self.unpublishedRetryInterval {
            log.debug("Unified London Prayer Timetable for '\(key)' had no days when last asked, so it isn't asked again yet")
            return [:]
        } else {
            // Retrieve remotely from endpoint
            log.warning("Fetching Unified London Prayer Timetable for '\(key)' from network...")
            let url = URL(safeString: "https://www.londonprayertimes.com/api/times/").appending(
                queryItems: [
                    URLQueryItem(name: "key", value: apiKey),
                    URLQueryItem(name: "year", value: key),
                    URLQueryItem(name: "24hours", value: "true"),
                    URLQueryItem(name: "format", value: "json")
                ]
            )

            do {
                data = try await networkManager.send(URLRequest(url: url)).data
                log.debug("Fetched Unified London Prayer Timetable for '\(key)' from network successfully")
            } catch {
                // A year that can't be fetched has no times, like a day its timetable doesn't reach
                log.error("Could not fetch the Unified London Prayer Timetable for '\(key)'", error: error)
                throw PrayError.invalidTimes
            }
        }

        // Parse and save to cache
        return try save(data: data, for: year)
    }

    func save(data: Data, for year: Int) throws -> [String: PrayerServiceLondon.LondonPrayerTimes] {
        let key = String(year)
        let cacheKey = Self.cacheKey(forYear: year)
        let decoded: PrayerServiceLondon.ServerResponse

        do {
            decoded = try JSONDecoder().decode(ServerResponse.self, from: data)
        } catch {
            log.error("An error occured while storing Unified London Prayer Timetable for '\(key)' into cache", error: error)
            throw error
        }

        // The API answers a year it hasn't published with no days, so it's asked again once the wait has passed
        guard !decoded.times.isEmpty else {
            log.warning("Unified London Prayer Timetable for '\(key)' has no days yet, so it isn't kept")
            defaults.removeObject(forKey: cacheKey)
            defaults.set(Date.now, forKey: Self.askedKey(forYear: year))
            return [:]
        }

        // Persist in user preferences
        defaults.removeObject(forKey: Self.askedKey(forYear: year))
        if defaults.object(forKey: cacheKey) == nil {
            defaults.set(data, forKey: cacheKey)
            defaults.removeObject(forKey: Self.cacheKey(forYear: year - 2))
        }

        log.debug("Stored Unified London Prayer Timetable for '\(key)' into cache successfully")
        return decoded.times
    }

    func fileURL(forYear year: Int) -> URL? {
        Bundle.module.url(forResource: Self.filePrefix + String(year), withExtension: "json")
    }
}

// MARK: - Types

private extension PrayerServiceLondon {
    struct ServerResponse: Decodable {
        let times: [String: LondonPrayerTimes]

        private enum CodingKeys: CodingKey {
            case times
        }
    }

    struct LondonPrayerTimes: Decodable {
        let date: String
        let fajr: String
        let fajr_jamat: String
        let sunrise: String
        let dhuhr: String
        let dhuhr_jamat: String
        let asr: String
        let asr_2: String
        let asr_jamat: String
        let magrib: String
        let magrib_jamat: String
        let isha: String
        let isha_jamat: String
    }
}
