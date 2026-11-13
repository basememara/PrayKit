//
//  PrayerTimetableStore.swift
//  PrayServices
//
//  Created by Basem Emara on 2026-11-13.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import ZamzamCore

/// Keeps a source's tables: the copy the package ships first, then the one saved in the folder, then the API.
///
/// Both roots share one layout, a folder per source, a folder per zone where the source has them, and a file per table
/// named for the period it covers:
///
///     PrayerTimetables/london/2027.json
///     PrayerTimetables/<source>/<zone>/2027-03.json
///
/// A file holds the API's response as it came, so the bundled and the saved copy read the same way.
struct PrayerTimetableStore: Sendable {
    typealias Days = [TimetableDate: TimetableDay]

    static let bundledDirectory = Bundle.module.resourceURL?.appending(path: "PrayerTimetables", directoryHint: .isDirectory)

    /// How long a table the API refused, or hasn't published in whole, waits before it's asked for again, by every
    /// process sharing the folder.
    private static let retryInterval: TimeInterval = 6 * 3600

    /// How long a request waits on a silent connection, in place of Foundation's minute: a day at the end of a table
    /// needs the next one's first Fajr, so a request that hangs holds back that day's own times.
    private static let requestTimeout: TimeInterval = 15

    /// Saved tables kept back from the one holding today: that one and the one before it. Tables ahead of today stay,
    /// so a calendar looking ahead never removes what the widgets read.
    private static let periodsKept = 2

    private let source: any PrayerTimetableSource
    private let networkManager: NetworkManager
    private let directory: URL
    private let log: LogManager
    private let now: @Sendable () -> Date
    private let loads = Loads()

    init(
        source: any PrayerTimetableSource,
        networkManager: NetworkManager,
        directory: URL,
        log: LogManager,
        now: @escaping @Sendable () -> Date
    ) {
        self.source = source
        self.networkManager = networkManager
        self.directory = directory
        self.log = log
        self.now = now
    }
}

extension PrayerTimetableStore {
    /// The days of the table holding a date for the request's place, as far as they can be had: none while the table
    /// isn't published or can't be reached.
    ///
    /// - Parameter calendar: A Gregorian calendar in the place's time zone.
    func days(holding date: Date, using calendar: Calendar, for request: PrayerAPI.Request) async -> Days {
        guard let period = source.period.interval(holding: date, using: calendar) else { return [:] }

        let table = PrayerTimetable(start: TimetableDate(period.start, using: calendar), zone: source.zone(for: request))

        return await loads.days(of: table, now: now) {
            await load(table, covering: period, using: calendar, at: now())
        }
    }

    /// Whether a table the API last didn't have whole is still waiting to be asked for again. A clock set back since
    /// reads as a wait that has passed.
    static func isWaiting(since asked: Date, at now: Date) -> Bool {
        (0..<retryInterval).contains(now.timeIntervalSince(asked))
    }
}

// MARK: - Helpers

/// A table as it was read, and when the API last didn't have it whole: never for a whole table.
private struct Loaded: Sendable {
    let days: PrayerTimetableStore.Days
    let asked: Date?

    func isDue(at now: Date) -> Bool {
        asked.map { !PrayerTimetableStore.isWaiting(since: $0, at: now) } ?? false
    }
}

/// What the API said when asked for a table.
private enum Answer {
    /// Its response and the days in it, none for a table not yet published.
    case table(Data, PrayerTimetableStore.Days)
    case refused
    /// No answer, or one that couldn't be read.
    case unanswered
}

/// The tables read so far. `PrayerManager.fetch(between:)` fans out through a task group, so the days of a table share
/// its one load, which is kept until it is due again. A caller reads the clock once the load it waited on is done, so
/// one that asked a moment before the load began never reads its mark as a clock set back.
private actor Loads {
    private var loads = [PrayerTimetable: Task<Loaded, Never>]()

    func days(
        of table: PrayerTimetable,
        now: @Sendable () -> Date,
        load: @escaping @Sendable () async -> Loaded
    ) async -> PrayerTimetableStore.Days {
        if let task = loads[table] {
            let loaded = await task.value
            guard loaded.isDue(at: now()) else { return loaded.days }

            // Another caller may have started the next load while this one waited on the last
            guard loads[table] == task else { return await days(of: table, now: now, load: load) }
        }

        let task = Task(operation: load)
        loads[table] = task
        return await task.value.days
    }
}

private extension PrayerTimetableStore {
    /// A table is whole once it has a day for every day of its period. Until then what it has is saved and read, and
    /// the API is asked again once the wait has passed, so a table published in part never sticks.
    func load(_ table: PrayerTimetable, covering period: DateInterval, using calendar: Calendar, at now: Date) async -> Loaded {
        let path = path(of: table)

        // The bundle comes first, so a copy saved from the network never hides a table the package ships
        if let file = Self.bundledDirectory?.appending(path: "\(path).json"), let data = try? Data(contentsOf: file) {
            log.debug("Read the timetable '\(path)' from the bundle")
            return Loaded(days: decode(data, at: path) ?? [:], asked: nil)
        }

        let dayCount = calendar.dateComponents([.day], from: period.start, to: period.end).day ?? 0
        let saved = (try? Data(contentsOf: savedFile(at: path))).flatMap { decode($0, at: path) } ?? [:]

        if !saved.isEmpty, saved.count >= dayCount {
            log.debug("Read the timetable '\(path)' from its saved file")
            return Loaded(days: saved, asked: nil)
        }

        if let asked = lastAsked(at: path), Self.isWaiting(since: asked, at: now) {
            log.debug("The timetable '\(path)' wasn't whole when last asked, so it isn't asked again yet")
            return Loaded(days: saved, asked: asked)
        }

        switch await ask(for: table, at: path) {
        case let .table(data, days) where !days.isEmpty:
            save(data, at: path)
            removeExpired(beside: path, using: calendar, at: now)

            guard days.count < dayCount else {
                try? FileManager.default.removeItem(at: askedFile(at: path))
                return Loaded(days: days, asked: nil)
            }

            log.warning("The timetable '\(path)' isn't whole yet")
            markAsked(at: path, now: now)
            return Loaded(days: days, asked: now)
        case .unanswered where saved.isEmpty:
            // A server that couldn't answer, or no connection, says nothing about the table, so the next lookup asks
            return Loaded(days: [:], asked: .distantPast)
        case .table, .refused, .unanswered:
            // No days yet, a refusal, or no answer while part of the table is saved: it waits
            markAsked(at: path, now: now)
            return Loaded(days: saved, asked: now)
        }
    }

    func ask(for table: PrayerTimetable, at path: String) async -> Answer {
        log.warning("Fetching the timetable '\(path)' from the network...")

        var request = source.urlRequest(for: table)
        request.timeoutInterval = Self.requestTimeout

        do {
            let data = try await networkManager.send(request).data
            return decode(data, at: path).map { .table(data, $0) } ?? .unanswered
        } catch {
            log.error("Could not fetch the timetable '\(path)': \(Self.reason(for: error))")
            let isRefused = (error as? NetworkError)?.statusCode.map((400..<500).contains) ?? false
            return isRefused ? .refused : .unanswered
        }
    }

    /// The days in a table's file or response, or `nil` when it can't be read.
    func decode(_ data: Data, at path: String) -> Days? {
        do {
            return try source.days(from: data)
        } catch {
            log.error("Could not read the timetable '\(path)'", error: error)
            return nil
        }
    }

    func save(_ data: Data, at path: String) {
        do {
            try write(data, to: savedFile(at: path))
            log.debug("Saved the timetable '\(path)'")
        } catch {
            log.error("Could not save the timetable '\(path)'", error: error)
        }
    }

    /// Removes the saved tables beside one just saved, and their marks, that end before the ones kept back from today.
    /// Names sort by date, so a name before the oldest kept one is an older table; the table just saved always stays.
    func removeExpired(beside path: String, using calendar: Calendar, at now: Date) {
        guard let today = source.period.interval(holding: now, using: calendar)?.start,
              let oldestKept = calendar.date(byAdding: source.period.component, value: 1 - Self.periodsKept, to: today)
        else {
            return
        }

        let cutoff = source.period.name(startingOn: TimetableDate(oldestKept, using: calendar))
        let saved = savedFile(at: path)
        let name = { (file: URL) in file.deletingPathExtension().lastPathComponent }
        let files = (try? FileManager.default.contentsOfDirectory(at: saved.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []

        files
            .filter { name($0) < cutoff && name($0) != name(saved) }
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }

    /// Why a request failed, without the error itself: both a network error and the transport's own print the
    /// request's URL, which can carry the source's key, and the log is what support requests attach.
    static func reason(for error: Error) -> String {
        let networkError = error as? NetworkError

        if let statusCode = networkError?.statusCode {
            return "status \(statusCode)"
        }

        guard let urlError = (networkError?.internalError ?? error) as? URLError else { return "no response" }
        return "URL error \(urlError.code.rawValue)"
    }

    /// Notes that the API was asked just now and didn't have the whole table to give.
    func markAsked(at path: String, now: Date) {
        do {
            try write(Data(String(now.timeIntervalSince1970).utf8), to: askedFile(at: path))
        } catch {
            log.error("Could not note when the timetable '\(path)' was asked for", error: error)
        }
    }

    /// When the API was last asked and didn't have the whole table to give.
    func lastAsked(at path: String) -> Date? {
        (try? String(contentsOf: askedFile(at: path), encoding: .utf8))
            .flatMap(TimeInterval.init)
            .map(Date.init(timeIntervalSince1970:))
    }

    func write(_ data: Data, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }

    /// Where a table sits under either root, without its extension: `london/2027`.
    func path(of table: PrayerTimetable) -> String {
        [source.id, table.zone, source.period.name(startingOn: table.start)]
            .compactMap(\.self)
            .joined(separator: "/")
    }

    func savedFile(at path: String) -> URL {
        directory.appending(path: "\(path).json")
    }

    func askedFile(at path: String) -> URL {
        directory.appending(path: "\(path).asked")
    }
}
