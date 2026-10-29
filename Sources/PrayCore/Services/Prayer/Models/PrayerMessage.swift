//
//  PrayerMessage.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-29.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import ZamzamCore

public struct PrayerMessage: Equatable, Sendable {
    public let content: Content
    public let placeName: String?
    public let timeZone: TimeZone
    public let uses24hTime: Bool
    public let hijriDayOffset: Int

    public init(content: Content, placeName: String?, timeZone: TimeZone, uses24hTime: Bool, hijriDayOffset: Int) {
        self.content = content
        self.placeName = placeName
        self.timeZone = timeZone
        self.uses24hTime = uses24hTime
        self.hijriDayOffset = hijriDayOffset
    }
}

public extension PrayerMessage {
    enum Content: Equatable, Sendable {
        case timetable(times: [PrayerTime])
        case meet(Meeting)
        case reminder(prayer: Prayer, starts: Date, ends: Date)
    }

    struct Meeting: Equatable, Sendable {
        public enum Timing: String, CaseIterable, Sendable {
            case before
            case after
        }

        public let prayer: Prayer
        public let adhan: Date
        public let minutes: Int
        public let timing: Timing
        public let together: Bool

        public init(prayer: Prayer, adhan: Date, minutes: Int, timing: Timing, together: Bool) {
            self.prayer = prayer
            self.adhan = adhan
            self.minutes = minutes
            self.timing = timing
            self.together = together
        }

        public var time: Date {
            switch timing {
            case .before:
                adhan - .minutes(minutes)
            case .after:
                adhan + .minutes(minutes)
            }
        }
    }
}

public extension PrayerMessage.Content {
    var target: Date? {
        switch self {
        case .timetable:
            nil
        case let .meet(meeting):
            meeting.time
        case let .reminder(_, _, ends):
            ends
        }
    }

    var datedAt: Date? {
        switch self {
        case let .timetable(times):
            times.first?.dateInterval.start
        case let .meet(meeting):
            meeting.time
        case let .reminder(_, starts, _):
            starts
        }
    }
}

// MARK: - Building

public extension PrayerDay {
    var timetable: PrayerMessage.Content {
        .timetable(times: times.filter(\.type.isEssential))
    }

    func meeting(
        _ prayer: Prayer,
        minutes: Int,
        _ timing: PrayerMessage.Meeting.Timing,
        together: Bool,
        at time: Date
    ) -> PrayerMessage.Content? {
        let adhan = (times + tomorrow).first { prayerTime in
            let start = prayerTime.dateInterval.start
            return prayerTime.type == prayer && (timing == .after ? start + .minutes(minutes) : start) > time
        }

        return adhan.map { .meet(PrayerMessage.Meeting(prayer: prayer, adhan: $0.dateInterval.start, minutes: minutes, timing: timing, together: together)) }
    }

    func reminder(at time: Date) -> PrayerMessage.Content? {
        deadline(at: time).map { .reminder(prayer: $0.type, starts: $0.dateInterval.start, ends: $0.dateInterval.end) }
    }

    /// Isha ends at the middle of the night only when the day was fetched with `PrayerFilter.all`.
    func deadline(at time: Date) -> PrayerTime? {
        guard let prayer = lastObligatory(at: time) else { return nil }
        let runsOut = end(of: prayer)
        guard runsOut > time else { return nil }
        return PrayerTime(type: prayer.type, dateInterval: DateInterval(start: prayer.dateInterval.start, end: runsOut))
    }
}

public extension Settings {
    func shownHijriDayOffset(at moment: Date, in prayerDays: [PrayerDay], timeZone: TimeZone) -> Int {
        moment.hijriDayOffset(
            for: prayerDays.first { $0.contains(moment) },
            hijriDayOffset: hijriDayOffset,
            autoIncrementHijri: autoIncrementHijri,
            timeZone: timeZone
        )
    }
}

private extension PrayerDay {
    func end(of prayer: PrayerTime) -> Date {
        guard prayer.type == .isha else { return prayer.dateInterval.end }
        return middleOfNight(during: prayer) ?? prayer.dateInterval.end
    }

    func middleOfNight(during isha: PrayerTime) -> Date? {
        (times + tomorrow)
            .first { $0.type == .midnight && $0.dateInterval.start > isha.dateInterval.start && $0.dateInterval.start < isha.dateInterval.end }
            .map(\.dateInterval.start)
    }
}

// MARK: - URL

public extension PrayerMessage {
    private static let version = "1"
    private static let baseURL = URL(safeString: "https://praywatch.app/m")

    var url: URL {
        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "v", value: Self.version),
            URLQueryItem(name: "tz", value: timeZone.identifier),
            URLQueryItem(name: "h24", value: uses24hTime ? "1" : "0"),
            URLQueryItem(name: "hijri", value: "\(hijriDayOffset)"),
            placeName.map { URLQueryItem(name: "place", value: $0) }
        ].compactMap(\.self) + content.queryItems
        return components?.url ?? Self.baseURL
    }

    init?(url: URL) {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let query = Dictionary(items.compactMap { item in item.value.map { (item.name, $0) } }) { first, _ in first }

        guard query["v"] == Self.version,
              let timeZone = query["tz"].flatMap(TimeZone.init(identifier:)),
              let hijriDayOffset = query["hijri"].flatMap(Int.init),
              let content = Content(query: query)
        else { return nil }

        self.init(content: content, placeName: query["place"], timeZone: timeZone, uses24hTime: query["h24"] == "1", hijriDayOffset: hijriDayOffset)
    }
}

private extension PrayerMessage.Content {
    var queryItems: [URLQueryItem] {
        switch self {
        case let .timetable(times):
            [
                URLQueryItem(name: "kind", value: "timetable"),
                URLQueryItem(
                    name: "times",
                    value: times
                        .map { "\($0.type.rawValue):\($0.dateInterval.start.epoch):\($0.dateInterval.end.epoch)" }
                        .joined(separator: ",")
                )
            ]
        case let .meet(meeting):
            [
                URLQueryItem(name: "kind", value: "meet"),
                URLQueryItem(name: "prayer", value: meeting.prayer.rawValue),
                URLQueryItem(name: "adhan", value: meeting.adhan.epoch),
                URLQueryItem(name: "minutes", value: "\(meeting.minutes)"),
                URLQueryItem(name: "timing", value: meeting.timing.rawValue),
                URLQueryItem(name: "together", value: meeting.together ? "1" : "0")
            ]
        case let .reminder(prayer, starts, ends):
            [
                URLQueryItem(name: "kind", value: "reminder"),
                URLQueryItem(name: "prayer", value: prayer.rawValue),
                URLQueryItem(name: "starts", value: starts.epoch),
                URLQueryItem(name: "ends", value: ends.epoch)
            ]
        }
    }

    init?(query: [String: String]) {
        let prayer = query["prayer"].flatMap(Prayer.init(rawValue:))

        switch query["kind"] {
        case "timetable":
            guard let times = query["times"].flatMap(Self.prayerTimes(from:)) else { return nil }
            self = .timetable(times: times)
        case "meet":
            guard let prayer,
                  let adhan = query["adhan"].flatMap(Date.init(epoch:)),
                  let minutes = query["minutes"].flatMap(Int.init), minutes >= 0,
                  let timing = query["timing"].flatMap(PrayerMessage.Meeting.Timing.init(rawValue:))
            else { return nil }
            self = .meet(PrayerMessage.Meeting(prayer: prayer, adhan: adhan, minutes: minutes, timing: timing, together: query["together"] == "1"))
        case "reminder":
            guard let prayer,
                  let starts = query["starts"].flatMap(Date.init(epoch:)),
                  let ends = query["ends"].flatMap(Date.init(epoch:)),
                  starts <= ends
            else { return nil }
            self = .reminder(prayer: prayer, starts: starts, ends: ends)
        default:
            return nil
        }
    }

    static func prayerTimes(from value: String) -> [PrayerTime]? {
        let times = value.split(separator: ",").map { entry -> PrayerTime? in
            let fields = entry.split(separator: ":").map(String.init)
            guard fields.count == 3,
                  let type = Prayer(rawValue: fields[0]),
                  let start = Date(epoch: fields[1]),
                  let end = Date(epoch: fields[2]),
                  start <= end
            else { return nil }
            return PrayerTime(type: type, dateInterval: DateInterval(start: start, end: end))
        }

        let parsed = times.compactMap(\.self)
        return parsed.isEmpty || parsed.count != times.count ? nil : parsed
    }
}

private extension Date {
    var epoch: String { "\(Int(timeIntervalSince1970))" }

    init?(epoch: String) {
        guard let seconds = Int(epoch) else { return nil }
        self.init(timeIntervalSince1970: TimeInterval(seconds))
    }
}
