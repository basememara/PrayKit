//
//  PrayerTimeSnapshotTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
@testable import PrayCore
import Testing
import ZamzamCore

/// What PrayKit computes today, pinned per place, season and setting, and the method each time zone gives a user, so a
/// dependency bump or an engine change that moves a time, turns a day into an error, or moves a zone to another method
/// fails with the rows that moved.
///
/// A missing snapshot is recorded and fails once for review. A changed one fails and writes `<name>.actual.tsv` beside
/// it; copying that over the snapshot re-records it, and the diff is reviewed in its own commit.
struct PrayerTimeSnapshotTests {
    private let fixture = PrayTestFixture()
}

extension PrayerTimeSnapshotTests {
    @Test(arguments: SnapshotCase.all)
    func prayerTimesMatchTheirSnapshot(snapshotCase: SnapshotCase) async throws {
        let timeZone = try snapshotCase.place.timeZone()
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let request = try snapshotCase.request()
        var rows = [String]()

        for day in snapshotCase.days(using: calendar) {
            rows.append(try await row(for: day, with: request, using: calendar))
        }

        let lines = [snapshotCase.header(method: request.method)]
            + (snapshotCase.note.map { ["# note: \($0)"] } ?? [])
            + [Self.columns.joined(separator: "\t")]
            + rows

        try Snapshot.verify(lines, at: Snapshot.folder.appending(path: "PrayerTimes/\(snapshotCase.id).tsv"))
    }

    @Test
    func everyTimeZoneGivesItsSnapshottedMethod() throws {
        let known = Set(TimeZone.knownTimeZoneIdentifiers)

        let listed = try known.sorted().map { identifier in
            let timeZone = try #require(TimeZone(identifier: identifier))
            let source = CalculationMethod.recommended(for: timeZone, at: nil) == nil ? "fallback" : "map"
            return [identifier, Settings.placeMethod(for: timeZone, at: nil).rawValue, source].joined(separator: "\t")
        }

        let unlisted = CalculationMethod.mapped
            .flatMap { method, identifiers in identifiers.map { (identifier: $0, method: method) } }
            .filter { known.contains($0.identifier) == false }
            .sorted { $0.identifier < $1.identifier }
            .map { [$0.identifier, $0.method.rawValue, "unlisted"].joined(separator: "\t") }

        let lines = [
            "# The method a user whose method follows the place gets in each time zone: its entry in the map, the",
            "# Moonsighting Committee fallback where it has none, and map entries this host doesn't list as a zone.",
            "zone\tmethod\tsource"
        ] + listed + unlisted

        try Snapshot.verify(lines, at: Snapshot.folder.appending(path: "RecommendedMethods.tsv"))
    }

    @Test
    func everySnapshotFileHasACase() throws {
        let folder = Snapshot.folder.appending(path: "PrayerTimes")
        let ids = Set(SnapshotCase.all.map(\.id))

        let orphans = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
            .filter { $0.hasSuffix(".tsv") && $0.hasSuffix(".actual.tsv") == false }
            .filter { ids.contains(String($0.dropLast(4))) == false }
            .sorted()

        #expect(orphans.isEmpty, "Snapshots without a case, delete them: \(orphans.joined(separator: ", "))")
    }
}

private extension PrayerTimeSnapshotTests {
    static let columns = ["date", "utc", "fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha", "midnight", "lastThird", "nextFajr"]
    static let prayers: [Prayer] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha, .midnight, .lastThird]

    func row(for day: SnapshotDay, with request: PrayerAPI.Request, using calendar: Calendar) async throws -> String {
        let noon = try #require(calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)))
        let start = calendar.startOfDay(for: noon)
        let leading = [day.text, Self.offset(of: request.timeZone, at: noon)]

        do {
            let prayerDay = try await fixture.prayerManager.fetch(for: noon, with: request)
            let times = Self.prayers.map { prayer in
                prayerDay.times.first { $0.type == prayer }.map { Self.clock($0.dateInterval.start, from: start, using: calendar) } ?? "-"
            }
            let nextFajr = prayerDay.tomorrow.first { $0.type == .fajr }.map { Self.clock($0.dateInterval.start, from: start, using: calendar) } ?? "-"
            let borrowed = prayerDay.borrowed.map { ["borrowed: \($0.rawValue)"] } ?? []
            return (leading + times + [nextFajr] + borrowed).joined(separator: "\t")
        } catch {
            return (leading + ["error: \(error)"]).joined(separator: "\t")
        }
    }

    /// A wall-clock time, with the days it falls after the row's date (`00:19:00+1d`).
    static func clock(_ date: Date, from start: Date, using calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
        let suffix = days == 0 ? "" : String(format: "%+dd", days)
        return String(format: "%02d:%02d:%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0) + suffix
    }

    static func offset(of timeZone: TimeZone, at date: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        return (seconds < 0 ? "-" : "+") + String(format: "%02d:%02d", abs(seconds) / 3600, abs(seconds) % 3600 / 60)
    }
}

// MARK: - Cases

struct SnapshotCase: Sendable, CustomTestStringConvertible {
    enum Method: Sendable {
        /// The method the place's time zone gives a user whose method follows the place.
        case place
        case set(CalculationMethod)
    }

    let id: String
    let place: SnapshotPlace
    var method: Method = .place
    var jurisprudence: Madhab = .standard
    var fajrDegrees: Double?
    var ishaDegrees: Double?
    var adjustments: PrayerAdjustments?
    var polarResolution = PolarResolution.nearestLatitude
    var note: String?

    var testDescription: String { id }

    func resolvedMethod(in timeZone: TimeZone) -> CalculationMethod {
        switch method {
        case .place:
            Settings.placeMethod(for: timeZone, at: place.coordinates)
        case let .set(method):
            method
        }
    }

    func request() throws -> PrayerAPI.Request {
        let timeZone = try place.timeZone()

        return PrayerAPI.Request(
            coordinates: place.coordinates,
            timeZone: timeZone,
            method: resolvedMethod(in: timeZone),
            jurisprudence: jurisprudence,
            fajrDegrees: fajrDegrees,
            ishaDegrees: ishaDegrees,
            adjustments: adjustments,
            polarResolution: polarResolution
        )
    }

    func header(method: CalculationMethod) -> String {
        let source = switch self.method {
        case .place: "place"
        case .set: "set"
        }

        let polar = polarResolution == .nearestLatitude ? [] : ["polar \(polarResolution.rawValue)"]

        return ([
            "# \(id)",
            "lat \(place.latitude)",
            "lon \(place.longitude)",
            "tz \(place.timeZoneIdentifier)",
            "method \(method.rawValue) (\(source))",
            "madhab \(jurisprudence.rawValue)",
            "degrees \(fajrDegrees.map { "\($0)" } ?? "-")/\(ishaDegrees.map { "\($0)" } ?? "-")",
            "adjustments \(adjustments.map(Self.describe) ?? "-")"
        ] + polar).joined(separator: "  ")
    }

    static func describe(_ adjustments: PrayerAdjustments) -> String {
        [
            "fajr \(adjustments.fajr)\(adjustments.isFajrSunriseRelative ? " before sunrise" : "")",
            "sunrise \(adjustments.sunrise)",
            "dhuhr \(adjustments.dhuhr)",
            "asr \(adjustments.asr)",
            "maghrib \(adjustments.maghrib)",
            "isha \(adjustments.isha)\(adjustments.isIshaMaghribRelative ? " after maghrib" : "")",
            "elevation \(adjustments.elevation?.rawValue ?? "-")"
        ].joined(separator: ", ")
    }

    /// The 21st of every month, a day in Ramadan, the year's turn and the zone's clock changes, all in 2026.
    ///
    /// London's timetable is bundled through 2026, so its Dec 31 would ask the network for 2027's first Fajr.
    func days(using calendar: Calendar) -> [SnapshotDay] {
        let monthly = (1...12).map { SnapshotDay(year: 2026, month: $0, day: 21) }
        let ramadan = [SnapshotDay(year: 2026, month: 3, day: 1)]
        let yearEnd = resolvedMethod(in: calendar.timeZone) == .london ? [] : [SnapshotDay(year: 2026, month: 12, day: 31)]
        return Set(monthly + ramadan + yearEnd + SnapshotDay.clockChanges(using: calendar)).sorted()
    }
}

struct SnapshotPlace: Sendable {
    let id: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String

    init(_ id: String, _ latitude: Double, _ longitude: Double, _ timeZoneIdentifier: String) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var coordinates: Coordinates { Coordinates(latitude: latitude, longitude: longitude) }

    func timeZone() throws -> TimeZone {
        try #require(TimeZone(identifier: timeZoneIdentifier))
    }
}

struct SnapshotDay: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    var text: String { String(format: "%04d-%02d-%02d", year, month, day) }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// The local days the zone's clocks change on in 2026, none where they never do.
    static func clockChanges(using calendar: Calendar) -> [SnapshotDay] {
        guard let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) else { return [] }

        return sequence(first: start) { calendar.timeZone.nextDaylightSavingTimeTransition(after: $0) }
            .dropFirst()
            .prefix { calendar.component(.year, from: $0) == 2026 }
            .map { calendar.dateComponents([.year, .month, .day], from: $0) }
            .compactMap { parts in
                guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
                return SnapshotDay(year: year, month: month, day: day)
            }
    }
}

extension SnapshotPlace {
    static let kualaLumpur = SnapshotPlace("kuala-lumpur", 3.1390, 101.6869, "Asia/Kuala_Lumpur")
    static let london = SnapshotPlace("london", 51.5074, -0.1278, "Europe/London")
    static let oslo = SnapshotPlace("oslo", 59.9139, 10.7522, "Europe/Oslo")
    static let istanbul = SnapshotPlace("istanbul", 41.0082, 28.9784, "Europe/Istanbul")
    static let karachi = SnapshotPlace("karachi", 24.8607, 67.0011, "Asia/Karachi")
    static let cairo = SnapshotPlace("cairo", 30.0444, 31.2357, "Africa/Cairo")
    static let tromso = SnapshotPlace("tromso", 69.6492, 18.9553, "Europe/Oslo")

    /// Where users are, across the latitude bands, both hemispheres and the zones with odd offsets.
    static let all: [SnapshotPlace] = [
        kualaLumpur,
        SnapshotPlace("jakarta", -6.2088, 106.8456, "Asia/Jakarta"),
        SnapshotPlace("singapore", 1.3521, 103.8198, "Asia/Singapore"),
        SnapshotPlace("makkah", 21.4225, 39.8262, "Asia/Riyadh"),
        SnapshotPlace("dubai", 25.2048, 55.2708, "Asia/Dubai"),
        karachi,
        SnapshotPlace("lagos", 6.5244, 3.3792, "Africa/Lagos"),
        SnapshotPlace("muscat", 23.5880, 58.3829, "Asia/Muscat"),
        cairo,
        istanbul,
        SnapshotPlace("tehran", 35.6892, 51.3890, "Asia/Tehran"),
        SnapshotPlace("casablanca", 33.5731, -7.5898, "Africa/Casablanca"),
        SnapshotPlace("algiers", 36.7538, 3.0588, "Africa/Algiers"),
        SnapshotPlace("tunis", 36.8065, 10.1815, "Africa/Tunis"),
        SnapshotPlace("kuwait", 29.3759, 47.9774, "Asia/Kuwait"),
        SnapshotPlace("doha", 25.2854, 51.5310, "Asia/Qatar"),
        SnapshotPlace("amman", 31.9539, 35.9106, "Asia/Amman"),
        SnapshotPlace("baghdad", 33.3152, 44.3661, "Asia/Baghdad"),
        SnapshotPlace("moscow", 55.7558, 37.6173, "Europe/Moscow"),
        SnapshotPlace("paris", 48.8566, 2.3522, "Europe/Paris"),
        SnapshotPlace("new-york", 40.7128, -74.0060, "America/New_York"),
        SnapshotPlace("toronto", 43.6510, -79.3470, "America/Toronto"),
        SnapshotPlace("los-angeles", 34.0522, -118.2437, "America/Los_Angeles"),
        london,
        SnapshotPlace("mumbai", 19.0760, 72.8777, "Asia/Kolkata"),
        SnapshotPlace("mumbai-as-calcutta", 19.0760, 72.8777, "Asia/Calcutta"),
        SnapshotPlace("kyiv", 50.4501, 30.5234, "Europe/Kyiv"),
        SnapshotPlace("kyiv-as-kiev", 50.4501, 30.5234, "Europe/Kiev"),
        SnapshotPlace("sydney", -33.8688, 151.2093, "Australia/Sydney"),
        SnapshotPlace("adelaide", -34.9285, 138.6007, "Australia/Adelaide"),
        SnapshotPlace("cape-town", -33.9249, 18.4241, "Africa/Johannesburg"),
        SnapshotPlace("auckland", -36.8485, 174.7633, "Pacific/Auckland"),
        SnapshotPlace("punta-arenas", -53.1638, -70.9171, "America/Punta_Arenas"),
        SnapshotPlace("luton", 51.8787, -0.4200, "Europe/London"),
        SnapshotPlace("manchester", 53.4808, -2.2426, "Europe/London"),
        SnapshotPlace("edinburgh", 55.9533, -3.1883, "Europe/London"),
        oslo,
        SnapshotPlace("stockholm", 59.3293, 18.0686, "Europe/Stockholm"),
        SnapshotPlace("helsinki", 60.1699, 24.9384, "Europe/Helsinki"),
        SnapshotPlace("reykjavik", 64.1466, -21.9426, "Atlantic/Reykjavik"),
        tromso
    ]
}

extension SnapshotCase {
    static let all: [SnapshotCase] = places + methods + settings + relativeLimits

    static let places: [SnapshotCase] = SnapshotPlace.all.map { place in
        SnapshotCase(id: "\(place.id).place", place: place, note: notes[place.id])
    }

    /// Rows known to be wrong today, so nobody takes them for verified times.
    static let notes: [String: String] = [:]

    static let methods: [SnapshotCase] = [SnapshotPlace.kualaLumpur, .london, .oslo].flatMap { place in
        CalculationMethod.allCases.map { SnapshotCase(id: "\(place.id).\($0.rawValue.lowercased())", place: place, method: .set($0)) }
    }

    static let settings: [SnapshotCase] = ElevationRule.allCases.map { rule in
        SnapshotCase(id: "oslo.place.\(rule.rawValue.lowercased())", place: .oslo, adjustments: .elevation(rule))
    } + [
        SnapshotCase(id: "kuala-lumpur.place.absolute", place: .kualaLumpur, adjustments: .absolute(2, -1, 3, 1, 2, 4)),
        SnapshotCase(id: "kuala-lumpur.place.fajr-before-sunrise", place: .kualaLumpur, adjustments: .relative(fajr: -90)),
        SnapshotCase(id: "kuala-lumpur.place.isha-after-maghrib", place: .kualaLumpur, adjustments: .relative(isha: 90)),
        SnapshotCase(id: "kuala-lumpur.custom.18-17", place: .kualaLumpur, method: .set(.custom), fajrDegrees: 18, ishaDegrees: 17),
        SnapshotCase(id: "kuala-lumpur.custom.0-17", place: .kualaLumpur, method: .set(.custom), fajrDegrees: 0, ishaDegrees: 17),
        SnapshotCase(id: "istanbul.place.hanafi", place: .istanbul, jurisprudence: .hanafi),
        SnapshotCase(id: "karachi.place.hanafi", place: .karachi, jurisprudence: .hanafi),
        SnapshotCase(id: "cairo.place.hanafi", place: .cairo, jurisprudence: .hanafi),
        SnapshotCase(id: "tromso.place.nearestday", place: .tromso, polarResolution: .nearestDay)
    ]

    /// A relative Fajr or Isha that can't apply: on the wrong side of sunrise or Maghrib, which saved settings can
    /// hold, or far enough to put Isha past the next Fajr. London's timetable and a calculated method treat it differently.
    static let relativeLimits: [SnapshotCase] = [(name: "place", method: Method.place), (name: "moon", method: .set(.moonsightingCommittee))]
        .flatMap { name, method in
            [
                SnapshotCase(
                    id: "london.\(name).fajr-300-before-sunrise-isha-300-after-maghrib",
                    place: .london,
                    method: method,
                    adjustments: .relative(fajr: -300, isha: 300)
                ),
                SnapshotCase(id: "london.\(name).fajr-300-before-sunrise", place: .london, method: method, adjustments: .relative(fajr: -300)),
                SnapshotCase(id: "london.\(name).fajr-1-after-sunrise", place: .london, method: method, adjustments: .relative(fajr: 1)),
                SnapshotCase(id: "london.\(name).fajr-300-after-sunrise", place: .london, method: method, adjustments: .relative(fajr: 300)),
                SnapshotCase(id: "london.\(name).isha-300-after-maghrib", place: .london, method: method, adjustments: .relative(isha: 300)),
                SnapshotCase(id: "london.\(name).isha-1-before-maghrib", place: .london, method: method, adjustments: .relative(isha: -1)),
                SnapshotCase(id: "london.\(name).isha-300-before-maghrib", place: .london, method: method, adjustments: .relative(isha: -300))
            ]
        }
}

private extension PrayerAdjustments {
    static func elevation(_ rule: ElevationRule) -> PrayerAdjustments {
        PrayerAdjustments(
            fajr: 0,
            sunrise: 0,
            dhuhr: 0,
            asr: 0,
            maghrib: 0,
            isha: 0,
            isFajrSunriseRelative: false,
            isIshaMaghribRelative: false,
            elevation: rule
        )
    }

    static func absolute(_ fajr: Int, _ sunrise: Int, _ dhuhr: Int, _ asr: Int, _ maghrib: Int, _ isha: Int) -> PrayerAdjustments {
        PrayerAdjustments(
            fajr: fajr,
            sunrise: sunrise,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha,
            isFajrSunriseRelative: false,
            isIshaMaghribRelative: false,
            elevation: nil
        )
    }
}

// MARK: - Snapshot files

enum Snapshot {
    static let folder = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Snapshots")

    /// Records a missing snapshot, or fails with every row that moved and writes the new one beside it.
    static func verify(_ lines: [String], at url: URL, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let snapshot = lines.joined(separator: "\n") + "\n"
        let actualURL = url.deletingPathExtension().appendingPathExtension("actual.tsv")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try snapshot.write(to: url, atomically: true, encoding: .utf8)
            Issue.record("Recorded \(url.lastPathComponent): review it, then run again.", sourceLocation: sourceLocation)
            return
        }

        let expected = try String(contentsOf: url, encoding: .utf8)

        guard expected != snapshot else {
            try? fileManager.removeItem(at: actualURL)
            return
        }

        try snapshot.write(to: actualURL, atomically: true, encoding: .utf8)

        let changes = SnapshotTable.changes(from: SnapshotTable(expected), to: SnapshotTable(snapshot))
        let shown = changes.prefix(40) + (changes.count > 40 ? ["…and \(changes.count - 40) more, see \(actualURL.lastPathComponent)"] : [])
        Issue.record(Comment(rawValue: "\(url.lastPathComponent) changed:\n" + shown.joined(separator: "\n")), sourceLocation: sourceLocation)
    }
}

/// A snapshot read back as its comment lines, its column names and its rows keyed by their first field.
private struct SnapshotTable {
    let comments: [String]
    let columns: [String]
    let rows: [String: [String]]

    init(_ text: String) {
        let lines = text.split(separator: "\n").map(String.init)
        let fields = lines.filter { $0.hasPrefix("#") == false }.map { $0.components(separatedBy: "\t") }

        comments = lines.filter { $0.hasPrefix("#") }
        columns = fields.first ?? []
        rows = Dictionary(fields.dropFirst().map { ($0.first ?? "", $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func changes(from old: SnapshotTable, to new: SnapshotTable) -> [String] {
        let comments = old.comments == new.comments ? [] : old.comments.map { "- \($0)" } + new.comments.map { "+ \($0)" }

        let rows = Set(old.rows.keys).union(new.rows.keys).sorted().flatMap { key -> [String] in
            switch (old.rows[key], new.rows[key]) {
            case let (.some(before), .some(after)):
                return fieldChanges(key: key, from: before, to: after, columns: new.columns)
            case (.none, .some):
                return ["+ \(key)"]
            case (.some, .none):
                return ["- \(key)"]
            case (.none, .none):
                return []
            }
        }

        return comments + rows
    }

    static func fieldChanges(key: String, from before: [String], to after: [String], columns: [String]) -> [String] {
        stride(from: 1, to: max(before.count, after.count), by: 1).compactMap { index in
            let old = index < before.count ? before[index] : ""
            let new = index < after.count ? after[index] : ""
            guard old != new else { return nil }

            let column = index < columns.count ? columns[index] : "#\(index)"
            let delta = seconds(old).flatMap { start in seconds(new).map { " (\(Self.delta($0 - start)))" } } ?? ""
            return "\(key) \(column): \(old) → \(new)\(delta)"
        }
    }

    /// Seconds into the row's day of a `HH:mm:ss` time, with its `+Nd` suffix.
    static func seconds(_ field: String) -> Int? {
        let clock = field.prefix(8).split(separator: ":").compactMap { Int($0) }
        guard field.count >= 8, clock.count == 3 else { return nil }

        let days = field.count > 8 ? Int(field.dropFirst(8).dropLast()) ?? 0 : 0
        return days * 86_400 + clock[0] * 3600 + clock[1] * 60 + clock[2]
    }

    static func delta(_ seconds: Int) -> String {
        seconds.isMultiple(of: 60) ? String(format: "%+d min", seconds / 60) : String(format: "%+d s", seconds)
    }
}
