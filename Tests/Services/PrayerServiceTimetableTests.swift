//
//  PrayerServiceTimetableTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import os
import PrayCore
@testable import PrayServices
import Testing
import ZamzamCore

/// A timetable's tables come from the bundle, then the folder, then its API. London's is bundled a year at a time, so a
/// year past the bundle, and Dec 31 of the last bundled year (which needs the next year's first Fajr), come from the
/// API, which answers a year it hasn't published yet with a timetable of no days.
struct PrayerServiceTimetableTests {
    private let log = LogManager(services: [LogServiceConsole(minLevel: .none, subsystem: "PrayKitTests")])
    private let folder = URL.temporaryDirectory.appending(path: "PrayerServiceTimetableTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let clock = TestClock()
}

// MARK: - London

extension PrayerServiceTimetableTests {
    @Test
    func aSavedEmptyYearNeverHidesTheBundledOne() async throws {
        // Given
        let year = try lastBundledYear() - 1
        let place = london(year)
        try save(LondonAPI.unpublished, at: "london/\(year).json")
        let service = londonService(LondonAPI())

        // When
        let times = try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())

        // Then
        #expect(times.contains { $0.type == .fajr })
        #expect(times.contains { $0.type == .isha })
    }

    @Test
    func anUnpublishedYearIsAskedForAgainOnceItIsOut() async throws {
        // Given
        let lastYear = try lastBundledYear()
        let place = london(lastYear)
        let api = LondonAPI()
        try save(LondonAPI.unpublished, at: "london/\(lastYear + 1).json")
        let service = londonService(api)
        let yearsEnd = try place.date(lastYear, 12, 31)

        // When
        await #expect(throws: PrayError.self) {
            try await service.calculate(for: yearsEnd, using: try place.calendar(), with: try place.request())
        }

        // Then
        #expect(!isSaved("london/\(lastYear + 1).json"), "A year with no days must not stay saved")

        // When
        await api.publish(lastYear + 1)
        clock.advance(by: 7 * 3600)
        let times = try await service.calculate(for: yearsEnd, using: try place.calendar(), with: try place.request())

        // Then
        let isha = try #require(times.first { $0.type == .isha })
        let nextFajr = try place.date(lastYear + 1, 1, 1, 6, 26)
        #expect(isha.dateInterval.end == nextFajr)
        #expect(isSaved("london/\(lastYear + 1).json"), "A published year is saved")
        #expect(!isSaved("london/\(lastYear + 1).unpublished"), "A published year is no longer waited on")
    }

    /// A year the app doesn't bundle yet comes from the API once it's published, so January never goes blank.
    @Test
    func aYearPastTheBundleIsFetchedOnceItIsOut() async throws {
        // Given
        let year = try lastBundledYear() + 2
        let place = london(year)
        let api = LondonAPI()
        let service = londonService(api)
        let newYearsDay = try place.date(year, 1, 1, 12)

        // When
        await #expect(throws: PrayError.self) {
            try await service.calculate(for: newYearsDay, using: try place.calendar(), with: try place.request())
        }

        await api.publish(year)
        clock.advance(by: 7 * 3600)
        let times = try await service.calculate(for: newYearsDay, using: try place.calendar(), with: try place.request())

        // Then
        let fajr = try #require(times.first { $0.type == .fajr })
        #expect(fajr.dateInterval.start == (try place.date(year, 1, 1, 6, 26)))
        #expect(isSaved("london/\(year).json"), "The fetched year is saved")
    }

    /// A year the API hasn't published yet waits a few hours before it's asked for again, so every widget reload and
    /// scheduling run in December doesn't ask.
    @Test
    func anUnpublishedYearWaitsBeforeItIsAskedForAgain() async throws {
        // Given
        let year = try lastBundledYear() + 5
        let place = london(year)
        let api = LondonAPI()
        let service = londonService(api)
        let newYearsDay = try place.date(year, 1, 1, 12)

        // When
        for _ in 1...3 {
            _ = try? await service.calculate(for: newYearsDay, using: try place.calendar(), with: try place.request())
        }

        // Then
        #expect(await api.requestedURLs.count == 1)

        // When
        clock.advance(by: 7 * 3600)
        _ = try? await service.calculate(for: newYearsDay, using: try place.calendar(), with: try place.request())

        // Then
        #expect(await api.requestedURLs.count == 2)
    }

    /// A range fans out a day at a time, so the days of a year the app doesn't have share one request for it.
    @Test
    func daysOfAYearBeingFetchedWaitForTheSameRequest() async throws {
        // Given
        let year = try lastBundledYear() + 4
        let place = london(year)
        let api = HeldAPI()
        let service = londonService(api)
        let days = try (1...8).map { try place.date(year, 1, $0, 12) }
        let calendar = try place.calendar()
        let request = try place.request()

        // When
        await withTaskGroup(of: Void.self) { group in
            days.forEach { day in
                group.addTask { _ = try? await service.calculate(for: day, using: calendar, with: request) }
            }

            await api.waitForARequest()
            try? await Task.sleep(for: .milliseconds(200))
            await api.answer()
        }

        // Then
        #expect(await api.requestCount == 1)
    }

    @Test
    func aYearThatCantBeFetchedHasNoTimes() async throws {
        // Given
        let year = try lastBundledYear() + 3
        let place = london(year)
        let service = londonService(OfflineNetwork())

        // When
        let error = await #expect(throws: PrayError.self) {
            try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())
        }

        // Then
        guard case .invalidTimes = error else {
            Issue.record("Expected invalid times, got \(String(describing: error))")
            return
        }
    }

    /// An answer that isn't the timetable (a captive portal's page, say) is no times, and nothing is kept of it, so the
    /// year is asked for again.
    @Test
    func anAnswerThatCantBeReadHasNoTimes() async throws {
        // Given
        let year = try lastBundledYear() + 6
        let place = london(year)
        let service = londonService(UnreadableAPI())

        // When
        let error = await #expect(throws: PrayError.self) {
            try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())
        }

        // Then
        guard case .invalidTimes = error else {
            Issue.record("Expected invalid times, got \(String(describing: error))")
            return
        }

        #expect((try? savedFiles()) ?? [] == [])
    }

    @Test
    func aYearThatIsNotBundledIsAskedForWithTheKeyAndTheYear() async throws {
        // Given
        let place = london(2019)
        let api = LondonAPI()
        let service = londonService(api, apiKey: "abc-123_XYZ")

        // When
        await #expect(throws: PrayError.self) {
            try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())
        }

        // Then
        #expect(await api.requestedURLs == ["https://www.londonprayertimes.com/api/times/?key=abc-123_XYZ&year=2019&24hours=true&format=json"])
    }
}

// MARK: - The key

extension PrayerServiceTimetableTests {
    /// A failed request's error prints its URL, and London's carries the key, so the log names the table and the
    /// failure only: support requests attach the log.
    @Test(arguments: [FailingNetwork(statusCode: 403), FailingNetwork(statusCode: nil)])
    fileprivate func aFailedRequestNeverLogsTheKey(network: FailingNetwork) async throws {
        // Given
        let place = london(2019)
        let recorder = RecordingLog()
        let service = PrayerServiceTimetable(
            source: PrayerTimetableSourceLondon(apiKey: "abc-123_XYZ"),
            networkManager: NetworkManager(service: network),
            directory: folder,
            log: LogManager(services: [recorder])
        )

        // When
        await #expect(throws: PrayError.self) {
            try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())
        }

        // Then
        #expect(!recorder.text.contains("abc-123_XYZ"))
        #expect(!recorder.text.contains("londonprayertimes.com"))
        #expect(recorder.text.contains("Could not fetch the timetable 'london/2019': \(network.statusCode.map { "status \($0)" } ?? "URL error -1009")"))
    }
}

// MARK: - Any source

/// A source brings only its period, its zones, its request and its format; the files, the waits and the day's times are
/// the service's, so these made-up authorities read through it untouched.
extension PrayerServiceTimetableTests {
    @Test
    func aMonthlySourceKeepsAFilePerZoneAndMonth() async throws {
        // Given
        let east = DayFixture("East of Greenwich", 3.139, 101.687, "Asia/Kuala_Lumpur", .custom, 2031, 1, 31)
        let west = DayFixture("West of Greenwich", 51.5074, -0.1278, "Europe/London", .custom, 2031, 1, 31)
        let api = LineAPI()
        let service = service(LineSource(id: "monthly", period: .month, hasZones: true), api)

        // When
        let eastTimes = try await service.calculate(for: try east.firstNoon(), using: try east.calendar(), with: try east.request())
        let westTimes = try await service.calculate(for: try west.firstNoon(), using: try west.calendar(), with: try west.request())

        // Then
        let eastFajr = try #require(eastTimes.first { $0.type == .fajr })
        let eastIsha = try #require(eastTimes.first { $0.type == .isha })
        let westFajr = try #require(westTimes.first { $0.type == .fajr })
        #expect(eastFajr.dateInterval.start == (try east.date(2031, 1, 31, 5, 0)))
        #expect(eastIsha.dateInterval.end == (try east.date(2031, 2, 1, 5, 0)), "Tomorrow's Fajr comes from February's table")
        #expect(westFajr.dateInterval.start == (try west.date(2031, 1, 31, 5, 10)))

        #expect(try savedFiles() == [
            "monthly/east/2031-01.json",
            "monthly/east/2031-02.json",
            "monthly/west/2031-01.json",
            "monthly/west/2031-02.json"
        ])
        #expect(await api.requestedURLs.count == 4)
    }

    @Test
    func theHanafiAsrIsReadWhereTheSourcePrintsOne() async throws {
        // Given
        let place = DayFixture("East of Greenwich", 3.139, 101.687, "Asia/Kuala_Lumpur", .custom, 2031, 1, 15)
        let service = service(LineSource(id: "monthly", period: .month), LineAPI())
        let request = PrayerAPI.Request(
            coordinates: Coordinates(latitude: place.latitude, longitude: place.longitude),
            timeZone: try place.request().timeZone,
            method: .custom,
            jurisprudence: .hanafi
        )

        // When
        let standard = try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())
        let hanafi = try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: request)

        // Then
        let standardAsr = try #require(standard.first { $0.type == .asr })
        let hanafiAsr = try #require(hanafi.first { $0.type == .asr })
        #expect(standardAsr.dateInterval.start == (try place.date(2031, 1, 15, 15, 0)))
        #expect(hanafiAsr.dateInterval.start == (try place.date(2031, 1, 15, 16, 0)))
    }

    @Test
    func aWeeklySourceNamesATableByItsMonday() async throws {
        // Given
        let place = DayFixture("A Sunday", 51.5074, -0.1278, "Europe/London", .custom, 2031, 3, 9)
        let service = service(LineSource(id: "weekly", period: .week), LineAPI())

        // When
        let times = try await service.calculate(for: try place.firstNoon(), using: try place.calendar(), with: try place.request())

        // Then
        let isha = try #require(times.first { $0.type == .isha })
        #expect(isha.dateInterval.end == (try place.date(2031, 3, 10, 5, 0)), "Tomorrow's Fajr comes from next week's table")
        #expect(try savedFiles() == ["weekly/2031-03-03.json", "weekly/2031-03-10.json"])
    }

    @Test
    func savingATableRemovesTheOneTwoPeriodsBack() async throws {
        // Given
        let place = DayFixture("Three Wednesdays", 51.5074, -0.1278, "Europe/London", .custom, 2031, 3, 5)
        let service = service(LineSource(id: "weekly", period: .week), LineAPI())

        // When
        for day in [5, 12, 19] {
            _ = try await service.calculate(for: try place.date(2031, 3, day), using: try place.calendar(), with: try place.request())
        }

        // Then
        #expect(try savedFiles() == ["weekly/2031-03-10.json", "weekly/2031-03-17.json"])
    }
}

// MARK: - Helpers

private extension PrayerServiceTimetableTests {
    func london(_ year: Int) -> DayFixture {
        DayFixture("London timetable", 51.5074, -0.1278, "Europe/London", .london, year, 6, 1)
    }

    func londonService(_ api: some NetworkService, apiKey: String = "") -> PrayerServiceTimetable {
        service(PrayerTimetableSourceLondon(apiKey: apiKey), api)
    }

    func service(_ source: some PrayerTimetableSource, _ api: some NetworkService) -> PrayerServiceTimetable {
        PrayerServiceTimetable(
            source: source,
            networkManager: NetworkManager(service: api),
            directory: folder,
            log: log,
            now: { [clock] in clock.now }
        )
    }

    /// The last year of London's timetable the package ships.
    func lastBundledYear() throws -> Int {
        let london = try #require(PrayerTimetableStore.bundledDirectory).appending(path: "london")
        let years = try FileManager.default.contentsOfDirectory(at: london, includingPropertiesForKeys: nil)
            .compactMap { Int($0.deletingPathExtension().lastPathComponent) }

        return try #require(years.max())
    }

    func save(_ text: String, at path: String) throws {
        let file = folder.appending(path: path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
    }

    func isSaved(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appending(path: path).path)
    }

    /// Every file in the folder, by its path inside it.
    func savedFiles() throws -> [String] {
        try FileManager.default.subpathsOfDirectory(atPath: folder.path)
            .filter { !$0.hasPrefix(".") && $0.contains(".") }
            .sorted()
    }
}

/// Keeps every log entry as the file log would write it.
private final class RecordingLog: LogService {
    let minLevel = LogAPI.Level.verbose
    private let entries = OSAllocatedUnfairLock(initialState: [String]())

    var text: String { entries.withLock { $0.joined(separator: "\n") } }

    func write(
        _ level: LogAPI.Level,
        with message: String,
        file: String,
        function: String,
        line: Int,
        error: Error?,
        context: [String: any CustomStringConvertible & Sendable],
        sessionContext: [String: any CustomStringConvertible & Sendable]
    ) {
        let entry = format(message, file, function, line, error, context)
        entries.withLock { $0.append(entry) }
    }
}

/// Fails as `NetworkServiceFoundation` does: with the status the server answered, or the transport's error when it
/// didn't, which names the URL that failed.
private struct FailingNetwork: NetworkService {
    let statusCode: Int?

    func send(_ request: URLRequest) async throws -> NetworkResponse {
        let offline = URLError(.notConnectedToInternet, userInfo: [NSURLErrorFailingURLStringErrorKey: request.url?.absoluteString ?? ""])
        throw NetworkError(request: request, statusCode: statusCode, internalError: statusCode == nil ? offline : nil)
    }
}

/// Answers every request with a page that isn't a timetable.
private struct UnreadableAPI: NetworkService {
    func send(_ request: URLRequest) async throws -> NetworkResponse {
        NetworkResponse(data: Data("<html>Sign in to continue</html>".utf8), headers: [:], statusCode: 200, request: request, response: URLResponse())
    }
}

/// A clock a test moves by hand.
private final class TestClock: Sendable {
    private let date = OSAllocatedUnfairLock(initialState: Date(timeIntervalSince1970: 1_900_000_000))

    var now: Date { date.withLock { $0 } }

    func advance(by interval: TimeInterval) {
        date.withLock { $0 += interval }
    }
}

/// The London Prayer Times API: a year is empty until it is published, then holds its first two days.
private actor LondonAPI: NetworkService {
    static let unpublished = #"{"city":"london","times":{}}"#

    private var published: Int?
    private(set) var requestedURLs = [String]()

    func publish(_ year: Int) {
        published = year
    }

    func send(_ request: URLRequest) async throws -> NetworkResponse {
        requestedURLs.append(request.url?.absoluteString ?? "")

        let body = published.map { year in
            #"""
            {"city":"london","times":{"\#(year)-01-01":{"date":"\#(year)-01-01",
            "fajr":"06:26","fajr_jamat":"06:46","sunrise":"08:03","dhuhr":"12:09","dhuhr_jamat":"12:45",
            "asr":"13:46","asr_2":"14:17","asr_jamat":"14:45","magrib":"16:05","magrib_jamat":"16:12",
            "isha":"17:42","isha_jamat":"19:30"},
            "\#(year)-01-02":{"date":"\#(year)-01-02",
            "fajr":"06:26","fajr_jamat":"06:46","sunrise":"08:03","dhuhr":"12:10","dhuhr_jamat":"12:45",
            "asr":"13:47","asr_2":"14:18","asr_jamat":"14:45","magrib":"16:06","magrib_jamat":"16:13",
            "isha":"17:43","isha_jamat":"19:30"}}}
            """#
        } ?? Self.unpublished

        return NetworkResponse(data: Data(body.utf8), headers: [:], statusCode: 200, request: request, response: URLResponse())
    }
}

/// An API that holds every request until it's told to answer, with a year it hasn't published.
private actor HeldAPI: NetworkService {
    private(set) var requestCount = 0
    private var held = [CheckedContinuation<Void, Never>]()
    private var arrivals = [CheckedContinuation<Void, Never>]()
    private var isAnswering = false

    func send(_ request: URLRequest) async throws -> NetworkResponse {
        requestCount += 1
        arrivals.forEach { $0.resume() }
        arrivals = []

        if !isAnswering {
            await withCheckedContinuation { held.append($0) }
        }

        return NetworkResponse(data: Data(LondonAPI.unpublished.utf8), headers: [:], statusCode: 200, request: request, response: URLResponse())
    }

    func waitForARequest() async {
        guard requestCount == 0 else { return }
        await withCheckedContinuation { arrivals.append($0) }
    }

    func answer() {
        isAnswering = true
        held.forEach { $0.resume() }
        held = []
    }
}

/// A made-up authority that publishes a line per day, with the Hanafi Asr as the fifth time:
/// `2031-01-31 05:00 06:30 12:00 15:00 16:00 18:00 19:30`.
private struct LineSource: PrayerTimetableSource {
    let id: String
    let period: TimetablePeriod
    var hasZones = false

    func zone(for request: PrayerAPI.Request) -> String? {
        guard hasZones else { return nil }
        return request.coordinates.longitude < 0 ? "west" : "east"
    }

    func urlRequest(for table: PrayerTimetable) -> URLRequest {
        URLRequest(url: URL(safeString: "https://timetable.test").appending(path: "\(table.zone ?? "all")/\(period.name(startingOn: table.start))"))
    }

    func days(from data: Data) throws -> [TimetableDate: TimetableDay] {
        String(decoding: data, as: UTF8.self).split(separator: "\n").reduce(into: [:]) { result, line in
            let fields = line.split(separator: " ")
            let clocks = fields.dropFirst().compactMap { TimetableClock($0) }
            guard let date = fields.first.flatMap({ TimetableDate($0) }), clocks.count == 7 else { return }

            result[date] = TimetableDay(
                fajr: clocks[0],
                sunrise: clocks[1],
                dhuhr: clocks[2],
                asr: clocks[3],
                asrHanafi: clocks[4],
                maghrib: clocks[5],
                isha: clocks[6]
            )
        }
    }
}

/// Answers `LineSource` with every day of the month or week it's asked for; Fajr is ten minutes later in the west.
private actor LineAPI: NetworkService {
    private(set) var requestedURLs = [String]()

    func send(_ request: URLRequest) async throws -> NetworkResponse {
        guard let url = request.url else { throw URLError(.badURL) }
        requestedURLs.append(url.absoluteString)

        let calendar = Calendar(identifier: .gregorian, timeZone: .gmt)
        let numbers = url.lastPathComponent.split(separator: "-").compactMap { Int($0) }
        let isWeek = numbers.count == 3

        guard numbers.count >= 2,
              let start = calendar.date(from: DateComponents(year: numbers[0], month: numbers[1], day: isWeek ? numbers[2] : 1)),
              let daysInMonth = calendar.range(of: .day, in: .month, for: start)?.count
        else {
            throw URLError(.badURL)
        }

        let fajr = url.pathComponents.contains("west") ? "05:10" : "05:00"
        let body = (0..<(isWeek ? 7 : daysInMonth))
            .compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            .map { "\($0.formatted(.iso8601.year().month().day())) \(fajr) 06:30 12:00 15:00 16:00 18:00 19:30" }
            .joined(separator: "\n")

        return NetworkResponse(data: Data(body.utf8), headers: [:], statusCode: 200, request: request, response: URLResponse())
    }
}
