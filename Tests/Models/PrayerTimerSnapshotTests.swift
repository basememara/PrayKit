//
//  PrayerTimerSnapshotTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing
import ZamzamCore

/// Every field a face reads from a `PrayerTimer`, pinned as it is today over the day fixtures and a settings matrix
/// that reaches each branch of its initializer, so a reshape that moves a field fails with the rows that moved.
///
/// Each fixture's day is sampled at every moment its countdown changes, a second either side of each, and on every
/// hour, with the timer built from the day that holds the moment, as a timeline builds it. The files record and
/// compare as the prayer-time snapshots do (`Snapshot.verify`).
struct PrayerTimerSnapshotTests {
    private let fixture = PrayTestFixture()
}

extension PrayerTimerSnapshotTests {
    @Test(arguments: TimerSnapshotCase.all)
    func timersMatchTheirSnapshot(snapshotCase: TimerSnapshotCase) async throws {
        let calendar = try snapshotCase.place.calendar()
        let settings = snapshotCase.row.settings
        let days = try await days(around: snapshotCase.place)

        let rows = try Self.moments(of: days.own.times, settings: settings, using: calendar).map { moment in
            Self.row(at: moment, timer: Self.timer(at: moment, in: [days.before, days.own], settings: settings, using: calendar), using: calendar)
        }

        let lines = try snapshotCase.header() + [Self.columns.joined(separator: "\t")] + rows
        try Snapshot.verify(lines, at: Self.folder.appending(path: "\(snapshotCase.id).tsv"))
    }

    @Test
    func everyTimerSnapshotFileHasACase() throws {
        let ids = Set(TimerSnapshotCase.all.map(\.id))

        let orphans = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path(percentEncoded: false))
            .filter { $0.hasSuffix(".tsv") && $0.hasSuffix(".actual.tsv") == false }
            .filter { ids.contains(String($0.dropLast(4))) == false }
            .sorted()

        #expect(orphans.isEmpty, "Snapshots without a case, delete them: \(orphans.joined(separator: ", "))")
    }

    /// The khutba rows of the matrix pin nothing without a Friday to fall on.
    @Test
    func aFixtureDayIsAFriday() throws {
        let fridays = try DayFixture.all.filter { try $0.firstNoon().isJumuah(using: try $0.calendar()) }
        #expect(!fridays.isEmpty)
    }
}

// MARK: - Stage

extension PrayerTimerSnapshotTests {
    /// A face reads a listed prayer's stage from the timer's own day or from the day it lists. While the day holds
    /// the moment the two agree; past its own span a day reads the prayer under way as passed, so a face that keeps
    /// a day reloads once it no longer holds now.
    @Test
    func bothStageReadingsAgreeWhileTheDayHoldsTheMoment() async throws {
        var readings = 0
        var disagreements = [String]()

        for place in DayFixture.all {
            let calendar = try place.calendar()
            let days = try await days(around: place)

            for row in TimerSettingsRow.all {
                let timers = try Self.moments(of: days.own.times, settings: row.settings, using: calendar)
                    .compactMap { Self.timer(at: $0, in: [days.before, days.own], settings: row.settings, using: calendar) }

                readings += timers.map(\.listedTimes.count).reduce(0, +)
                disagreements += timers.flatMap { timer in
                    timer.listedTimes.compactMap { prayerTime in
                        let byPrayerDay = timer.prayerDay.stage(of: prayerTime, at: timer.date)
                        let byListedDay = timer.listedDay.stage(of: prayerTime, at: timer.date)
                        guard byPrayerDay != byListedDay else { return nil }
                        return "\(place.name) \(row.id) \(Self.stamp(timer.date, using: calendar)) \(prayerTime.type): \(byPrayerDay), \(byListedDay)"
                    }
                }
            }
        }

        #expect(readings > 0)
        #expect(disagreements.isEmpty, "\(disagreements.count) of \(readings) stage readings disagree, first: \(disagreements.prefix(3))")
    }
}

// MARK: - Sampling

private extension PrayerTimerSnapshotTests {
    static let folder = Snapshot.folder.appending(path: "PrayerTimers")

    static let columns = [
        "date", "day", "type", "timerType", "countdownDate", "timeRemaining", "timeDuration", "progressRemaining", "dangerZone",
        "isDangerZone", "isJumuah", "isNamedJumuah", "stopwatchEnd", "turnover", "listsTomorrow"
    ]

    /// The fixture's day and the one before it, which holds the moments before its Fajr.
    func days(around place: DayFixture) async throws -> (before: PrayerDay, own: PrayerDay) {
        let request = try place.request()
        let noon = try place.firstNoon()
        let dayBefore = try #require(try place.calendar().date(byAdding: .day, value: -1, to: noon))

        return (
            before: try await fixture.prayerManager.fetch(for: dayBefore, with: request),
            own: try await fixture.prayerManager.fetch(for: noon, with: request)
        )
    }

    /// Every moment a prayer's countdown changes with a second either side of it, and every hour on the place's clock
    /// from the prayers' Fajr until their Isha ends.
    static func moments(of prayers: [PrayerTime], settings: Settings, using calendar: Calendar) throws -> [Date] {
        let start = try #require(prayers[.fajr]).dateInterval.start
        let end = try #require(prayers[.isha]).dateInterval.end
        let changes = prayers.flatMap { settings.expandedTimeline(for: $0, using: calendar) }.flatMap { [$0 - 1, $0, $0 + 1] }

        let offset = Double(calendar.timeZone.secondsFromGMT(for: start))
        let firstHour = ((start.timeIntervalSince1970 + offset) / 3600).rounded(.up) * 3600 - offset
        let hours = stride(from: firstHour, to: end.timeIntervalSince1970, by: 3600).map { Date(timeIntervalSince1970: $0) }

        return Set(changes + hours).sorted()
    }

    /// A timer from whichever day holds the moment, as a timeline builds one.
    static func timer(at moment: Date, in days: [PrayerDay], settings: Settings, using calendar: Calendar) -> PrayerTimer? {
        days.first { $0.contains(moment) }.flatMap { PrayerTimer(at: moment, using: $0, settings: settings, timeZone: calendar.timeZone) }
    }

    static func row(at moment: Date, timer: PrayerTimer?, using calendar: Calendar) -> String {
        guard let timer else { return [stamp(moment, using: calendar), "nil"].joined(separator: "\t") }

        return [
            stamp(timer.date, using: calendar),
            String(stamp(timer.prayerDay.date, using: calendar).prefix(10)),
            timer.type.rawValue,
            timer.timerType.rawValue,
            stamp(timer.countdownDate, using: calendar),
            seconds(timer.timeRemaining),
            seconds(timer.timeDuration),
            String(format: "%.6f", timer.progressRemaining),
            String(format: "%.6f", timer.dangerZone),
            "\(timer.isDangerZone)",
            "\(timer.isJumuah)",
            "\(timer.isNamedJumuah)",
            timer.stopwatchEnd.map { stamp($0, using: calendar) } ?? "-",
            timer.turnover.map { stamp($0, using: calendar) } ?? "-",
            "\(timer.listsTomorrow)"
        ].joined(separator: "\t")
    }

    /// A date on the place's clock with its offset from UTC, which tells the two passes of a repeated hour apart.
    static func stamp(_ date: Date, using calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let offset = calendar.timeZone.secondsFromGMT(for: date)

        return String(format: "%04d-%02d-%02d ", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            + String(format: "%02d:%02d:%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
            + (offset < 0 ? "-" : "+")
            + String(format: "%02d%02d", abs(offset) / 3600, abs(offset) % 3600 / 60)
    }

    static func seconds(_ interval: TimeInterval) -> String {
        interval == interval.rounded() ? String(format: "%.0f", interval) : String(format: "%.3f", interval)
    }
}

// MARK: - Cases

struct TimerSnapshotCase: Sendable, CustomTestStringConvertible {
    let place: DayFixture
    let row: TimerSettingsRow

    var id: String { "\(place.slug).\(row.id)" }
    var testDescription: String { id }

    static let all: [TimerSnapshotCase] = DayFixture.all.flatMap { place in
        TimerSettingsRow.all.map { TimerSnapshotCase(place: place, row: $0) }
    }

    func header() throws -> [String] {
        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let weekday = try weekdays[place.calendar().component(.weekday, from: place.firstNoon()) - 1]

        return [
            [
                "# \(id)",
                "lat \(place.latitude)",
                "lon \(place.longitude)",
                "tz \(place.timeZoneIdentifier)",
                "method \(place.method.rawValue)",
                "adjustments \(place.adjustments.map(SnapshotCase.describe) ?? "-")",
                "day \(String(format: "%04d-%02d-%02d", place.year, place.month, place.day)) \(weekday)"
            ].joined(separator: "  "),
            "# settings: \(row.summary)"
        ]
    }
}

/// One row of the settings matrix, each a change to the defaults that takes the timer's initializer down another branch.
struct TimerSettingsRow: Sendable {
    let id: String
    let settings: Settings

    init(_ id: String, _ change: (inout Settings) -> Void = { _ in }) {
        var settings = Settings()
        change(&settings)

        self.id = id
        self.settings = settings
    }

    /// The settings a timer reads, as the row has them.
    var summary: String {
        let iqamaTimes = settings.iqamaTimes
        let iqamas = [
            ("fajr", iqamaTimes.fajr),
            ("dhuhr", iqamaTimes.dhuhr),
            ("asr", iqamaTimes.asr),
            ("maghrib", iqamaTimes.maghrib),
            ("isha", iqamaTimes.isha),
            ("jumuah", iqamaTimes.jumuah)
        ].map { "\($0) \($1.map(\.description) ?? "-")" }

        let reminders = Prayer.allCases.filter(\.isEssential).map { "\($0.rawValue) \(settings.preAdhanMinutes[$0])" }

        return [
            "iqama timer \(settings.isIqamaTimerEnabled ? "on" : "off")",
            "count-up \(settings.stopwatchMinutes)",
            "sunrise after isha \(settings.sunriseAfterIsha ? "on" : "off")",
            "iqamas \(iqamas.joined(separator: ", "))",
            "reminders \(reminders.joined(separator: ", "))"
        ].joined(separator: "  ")
    }
}

extension TimerSettingsRow {
    static let all = [
        TimerSettingsRow("defaults"),
        TimerSettingsRow("iqamas") {
            $0.iqamaTimes = iqamas
            $0.isIqamaTimerEnabled = true
        },
        TimerSettingsRow("iqamas-timer-off") {
            $0.iqamaTimes = iqamas
            $0.isIqamaTimerEnabled = false
        },
        TimerSettingsRow("count-up-0") {
            $0.stopwatchMinutes = 0
        },
        TimerSettingsRow("sunrise-after-isha") {
            $0.sunriseAfterIsha = true
            $0.iqamaTimes.fajr = .minutes(20)
            $0.isIqamaTimerEnabled = true
        },
        TimerSettingsRow("sunrise-after-isha-timer-off") {
            $0.sunriseAfterIsha = true
            $0.iqamaTimes.fajr = .minutes(20)
            $0.isIqamaTimerEnabled = false
        },
        TimerSettingsRow("khutba") {
            $0.iqamaTimes.jumuah = khutba
            $0.isIqamaTimerEnabled = true
        },
        TimerSettingsRow("khutba-timer-off") {
            $0.iqamaTimes.jumuah = khutba
            $0.isIqamaTimerEnabled = false
        },
        // A reminder length of its own for every prayer, so a Friday shows whose minutes size the warning before the khutba
        TimerSettingsRow("reminders-khutba") {
            $0.iqamaTimes.jumuah = khutba
            $0.preAdhanMinutes = PreAdhanMinutes(rawValue: ["fajr": 10, "sunrise": 15, "dhuhr": 20, "asr": 25, "maghrib": 30, "isha": 35])
        }
    ]

    /// An iqama on every obligatory prayer, some counted from the adhan and some at a time of day.
    private static let iqamas = IqamaTimes(
        fajr: .minutes(20),
        dhuhr: .time(hour: 13, minutes: 30),
        asr: .minutes(15),
        maghrib: .minutes(5),
        isha: .time(hour: 21, minutes: 0),
        jumuah: nil
    )

    private static let khutba = IqamaTimes.IqamaType.time(hour: 13, minutes: 30)
}

private extension DayFixture {
    /// The fixture's name as a file name.
    var slug: String {
        name.folding(options: .diacriticInsensitive, locale: .posix)
            .lowercased()
            .split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
            .joined(separator: "-")
    }
}
