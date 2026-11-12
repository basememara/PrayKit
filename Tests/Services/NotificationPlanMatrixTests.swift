//
//  NotificationPlanMatrixTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices
import Testing

/// `NotificationPlan.make` for every fixture, moment and settings row, far more runs than the snapshots pin, each
/// held to what must be true of any plan.
struct NotificationPlanMatrixTests {
    private let fixture = PrayTestFixture()
}

extension NotificationPlanMatrixTests {
    @Test(arguments: DayFixture.all)
    func everyPlanKeepsTheRules(place: DayFixture) async throws {
        var checked = 0
        var broken = [String]()

        for moment in ScheduleMoment.allCases {
            let week = try await place.scheduleInput(at: moment, using: fixture.prayerManager)

            for variant in ScheduleVariant.all {
                let input = variant.input(from: week)

                checked += 1
                broken += input.plan().brokenRules(for: input).map { "\(place.name), \(moment.rawValue), \(variant.id): \($0)" }
            }
        }

        #expect(checked == ScheduleMoment.allCases.count * ScheduleVariant.all.count)
        #expect(broken.isEmpty, "\(broken.count) rules broken in \(checked) plans, first: \(broken.first ?? "-")")
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
                    reached[variant.row.id, default: []].formUnion(input.plan().branches(for: input))
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

// MARK: - Rules

private extension NotificationPlan {
    /// The rules this plan breaks, by name.
    func brokenRules(for input: ScheduleInput) -> [String] {
        let identifiers = requests.map(\.identifier)
        let forPrayers = requests.filter { $0.prayerTime != nil }
        let fetchedEnd = input.days.last?.times.last?.dateInterval.end ?? input.now

        let removed = Set(
            removals.compactMap { removal -> String? in
                guard case let .identifier(identifier) = removal else { return nil }
                return identifier
            }
        )

        // The run stops walking the prayers once the budget is spent, and lists a Siri prayer for each one it reached
        let silenced = NotificationServiceUN.prayersToNotify(in: input.days, from: input.now, calendar: input.calendar)
            .prefix(shortcutPrayers.count)
            .filter { (input.settings.notificationSounds[$0.prayerTime.type] ?? .off) == .off }
            .map { "\($0.prefix)-\($0.prayerTime.type)" }

        let rules: [(name: String, holds: Bool)] = [
            ("an identifier is requested twice", Set(identifiers).count == identifiers.count),
            ("a request is also removed", removed.isDisjoint(with: identifiers)),
            ("a prayer with its sound off is requested or left in place", silenced.allSatisfy { removed.contains($0) && !identifiers.contains($0) }),
            ("a prayer's request fires at or before now", forPrayers.compactMap(\.fireDate).allSatisfy { $0 > input.now }),
            ("a prayer's request fires after the fetched days", forPrayers.compactMap(\.fireDate).allSatisfy { $0 <= fetchedEnd }),
            ("the iqama update fires at or before now", fireDates(in: .reminder).allSatisfy { $0 > input.now }),
            ("calibrate fires at or before now with budget to spare", requested >= input.budget || fireDates(in: .calibrate).allSatisfy { $0 > input.now }),
            ("calibrate is not requested once", fireDates(in: .calibrate).count == 1),
            ("the budget is overdrawn by more than one", requested <= input.budget + 1),
            ("the count is not the prayers' requests and the iqama update", requested == requests.count { $0.category != .calibrate && $0.category != .beacon })
        ]

        return rules.filter { !$0.holds }.map(\.name)
    }

    /// When the requests that are for no prayer fire: the iqama update among the reminders, and calibrate.
    func fireDates(in category: NotificationCategory) -> [Date] {
        requests.filter { $0.prayerTime == nil && $0.category == category }.compactMap(\.fireDate)
    }
}
