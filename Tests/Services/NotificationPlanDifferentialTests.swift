//
//  NotificationPlanDifferentialTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices
import Testing

/// `NotificationPlan.make`, worded and encoded as the applier hands it to the notification center, against the
/// scheduler it was moved out of (`LegacyNotificationSchedule`): the same removals and adds in the same order, the
/// same Siri prayers, the same scheduled range and the same count, for every fixture, moment and settings row.
struct NotificationPlanDifferentialTests {
    private let fixture = PrayTestFixture()
}

extension NotificationPlanDifferentialTests {
    @Test(arguments: DayFixture.all)
    func thePlanSchedulesWhatTheSchedulerDid(place: DayFixture) async throws {
        var compared = 0
        var differences = [String]()

        for moment in ScheduleMoment.allCases {
            let week = try await place.scheduleInput(at: moment, using: fixture.prayerManager)

            for variant in ScheduleVariant.all {
                let input = variant.input(from: week)
                let legacy = await input.legacy()
                let planned = try input.planned()

                compared += 1
                differences += planned.firstDifference(from: legacy).map { ["\(place.name), \(moment.rawValue), \(variant.id): \($0)"] } ?? []
            }
        }

        #expect(compared == ScheduleMoment.allCases.count * ScheduleVariant.all.count)

        if let first = differences.first {
            Issue.record("\(differences.count) of \(compared) runs differ, first: \(first)")
        }
    }

    /// The matrix proves nothing about a branch no row takes.
    @Test
    func theMatrixReachesEveryBranch() async throws {
        var reached = [String: Set<ScheduleBranch>]()

        for place in DayFixture.all {
            for moment in ScheduleMoment.allCases {
                let week = try await place.scheduleInput(at: moment, using: fixture.prayerManager)

                for variant in ScheduleVariant.all {
                    let input = variant.input(from: week)
                    let branches = await input.legacy().branches(for: input)
                    reached[variant.row.id, default: []].formUnion(branches)
                }
            }
        }

        let missed = NotificationSettingsRow.all.compactMap { row -> String? in
            let unreached = row.reaches.intersection(ScheduleBranch.compiled).subtracting(reached[row.id] ?? [])
            return unreached.isEmpty ? nil : "\(row.id) misses \(unreached.map(\.rawValue).sorted().joined(separator: ", "))"
        }

        #expect(missed.isEmpty, "Rows that miss a branch they are there for: \(missed.joined(separator: "; "))")
        #expect(reached.values.reduce(into: Set()) { $0.formUnion($1) } == ScheduleBranch.compiled)
    }
}
