//
//  PrayerTimetableSourceLondon.swift
//  PrayServices
//
//  Created by Basem Emara on 2022-02-26.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import ZamzamCore

/// The London Unified Prayer Timetable, a year at a time: https://www.londonprayertimes.com
struct PrayerTimetableSourceLondon: PrayerTimetableSource {
    let apiKey: String
    let id = "london"
    let period = TimetablePeriod.year
}

extension PrayerTimetableSourceLondon {
    func urlRequest(for table: PrayerTimetable) -> URLRequest {
        URLRequest(
            url: URL(safeString: "https://www.londonprayertimes.com/api/times/").appending(
                queryItems: [
                    URLQueryItem(name: "key", value: apiKey),
                    URLQueryItem(name: "year", value: String(table.start.year)),
                    URLQueryItem(name: "24hours", value: "true"),
                    URLQueryItem(name: "format", value: "json")
                ]
            )
        )
    }

    func days(from data: Data) throws -> [TimetableDate: TimetableDay] {
        try JSONDecoder().decode(Response.self, from: data).times.reduce(into: [:]) { result, entry in
            guard let date = TimetableDate(entry.key), let day = TimetableDay(entry.value) else { return }
            result[date] = day
        }
    }
}

// MARK: - Types

private extension PrayerTimetableSourceLondon {
    /// A year the API hasn't published yet answers with no times.
    struct Response: Decodable {
        let times: [String: Day]
    }

    struct Day: Decodable {
        let fajr: String?
        let sunrise: String?
        let dhuhr: String?
        let asr: String?
        let asr_2: String?
        let magrib: String?
        let isha: String?
    }
}

private extension TimetableDay {
    init?(_ day: PrayerTimetableSourceLondon.Day) {
        let clock = { (text: String?) in text.flatMap { TimetableClock($0) } }

        guard let fajr = clock(day.fajr),
              let sunrise = clock(day.sunrise),
              let dhuhr = clock(day.dhuhr),
              let asr = clock(day.asr),
              let maghrib = clock(day.magrib),
              let isha = clock(day.isha)
        else {
            return nil
        }

        self.init(fajr: fajr, sunrise: sunrise, dhuhr: dhuhr, asr: asr, asrHanafi: clock(day.asr_2), maghrib: maghrib, isha: isha)
    }
}
