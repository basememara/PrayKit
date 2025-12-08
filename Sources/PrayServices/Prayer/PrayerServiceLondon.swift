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

public struct PrayerServiceLondon: PrayerService {
    private let networkManager: NetworkManager
    private let defaults: UserDefaults
    private let apiKey: String
    private let log: LogManager
    private let lastDate = Date(year: 2026, month: 12, day: 31)

    public init(networkManager: NetworkManager, apiKey: String, log: LogManager) {
        self.networkManager = networkManager
        self.defaults = UserDefaults(suiteName: "PrayerServiceLondon") ?? .standard
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

        // Validate does not go beyond available dates
        guard date <= lastDate ?? .now.endOfYear(using: calendar) else {
            log.warning("London prayers not available for '\(date.formatted())'")
            return []
        }

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
              let originalTomorrowFajrTime = timeFormatter.date(from: [tomorrowKey, tomorrowPrayers.fajr].joined(separator: " ")),
              let tomorrowSunriseTime = timeFormatter.date(from: [tomorrowKey, tomorrowPrayers.sunrise].joined(separator: " "))
        else {
            log.error("Could not initialize tomorrow prayer times from London prayer response.")
            throw PrayError.invalidTimes
        }

        var tomorrowFajrTime = originalTomorrowFajrTime

        // Apply user adjustments if applicable
        if let adjustments = request.adjustments, request.adjustments?.isEmpty == false {
            if adjustments.sunrise != 0 {
                sunriseTime = (sunriseTime + .minutes(adjustments.sunrise)).roundedMinute(using: calendar)
            }

            if adjustments.fajr != 0 {
                fajrTime = (fajrTime + .minutes(adjustments.fajr)).roundedMinute(using: calendar)
                tomorrowFajrTime = (tomorrowFajrTime + .minutes(adjustments.fajr)).roundedMinute(using: calendar)

                if adjustments.isFajrSunriseRelative {
                    let fajr = sunriseTime + .minutes(adjustments.fajr)
                    fajrTime = fajr < sunriseTime ? fajr : fajrTime

                    let tomorrowFajr = tomorrowSunriseTime + .minutes(adjustments.fajr)
                    tomorrowFajrTime = tomorrowFajr < tomorrowSunriseTime ? tomorrowFajr : tomorrowFajrTime
                }
            }

            if adjustments.dhuhr != 0 {
                dhuhrTime = (dhuhrTime + .minutes(adjustments.dhuhr)).roundedMinute(using: calendar)
            }

            if adjustments.asr != 0 {
                asrTime = (asrTime + .minutes(adjustments.asr)).roundedMinute(using: calendar)
            }

            if adjustments.maghrib != 0 {
                magribTime = (magribTime + .minutes(adjustments.maghrib)).roundedMinute(using: calendar)
            }

            if adjustments.isha != 0 {
                ishaTime = (ishaTime + .minutes(adjustments.isha)).roundedMinute(using: calendar)

                if adjustments.isIshaMaghribRelative {
                    let isha = magribTime + .minutes(adjustments.isha)
                    ishaTime = isha < tomorrowFajrTime ? isha : ishaTime
                }
            }
        }

        guard fajrTime < sunriseTime else {
            log.error("Fajr was invalid due to resulting after sunrise.")
            throw PrayError.invalidTimes
        }

        var times = [PrayerTime]()

        times.append(
            PrayerTime(
                type: .fajr,
                dateInterval: .init(
                    start: fajrTime,
                    end: sunriseTime
                )
            )
        )

        if [.all, .essential].contains(request.filter) {
            guard sunriseTime < dhuhrTime else {
                log.error("Sunrise was invalid due to resulting after dhuhr.")
                throw PrayError.invalidTimes
            }

            times.append(
                PrayerTime(
                    type: .sunrise,
                    dateInterval: .init(
                        start: sunriseTime,
                        end: dhuhrTime
                    )
                )
            )
        }

        guard dhuhrTime < asrTime else {
            log.error("Dhuhr was invalid due to resulting after asr.")
            throw PrayError.invalidElevation
        }

        guard asrTime < magribTime else {
            log.error("Asr was invalid due to resulting after maghrib.")
            throw PrayError.invalidElevation
        }

        guard magribTime < ishaTime else {
            log.error("Maghrib was invalid due to resulting after isha.")
            throw PrayError.invalidElevation
        }

        guard ishaTime < tomorrowFajrTime else {
            log.error("Isha was invalid due to resulting after tomorrow's fajr.")
            throw PrayError.invalidElevation
        }

        times.append(contentsOf: [
            PrayerTime(
                type: .dhuhr,
                dateInterval: .init(
                    start: dhuhrTime,
                    end: asrTime
                )
            ),
            PrayerTime(
                type: .asr,
                dateInterval: .init(
                    start: asrTime,
                    end: magribTime
                )
            ),
            PrayerTime(
                type: .maghrib,
                dateInterval: .init(
                    start: magribTime,
                    end: ishaTime
                )
            ),
            PrayerTime(
                type: .isha,
                dateInterval: .init(
                    start: ishaTime,
                    end: tomorrowFajrTime
                )
            )
        ])

        // Implementation taken from Adhan lib
        if [.all, .sunnah].contains(request.filter) {
            let nightDuration = originalTomorrowFajrTime.timeIntervalSince(magribTime)
            let middleOfTheNight = magribTime.addingTimeInterval(nightDuration / 2).roundedMinute(using: calendar)
            let lastThirdOfTheNight = magribTime.addingTimeInterval(nightDuration * (2 / 3)).roundedMinute(using: calendar)

            guard middleOfTheNight < lastThirdOfTheNight, lastThirdOfTheNight < originalTomorrowFajrTime else {
                log.error("Sunnah prayers were invalid due to resulting after tomorrow's fajr.")
                throw PrayError.invalidTimes
            }

            times.append(contentsOf: [
                PrayerTime(
                    type: .midnight,
                    dateInterval: .init(
                        start: middleOfTheNight,
                        end: lastThirdOfTheNight
                    )
                ),
                PrayerTime(
                    type: .lastThird,
                    dateInterval: .init(
                        start: lastThirdOfTheNight,
                        end: originalTomorrowFajrTime
                    )
                )
            ])
        }

        return times
    }
}

// MARK: - Helpers

private extension PrayerServiceLondon {
    static var cachedData = [String: [String: LondonPrayerTimes]]()
    static let jsonDecoder = JSONDecoder()
    static let jsonEncoder = JSONEncoder()

    func fetch(for year: Int) async throws -> [String: LondonPrayerTimes] {
        let key = String(year)

        // Retrieve from memory if available
        if let cache = Self.cachedData[key] {
            return cache
        }

        // Construct data
        let data: Data

        if let value = defaults.data(forKey: key) {
            // Retrieve from user defaults
            log.debug("Fetched Unified London Prayer Timetable for '\(key)' from User Defaults")
            data = value
        } else if let url = fileURL(forYear: year),
            let contents = try? Data(contentsOf: url) {
            // Retrieve from embedded file
            log.debug("Fetched Unified London Prayer Timetable for '\(key)' from bundle")
            data = contents
        } else {
            // Retrieve remotely from endpoint
            log.warning("Fetching Unified London Prayer Timetable for '\(key)' from network...")
            let urlFormat = "https://www.londonprayertimes.com/api/times/?key=%@&year=%@&24hours=true&format=json"
            let url = URL(safeString: String(format: urlFormat, apiKey, key))
            let urlRequest = URLRequest(url: url)
            let urlResponse = try await networkManager.send(urlRequest)
            log.debug("Fetched Unified London Prayer Timetable for '\(key)' from network successfully")
            data = urlResponse.data
        }

        // Parse and save to cache
        return try save(data: data, for: year)
    }

    func save(data: Data, for year: Int) throws -> [String: PrayerServiceLondon.LondonPrayerTimes] {
        let key = String(year)
        let decoded: PrayerServiceLondon.ServerResponse

        do {
            decoded = try Self.jsonDecoder.decode(ServerResponse.self, from: data)
        } catch {
            log.error("An error occured while storing Unified London Prayer Timetable for '\(key)' into cache", error: error)
            throw error
        }

        Self.cachedData[key] = decoded.times // Store in-memory

        // Persist in user preferences
        if defaults.object(forKey: key) == nil {
            defaults.set(data, forKey: key)
            defaults.removeObject(forKey: String(year - 2))
        }

        log.debug("Stored Unified London Prayer Timetable for '\(key)' into cache successfully")
        return decoded.times
    }

    func fileURL(forYear year: Int) -> URL? {
        Bundle.module.url(forResource: "london-\(String(year))", withExtension: "json")
    }
}

private extension Date {
    func roundedMinute(using calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        components.minute = Int(minute + round(second / 60))
        components.second = 0
        return calendar.date(from: components) ?? self
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
