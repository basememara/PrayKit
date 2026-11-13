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

    /// A saved table is removed when the one this many periods after it is saved.
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
    /// The days of the table holding a date for the request's place, none while that table isn't published.
    func days(holding date: Date, for request: PrayerAPI.Request) async throws -> Days {
        var calendar = Calendar(identifier: .gregorian, timeZone: request.timeZone, locale: .posix)
        calendar.firstWeekday = 2

        guard let period = calendar.dateInterval(of: source.period.component, for: date),
              let dayCount = calendar.dateComponents([.day], from: period.start, to: period.end).day
        else {
            throw PrayError.invalidTimes
        }

        let zone = source.zone(for: request)
        let table = PrayerTimetable(start: TimetableDate(period.start, using: calendar), zone: zone)
        let expired = calendar.date(byAdding: source.period.component, value: -Self.periodsKept, to: period.start)
            .map { PrayerTimetable(start: TimetableDate($0, using: calendar), zone: zone) }

        return try await loads.days(of: table, at: now()) {
            try await load(table, dayCount: dayCount, replacing: expired)
        }
    }
}

// MARK: - Helpers

/// A table as it was read, and when to ask for it again if it wasn't whole.
private struct Loaded: Sendable {
    let days: PrayerTimetableStore.Days
    let retryAfter: Date?
}

/// The tables read so far. `PrayerManager.fetch(between:)` fans out through a task group, so the days of a table share
/// its one load. A whole table is kept for good, one that isn't until its wait has passed, and a load that fails
/// isn't kept at all.
private actor Loads {
    private var loads = [PrayerTimetable: Task<Loaded, Error>]()

    func days(
        of table: PrayerTimetable,
        at now: Date,
        load: @escaping @Sendable () async throws -> Loaded
    ) async throws -> PrayerTimetableStore.Days {
        if let task = loads[table] {
            let loaded = try await task.value
            guard let retryAfter = loaded.retryAfter, now >= retryAfter else { return loaded.days }

            // Another caller may have started the next load while this one waited on the last
            guard loads[table] == task else { return try await days(of: table, at: now, load: load) }
        }

        let task = Task(operation: load)
        loads[table] = task

        do {
            return try await task.value.days
        } catch {
            if loads[table] == task {
                loads[table] = nil
            }

            throw error
        }
    }
}

private extension PrayerTimetableStore {
    /// A table is whole once it has a day for every day of its period. Until then what it has is saved and read, and
    /// the API is asked again once the wait has passed, so a table published in part never sticks.
    func load(_ table: PrayerTimetable, dayCount: Int, replacing expired: PrayerTimetable?) async throws -> Loaded {
        let path = path(of: table)

        // The bundle comes first, so a copy saved from the network never hides a table the package ships
        if let file = Self.bundledDirectory?.appending(path: "\(path).json"), let data = try? Data(contentsOf: file) {
            log.debug("Read the timetable '\(path)' from the bundle")
            return Loaded(days: try decode(data, at: path), retryAfter: nil)
        }

        let saved = (try? Data(contentsOf: savedFile(at: path))).flatMap { try? decode($0, at: path) } ?? [:]

        guard saved.count < dayCount else {
            log.debug("Read the timetable '\(path)' from its saved file")
            return Loaded(days: saved, retryAfter: nil)
        }

        // A clock set back since the last ask reads as a wait that has passed
        if let asked = lastAsked(at: path), (0..<Self.retryInterval).contains(now().timeIntervalSince(asked)) {
            log.debug("The timetable '\(path)' wasn't whole when last asked, so it isn't asked again yet")
            return Loaded(days: saved, retryAfter: asked + Self.retryInterval)
        }

        log.warning("Fetching the timetable '\(path)' from the network...")

        var request = source.urlRequest(for: table)
        request.timeoutInterval = Self.requestTimeout

        let data: Data
        do {
            data = try await networkManager.send(request).data
        } catch {
            log.error("Could not fetch the timetable '\(path)': \(Self.reason(for: error))")

            // A refusal is the API's answer, so it waits like a table not yet published; a server that couldn't
            // answer, or no connection, says nothing about the table
            let isRefused = (error as? NetworkError)?.statusCode.map((400..<500).contains) ?? false
            return try unanswered(keeping: saved, at: path, waits: isRefused)
        }

        guard let days = try? decode(data, at: path) else {
            return try unanswered(keeping: saved, at: path, waits: false)
        }

        guard !days.isEmpty else {
            log.warning("The timetable '\(path)' has no days yet")

            if saved.isEmpty {
                try? FileManager.default.removeItem(at: savedFile(at: path))
            }

            markAsked(at: path)
            return Loaded(days: saved, retryAfter: now() + Self.retryInterval)
        }

        let isWhole = days.count >= dayCount
        save(data, isWhole: isWhole, at: path, replacing: expired.map(self.path))
        return Loaded(days: days, retryAfter: isWhole ? nil : now() + Self.retryInterval)
    }

    /// What an ask that got no table leaves: the days already saved, which then wait before the next ask, or no times,
    /// like a day its timetable doesn't reach.
    func unanswered(keeping saved: Days, at path: String, waits: Bool) throws -> Loaded {
        if waits || !saved.isEmpty {
            markAsked(at: path)
        }

        guard !saved.isEmpty else { throw PrayError.invalidTimes }
        return Loaded(days: saved, retryAfter: now() + Self.retryInterval)
    }

    /// A table that can't be read has no times, whatever the source's own error.
    func decode(_ data: Data, at path: String) throws -> Days {
        do {
            return try source.days(from: data)
        } catch {
            log.error("Could not read the timetable '\(path)'", error: error)
            throw PrayError.invalidTimes
        }
    }

    /// Saves a table's days as a file. One that isn't whole yet is marked as asked, so the rest is asked for only once
    /// the wait has passed.
    func save(_ data: Data, isWhole: Bool, at path: String, replacing expiredPath: String?) {
        let fileManager = FileManager.default
        let savedFile = savedFile(at: path)

        do {
            try fileManager.createDirectory(at: savedFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: savedFile, options: .atomic)
            try? expiredPath.map { try fileManager.removeItem(at: self.savedFile(at: $0)) }
            log.debug("Saved the timetable '\(path)'")
        } catch {
            log.error("Could not save the timetable '\(path)'", error: error)
        }

        guard isWhole else {
            log.warning("The timetable '\(path)' isn't whole yet")
            markAsked(at: path)
            return
        }

        try? fileManager.removeItem(at: askedFile(at: path))
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
    func markAsked(at path: String) {
        let file = askedFile(at: path)

        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(String(now().timeIntervalSince1970).utf8).write(to: file, options: .atomic)
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
