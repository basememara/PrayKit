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

    /// How long a table the API hasn't published, or refused, waits before it's asked for again, by every process
    /// sharing the folder.
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

        guard let start = calendar.dateInterval(of: source.period.component, for: date)?.start else {
            throw PrayError.invalidTimes
        }

        let zone = source.zone(for: request)
        let table = PrayerTimetable(start: TimetableDate(start, using: calendar), zone: zone)
        let expired = calendar.date(byAdding: source.period.component, value: -Self.periodsKept, to: start)
            .map { PrayerTimetable(start: TimetableDate($0, using: calendar), zone: zone) }

        return try await loads.days(of: table) { try await load(table, replacing: expired) }
    }
}

// MARK: - Helpers

/// The tables read so far. `PrayerManager.fetch(between:)` fans out through a task group, so the days of a table share
/// its one load; a load that fails or finds no days isn't kept, so the table is loaded again next time.
private actor Loads {
    typealias Days = PrayerTimetableStore.Days

    private var loads = [PrayerTimetable: Task<Days, Error>]()

    func days(of table: PrayerTimetable, load: @escaping @Sendable () async throws -> Days) async throws -> Days {
        if let task = loads[table] {
            return try await task.value
        }

        let task = Task(operation: load)
        loads[table] = task

        do {
            let days = try await task.value
            if days.isEmpty {
                loads[table] = nil
            }

            return days
        } catch {
            loads[table] = nil
            throw error
        }
    }
}

private extension PrayerTimetableStore {
    func load(_ table: PrayerTimetable, replacing expired: PrayerTimetable?) async throws -> Days {
        let path = path(of: table)

        // The bundle comes first, so a copy saved from the network never hides a table the package ships
        if let file = Self.bundledDirectory?.appending(path: "\(path).json"), let data = try? Data(contentsOf: file) {
            log.debug("Read the timetable '\(path)' from the bundle")
            return try decode(data, at: path)
        }

        if let data = try? Data(contentsOf: savedFile(at: path)), let days = try? decode(data, at: path), !days.isEmpty {
            log.debug("Read the timetable '\(path)' from its saved file")
            return days
        }

        // A clock set back since the last ask reads as a wait that has passed
        if let asked = lastAsked(at: path), (0..<Self.retryInterval).contains(now().timeIntervalSince(asked)) {
            log.debug("The timetable '\(path)' wasn't to be had when last asked, so it isn't asked again yet")
            return [:]
        }

        log.warning("Fetching the timetable '\(path)' from the network...")

        var request = source.urlRequest(for: table)
        request.timeoutInterval = Self.requestTimeout

        let data: Data
        do {
            data = try await networkManager.send(request).data
        } catch {
            // A table that can't be fetched has no times, like a day its timetable doesn't reach
            log.error("Could not fetch the timetable '\(path)': \(Self.reason(for: error))")

            // A refusal is the API's answer, so it waits like a table not yet published; a server that couldn't
            // answer, or no connection, says nothing about the table
            if let statusCode = (error as? NetworkError)?.statusCode, (400..<500).contains(statusCode) {
                markAsked(at: path)
            }

            throw PrayError.invalidTimes
        }

        let days = try decode(data, at: path)
        save(data, hasDays: !days.isEmpty, at: path, replacing: expired.map(self.path))
        return days
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

    /// Saves a published table as a file, or marks when the API answered that it has no days yet, so it's asked again
    /// only once the wait has passed.
    func save(_ data: Data, hasDays: Bool, at path: String, replacing expiredPath: String?) {
        let fileManager = FileManager.default
        let savedFile = savedFile(at: path)

        guard hasDays else {
            log.warning("The timetable '\(path)' has no days yet, so it isn't saved")
            try? fileManager.removeItem(at: savedFile)
            markAsked(at: path)
            return
        }

        do {
            try fileManager.createDirectory(at: savedFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: savedFile, options: .atomic)
            try? fileManager.removeItem(at: askedFile(at: path))
            try? expiredPath.map { try fileManager.removeItem(at: self.savedFile(at: $0)) }
            log.debug("Saved the timetable '\(path)'")
        } catch {
            log.error("Could not save the timetable '\(path)'", error: error)
        }
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

    /// Notes that the API was asked just now and had no table to give.
    func markAsked(at path: String) {
        let file = askedFile(at: path)

        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(String(now().timeIntervalSince1970).utf8).write(to: file, options: .atomic)
        } catch {
            log.error("Could not note when the timetable '\(path)' was asked for", error: error)
        }
    }

    /// When the API was last asked and had no table to give.
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
