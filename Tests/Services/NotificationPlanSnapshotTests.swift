//
//  NotificationPlanSnapshotTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices
import Testing

/// The plan a scheduling run makes, pinned as it is today: every request in the order it is added, then the removals,
/// the Siri prayers, the scheduled range and the count, so a reshape of `NotificationPlan.make` that moves a minute,
/// swaps a sound or drops a notification fails with the rows that moved.
///
/// Every day fixture is planned at the defaults and with every kind of notification on, and two of them across the
/// rows that take the remaining branches. The files record and compare as the prayer-time snapshots do
/// (`Snapshot.verify`).
struct NotificationPlanSnapshotTests {
    private let fixture = PrayTestFixture()
}

extension NotificationPlanSnapshotTests {
    @Test(arguments: PlanSnapshotCase.all)
    func plansMatchTheirSnapshot(snapshotCase: PlanSnapshotCase) async throws {
        let input = try await snapshotCase.input(using: fixture.prayerManager)
        let plan = input.plan()

        let lines = try snapshotCase.header(for: input)
            + [Self.columns.joined(separator: "\t")]
            + plan.requests.map { Self.row(for: $0, in: input) }
            + plan.removals.map { Self.row(for: $0) }
            + Self.summary(of: plan, using: input.calendar)

        try Snapshot.verify(lines, at: Self.folder.appending(path: "\(snapshotCase.id).tsv"))
    }

    @Test
    func everyPlanSnapshotFileHasACase() throws {
        let ids = Set(PlanSnapshotCase.all.map(\.id))

        let orphans = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path(percentEncoded: false))
            .filter { $0.hasSuffix(".tsv") && $0.hasSuffix(".actual.tsv") == false }
            .filter { ids.contains(String($0.dropLast(4))) == false }
            .sorted()

        #expect(orphans.isEmpty, "Snapshots without a case, delete them: \(orphans.joined(separator: ", "))")
    }

    /// A chosen case names its fixture and its settings row, and a name that matches neither would drop it unseen.
    @Test
    func everyChosenCaseIsFound() {
        #expect(PlanSnapshotCase.chosen.allSatisfy { $0 != nil })
        #expect(Set(PlanSnapshotCase.all.map(\.id)).count == PlanSnapshotCase.all.count)
    }

    /// The snapshots hold a reshape to nothing on a branch none of them takes.
    @Test
    func theSnapshotsReachEveryBranch() async throws {
        var reached = Set<ScheduleBranch>()

        for snapshotCase in PlanSnapshotCase.all {
            let input = try await snapshotCase.input(using: fixture.prayerManager)
            reached.formUnion(input.plan().branches(for: input))
        }

        let missed = Set(ScheduleBranch.allCases).subtracting(reached).map(\.rawValue).sorted()
        #expect(missed.isEmpty, "Branches no snapshot takes: \(missed.joined(separator: ", "))")
    }
}

// MARK: - Rows

private extension NotificationPlanSnapshotTests {
    static let folder = Snapshot.folder.appending(path: "NotificationPlans")
    static let columns = ["entry", "kind", "fire", "body", "sound", "level", "category", "payload"]

    static func row(for request: NotificationPlan.Request, in input: ScheduleInput) -> String {
        let calendar = input.calendar

        return [
            request.identifier,
            "add",
            describe(request.trigger, using: calendar),
            describe(request.body, using: calendar),
            describe(request.sound),
            request.interruptionLevel?.name ?? "-",
            request.category.rawValue,
            describe(request.payload, of: request, in: input)
        ].joined(separator: "\t")
    }

    static func row(for removal: NotificationPlan.Removal) -> String {
        switch removal {
        case let .identifier(identifier):
            [identifier, "remove"].joined(separator: "\t")
        case let .category(category):
            [category.rawValue, "remove-category"].joined(separator: "\t")
        }
    }

    static func summary(of plan: NotificationPlan, using calendar: Calendar) -> [String] {
        let shortcuts = plan.shortcutPrayers.map { "\($0.type.rawValue) \(Snapshot.stamp($0.dateInterval.start, using: calendar).dropFirst(5).prefix(14))" }

        return [
            (["shortcuts", "\(shortcuts.count)"] + shortcuts).joined(separator: "\t"),
            ["firstScheduled", plan.firstScheduled.map { Snapshot.stamp($0, using: calendar) } ?? "-"].joined(separator: "\t"),
            ["lastScheduled", Snapshot.stamp(plan.lastScheduled, using: calendar)].joined(separator: "\t"),
            ["requested", "\(plan.requested)"].joined(separator: "\t")
        ]
    }

    static func describe(_ trigger: NotificationPlan.Trigger, using calendar: Calendar) -> String {
        switch trigger {
        case let .date(date):
            Snapshot.stamp(date, using: calendar)
        case let .region(center, radius):
            "region \(center.latitude),\(center.longitude) \(Int(radius))m"
        }
    }

    static func describe(_ body: NotificationPlan.Body, using calendar: Calendar) -> String {
        switch body {
        case let .prayer(prayerTime):
            "prayer \(describe(prayerTime, using: calendar))"
        case let .iqama(prayerTime, minutes, isJumuah):
            "iqama \(describe(prayerTime, using: calendar)) \(minutes)m" + (isJumuah ? " jumuah" : "")
        case let .reminder(prayerTime, minutes):
            "reminder \(describe(prayerTime, using: calendar)) \(minutes)m"
        case let .duha(date):
            "duha \(Snapshot.stamp(date, using: calendar))"
        case .iqamaUpdate:
            "iqamaUpdate"
        case .calibrate:
            "calibrate"
        case .beacon:
            "beacon"
        }
    }

    /// A prayer by its start on the place's clock and its length, with where a polar day borrowed it from.
    static func describe(_ prayerTime: PrayerTime, using calendar: Calendar) -> String {
        let length = Snapshot.seconds(prayerTime.dateInterval.duration)
        let borrowed = prayerTime.borrowed.map { " borrowed:\($0.rawValue)" } ?? ""
        return "\(prayerTime.type.rawValue) \(Snapshot.stamp(prayerTime.dateInterval.start, using: calendar)) \(length)s\(borrowed)"
    }

    static func describe(_ sound: NotificationPlan.Sound?) -> String {
        switch sound {
        case .default:
            "default"
        case let .file(file):
            file
        case nil:
            "-"
        }
    }

    /// A payload by its `userInfo` key; a prayer time that is the body's own is not repeated.
    static func describe(_ payload: NotificationPlan.Payload, of request: NotificationPlan.Request, in input: ScheduleInput) -> String {
        switch payload {
        case let .prayerTime(prayerTime):
            request.body.prayerTime == prayerTime ? "prayer_time" : "prayer_time \(describe(prayerTime, using: input.calendar))"
        case let .iqamaUpdateOrigin(date):
            "origin_at \(Snapshot.stamp(date, using: input.calendar))"
        case let .requestHash(requestHash):
            "prayer_request_hash \(requestHash.id)" + (requestHash == input.requestHash ? "" : " not the run's")
        case let .coordinates(coordinates):
            "coordinates \(coordinates.latitude),\(coordinates.longitude)"
        }
    }
}

private extension NotificationPlan.Body {
    var prayerTime: PrayerTime? {
        switch self {
        case let .prayer(prayerTime), let .iqama(prayerTime, _, _), let .reminder(prayerTime, _):
            prayerTime
        case .duha, .iqamaUpdate, .calibrate, .beacon:
            nil
        }
    }
}

// MARK: - Cases

struct PlanSnapshotCase: Sendable, CustomTestStringConvertible {
    let place: DayFixture
    let variant: ScheduleVariant
    let moment: ScheduleMoment

    var id: String { "\(place.slug).\(variant.id)" }
    var testDescription: String { id }

    func input(using prayerManager: PrayerManager) async throws -> ScheduleInput {
        variant.input(from: try await place.scheduleInput(at: moment, using: prayerManager))
    }

    func header(for input: ScheduleInput) throws -> [String] {
        let calendar = input.calendar
        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let weekday = try weekdays[calendar.component(.weekday, from: place.firstNoon()) - 1]

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
            "# settings: \(variant.row.summary)",
            [
                "# now \(Snapshot.stamp(input.now, using: calendar)) (\(moment.rawValue))",
                "budget \(input.budget)",
                "iqama update origin \(input.iqamaUpdateOrigin.map { Snapshot.stamp($0, using: calendar) } ?? "-")"
            ].joined(separator: "  "),
            "# requests in the order they are added, then the removals; a payload of prayer_time alone carries the body's own prayer"
        ]
    }
}

extension PlanSnapshotCase {
    static let all: [PlanSnapshotCase] = everywhere + chosen.compactMap(\.self)

    /// Every fixture after its first Dhuhr at the defaults, and an hour before its first Fajr with everything on.
    static let everywhere: [PlanSnapshotCase] = DayFixture.all.flatMap { place in
        [
            PlanSnapshotCase(place: place, variant: ScheduleVariant(row: .defaults, budget: NotificationPlan.defaultBudget, origin: .absent), moment: .afterDhuhr),
            PlanSnapshotCase(place: place, variant: ScheduleVariant(row: .everythingOn, budget: NotificationPlan.defaultBudget, origin: .absent), moment: .beforeFajr)
        ]
    }

    /// The rows that take the remaining branches, on a plain week and on one that begins on a Friday.
    static let chosen: [PlanSnapshotCase?] = [
        PlanSnapshotCase("Kuala Lumpur", "everything-off", at: .midMorning),
        PlanSnapshotCase("Kuala Lumpur", "silencing-adhans", at: .beforeFajr),
        PlanSnapshotCase("Kuala Lumpur", "mixed-sounds", at: .beforeFajr),
        PlanSnapshotCase("Kuala Lumpur", "night-times", at: .afterIsha),
        PlanSnapshotCase("Kuala Lumpur", "duha-time", at: .beforeFajr),
        PlanSnapshotCase("Kuala Lumpur", "iqamas", at: .afterDhuhr),
        PlanSnapshotCase("Kuala Lumpur", "everything-on", at: .afterIsha, budget: 7),
        PlanSnapshotCase("Kuala Lumpur", "update-weekly", at: .midMorning, origin: .outside),
        PlanSnapshotCase("Kuala Lumpur", "update-monthly", at: .midMorning, budget: 20, origin: .inside),
        PlanSnapshotCase("Kuala Lumpur", "gps-off", at: .midMorning),
        PlanSnapshotCase("San Francisco in June", "khutba-only", at: .fridayMorning),
        PlanSnapshotCase("San Francisco in June", "iqamas", at: .fridayAfterDhuhr, budget: 20),
        PlanSnapshotCase("San Francisco in June", "iqamas-reminder-silent", at: .fridayMorning),
        PlanSnapshotCase("San Francisco in June", "reminder-minutes", at: .fridayMorning)
    ]

    init?(_ placeName: String, _ rowID: String, at moment: ScheduleMoment, budget: Int = NotificationPlan.defaultBudget, origin: ScheduleOrigin = .absent) {
        guard let place = DayFixture.all.first(where: { $0.name == placeName }), let row = NotificationSettingsRow.row(rowID) else {
            return nil
        }

        self.init(place: place, variant: ScheduleVariant(row: row, budget: budget, origin: origin), moment: moment)
    }
}
