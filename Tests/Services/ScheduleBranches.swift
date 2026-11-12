//
//  ScheduleBranches.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices
import ZamzamCore

/// A branch of the scheduler that leaves a trace in what it adds or removes.
enum ScheduleBranch: String, CaseIterable, Sendable {
    case prayerAdded
    /// Sunrise, midnight or the last third, which notify in the reminder category.
    case sideTimeAdded
    case prayerAddedSilent
    case prayerRemoved
    case iqamaAdded
    case iqamaAddedSilent
    case jumuahIqamaAdded
    /// A Friday Dhuhr still to come whose own notification gives way to its iqama reminder.
    case jumuahReplacesDhuhr
    /// An iqama reminder for a prayer whose adhan has passed.
    case iqamaForBegunPrayer
    case iqamaRemoved
    case reminderAdded
    case reminderSilencedByAlarm
    /// A Friday reminder counted back from the khutba rather than from Dhuhr.
    case jumuahReminderBeforeKhutba
    case reminderRemoved
    case imsakAdded
    case imsakRemoved
    case duhaAdded
    case duhaRemoved
    case iqamaUpdateKeepsOrigin
    case iqamaUpdateStartsNow
    case iqamaUpdateRemoved
    case calibrate
    case beaconAdded
    case beaconRemoved
    case budgetExhausted
    /// The iqama update reminder is added with nothing left, so the run asks for one more than its budget.
    case budgetOverdrawn
    case nothingScheduled
}

extension NotificationPlan {
    /// The branches the run took, read from what it adds and removes.
    func branches(for input: ScheduleInput) -> Set<ScheduleBranch> {
        let addedIdentifiers = Set(requests.map(\.identifier))

        let removed = removals.compactMap { removal -> ScheduleBranch? in
            switch removal {
            case let .identifier(identifier):
                ScheduleRequestKind(identifier).removed
            case .category:
                .beaconRemoved
            }
        }

        let overall: [ScheduleBranch?] = [
            requested >= input.budget ? .budgetExhausted : nil,
            requested > input.budget ? .budgetOverdrawn : nil,
            firstScheduled == nil ? .nothingScheduled : nil
        ]

        return Set(requests.flatMap { $0.branches(for: input, addedIdentifiers: addedIdentifiers) } + removed + overall.compactMap(\.self))
    }
}

private enum ScheduleRequestKind {
    case prayer
    case iqama
    case reminder
    case imsak
    case duha
    case iqamaUpdate
    case calibrate
    case beacon

    init(_ identifier: String) {
        self = switch identifier {
        case "calibrate":
            .calibrate
        case "calibrate-beacon":
            .beacon
        case NotificationPlan.iqamaUpdateIdentifier:
            .iqamaUpdate
        case _ where identifier.hasSuffix("-iqama-reminder"):
            .iqama
        case _ where identifier.hasSuffix("-imsak-reminder"):
            .imsak
        case _ where identifier.hasSuffix("-duha-reminder"):
            .duha
        case _ where identifier.hasSuffix("-reminder"):
            .reminder
        default:
            .prayer
        }
    }

    var removed: ScheduleBranch? {
        switch self {
        case .prayer:
            .prayerRemoved
        case .iqama:
            .iqamaRemoved
        case .reminder:
            .reminderRemoved
        case .imsak:
            .imsakRemoved
        case .duha:
            .duhaRemoved
        case .iqamaUpdate:
            .iqamaUpdateRemoved
        case .calibrate, .beacon:
            nil
        }
    }
}

private extension NotificationPlan.Request {
    func branches(for input: ScheduleInput, addedIdentifiers: Set<String>) -> [ScheduleBranch] {
        let isJumuah = prayerTime?.isJumuah(using: input.calendar) ?? false
        let hasBegun = prayerTime.map { $0.dateInterval.start <= input.now } ?? false

        switch ScheduleRequestKind(identifier) {
        case .prayer:
            return [category == .main ? .prayerAdded : .sideTimeAdded] + (sound == nil ? [.prayerAddedSilent] : [])
        case .iqama:
            let prayerIdentifier = String(identifier.dropLast("-iqama-reminder".count))
            let replaces = isJumuah && !hasBegun && !addedIdentifiers.contains(prayerIdentifier) && input.settings.notificationSounds[.dhuhr] != .off

            return [isJumuah ? .jumuahIqamaAdded : .iqamaAdded]
                + (sound == nil ? [.iqamaAddedSilent] : [])
                + (hasBegun ? [.iqamaForBegunPrayer] : [])
                + (replaces ? [.jumuahReplacesDhuhr] : [])
        case .reminder:
            let isSilenced = sound == nil && prayerTime.flatMap { input.settings.reminderSounds[$0.type]?.file } != nil
            let fromDhuhr = prayerTime.map { $0.dateInterval.start - .minutes(input.settings.preAdhanMinutes[$0.type]) }

            return [.reminderAdded]
                + (isSilenced ? [.reminderSilencedByAlarm] : [])
                + (isJumuah && fireDate != fromDhuhr ? [.jumuahReminderBeforeKhutba] : [])
        case .imsak:
            return [.imsakAdded]
        case .duha:
            return [.duhaAdded]
        case .iqamaUpdate:
            return [payload == .iqamaUpdateOrigin(input.now) ? .iqamaUpdateStartsNow : .iqamaUpdateKeepsOrigin]
        case .calibrate:
            return [.calibrate]
        case .beacon:
            return [.beaconAdded]
        }
    }
}
