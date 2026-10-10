//
//  SettingsDocumentTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct SettingsDocumentTests {}

// MARK: - Coverage

extension SettingsDocumentTests {
    @Test
    func everySettingHasAKey() {
        let properties = Set(Mirror(reflecting: Settings()).children.compactMap(\.label))
        let keys = Set(SettingKey.allCases.map { "\($0)" })

        #expect(properties == keys)
    }

    @Test
    func everyKeyIsInTheFieldTable() {
        #expect(Set(SettingsDocument().changedKeys(to: .everyFieldChanged)) == Set(SettingKey.allCases))
    }
}

// MARK: - Editing

extension SettingsDocumentTests {
    @Test
    func anEditStampsOnlyChangedSettings() {
        let edited = SettingsDocument().editing(at: Date(timeIntervalSince1970: 10)) {
            $0.snoozeMinutes = 5
            $0.theme = Settings().theme
        }

        #expect(edited.revisions == [.snoozeMinutes: Revision(milliseconds: 10_000)])
    }

    @Test
    func anEditThatChangesNothingKeepsTheDocument() {
        let document = SettingsDocument().editing(at: Date(timeIntervalSince1970: 10)) { $0.snoozeMinutes = 5 }

        #expect(document.editing(at: Date(timeIntervalSince1970: 20)) { $0.snoozeMinutes = 5 } == document)
    }

    @Test
    func aSlowClockStillStampsAfterTheNewestRevisionSeen() {
        let fromTheFuture = SettingsDocument(revisions: [.theme: Revision(milliseconds: 9_000_000)])
        let edited = fromTheFuture.editing(at: Date(timeIntervalSince1970: 1)) { $0.snoozeMinutes = 5 }

        #expect(edited.revision(of: .snoozeMinutes) == Revision(milliseconds: 9_000_001))
    }
}

// MARK: - Merging

extension SettingsDocumentTests {
    @Test
    func theNewerRevisionWinsPerSetting() {
        let base = SettingsDocument()
        let phone = base.editing(at: Date(timeIntervalSince1970: 100)) { $0.calculationMethod = .karachi }
            .editing(at: Date(timeIntervalSince1970: 300)) { $0.snoozeMinutes = 5 }
        let watch = base.editing(at: Date(timeIntervalSince1970: 200)) {
            $0.calculationMethod = .egyptian
            $0.snoozeMinutes = 15
        }

        let merged = phone.merging(watch)
        #expect(merged.settings.calculationMethod == .egyptian)
        #expect(merged.settings.snoozeMinutes == 5)
        #expect(merged == watch.merging(phone))
    }

    @Test
    func aRevisedValueReplacesALegacyOne() {
        var legacy = Settings()
        legacy.theme = .web3
        let revised = SettingsDocument().editing(at: Date(timeIntervalSince1970: 1)) { $0.theme = .dawn }

        #expect(SettingsDocument(settings: legacy).merging(revised).settings.theme == .dawn)
        #expect(revised.merging(SettingsDocument(settings: legacy)).settings.theme == .dawn)
    }

    @Test
    func aTieResolvesTheSameWayOnBothSides() {
        let revision = Revision(milliseconds: 42)
        var left = Settings()
        left.duhaReminder = .minutes(10)
        var right = Settings()
        right.duhaReminder = nil

        let leftDocument = SettingsDocument(settings: left, revisions: [.duhaReminder: revision])
        let rightDocument = SettingsDocument(settings: right, revisions: [.duhaReminder: revision])

        #expect(leftDocument.merging(rightDocument) == rightDocument.merging(leftDocument))
    }

    @Test
    func anEchoChangesNothing() {
        let document = SettingsDocument().editing(at: Date(timeIntervalSince1970: 7)) { $0.duhaReminder = nil }

        #expect(document.merging(document) == document)
    }

    @Test
    func mergingIsAssociativeCommutativeAndIdempotent() {
        var generator = SplitMix64(seed: 0x5EED)

        (0..<300).forEach { _ in
            let first = SettingsDocument.random(using: &generator)
            let second = SettingsDocument.random(using: &generator)
            let third = SettingsDocument.random(using: &generator)

            #expect(first.merging(second) == second.merging(first))
            #expect(first.merging(second).merging(third) == first.merging(second.merging(third)))
            #expect(first.merging(first) == first)
        }
    }

    @Test
    func copiesConvergeWhateverOrderTheyArriveIn() {
        var generator = SplitMix64(seed: 0xC0FFEE)

        (0..<100).forEach { _ in
            let copies = (0..<5).map { _ in SettingsDocument.random(using: &generator) }
            let expected = copies.reduce(SettingsDocument()) { $0.merging($1) }

            (0..<5).forEach { _ in
                let shuffled = copies.shuffled(using: &generator)
                #expect(shuffled.reduce(SettingsDocument()) { $0.merging($1) } == expected)
            }
        }
    }
}

// MARK: - Helpers

private extension SettingsDocument {
    /// A document over a few settings with few possible values and revisions, so ties and collisions are common.
    static func random(using generator: inout SplitMix64) -> SettingsDocument {
        var settings = Settings()
        settings.calculationMethod = [.karachi, .egyptian, .turkey].randomElement(using: &generator) ?? .karachi
        settings.snoozeMinutes = [5, 10, 30].randomElement(using: &generator) ?? 5
        settings.isGPSEnabled = Bool.random(using: &generator)
        settings.duhaReminder = [nil, .minutes(10), .time(hour: 8, minutes: 0)].randomElement(using: &generator) ?? nil
        settings.notificationSounds = [
            NotificationSounds(rawValue: ["fajr": .adhan]),
            NotificationSounds(rawValue: ["fajr": .chime, "isha": .off])
        ].randomElement(using: &generator) ?? NotificationSounds(rawValue: [:])

        let keys: [SettingKey] = [.calculationMethod, .snoozeMinutes, .isGPSEnabled, .duhaReminder, .notificationSounds]
        let revisions = keys.reduce(into: [SettingKey: Revision]()) { result, key in
            result[key] = Revision(milliseconds: Int64.random(in: 0...3, using: &generator))
        }

        return SettingsDocument(settings: settings, revisions: revisions)
    }
}

extension SettingsDocumentTests {
    @Test
    func takingOnlyNewerEditsLeavesAnUnrevisedTieAlone() {
        var mine = Settings()
        mine.notificationAdhan[.fajr] = .abdulBasit
        var theirs = Settings()
        theirs.notificationAdhan[.fajr] = .alAqsa

        let merged = SettingsDocument(settings: mine).adoptingNewer(SettingsDocument(settings: theirs))

        #expect(merged.settings.notificationAdhan[.fajr] == .abdulBasit)
    }

    @Test
    func takingOnlyNewerEditsTakesARevisedOne() {
        let edited = SettingsDocument().editing(at: Date(timeIntervalSince1970: 1_800_000_000)) {
            $0.notificationAdhan[.fajr] = .alAqsa
        }

        let merged = SettingsDocument().adoptingNewer(edited)

        #expect(merged.settings.notificationAdhan[.fajr] == .alAqsa)
        #expect(merged.revision(of: .notificationAdhan) == edited.revision(of: .notificationAdhan))
    }
}

