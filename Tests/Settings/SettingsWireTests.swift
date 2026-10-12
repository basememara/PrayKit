//
//  SettingsWireTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct SettingsWireTests {
    private let saved = Date(timeIntervalSince1970: 1_700_000_000)
}

// MARK: - Older app versions

extension SettingsWireTests {
    /// JSON doesn't fix the order of a map's keys, so JSON fields are compared by what an older version decodes.
    @Test
    func fieldsMatchWhatOlderVersionsWrite() throws {
        var expected = try Self.legacyRecord(of: .everyFieldChanged)
        expected["adhanDuaa"] = .string(AdhanDuaa.wasilahFadilah.rawValue)
        expected["soundsBeforeMute"] = .data(try JSONEncoder().encode(Settings.everyFieldChanged.soundsBeforeMute))
        let fields = SettingsDocument(settings: .everyFieldChanged).wireFields

        #expect(Set(fields.keys) == Set(expected.keys))
        #expect(fields.filter { !$0.value.isData } == expected.filter { !$0.value.isData })
        #expect(try Self.decode(PreAdhanMinutes.self, fields["preAdhanMinutes"]) == Settings.everyFieldChanged.preAdhanMinutes)
        #expect(try Self.decode(AdjustmentMinutes.self, fields["adjustmentMinutes"]) == Settings.everyFieldChanged.adjustmentMinutes)
        #expect(try Self.decode(IqamaTimes.self, fields["iqamaTimes"]) == Settings.everyFieldChanged.iqamaTimes)
        #expect(try Self.decode(IqamaReminders.self, fields["iqamaReminders"]) == Settings.everyFieldChanged.iqamaReminders)
        #expect(try Self.decode(DuhaType.self, fields["duhaReminder"]) == Settings.everyFieldChanged.duhaReminder)
        #expect(try Self.decode(NotificationAdhan.self, fields["notificationAdhan"]) == Settings.everyFieldChanged.notificationAdhan)
        #expect(try Self.decode(NotificationSounds.self, fields["notificationSounds"]) == Settings.everyFieldChanged.notificationSounds)
        #expect(try Self.decode(NotificationSounds.self, fields["soundsBeforeMute"]) == Settings.everyFieldChanged.soundsBeforeMute)
        #expect(try Self.decode(ReminderSounds.self, fields["reminderSounds"]) == Settings.everyFieldChanged.reminderSounds)
    }

    @Test
    func aRecordFromAnOlderVersionIsStampedWhenItWasSaved() throws {
        let document = SettingsDocument(
            wireFields: try Self.legacyRecord(of: .everyFieldChanged),
            base: Settings(),
            modifiedAt: saved,
            previous: nil
        )

        var expected = Settings.everyFieldChanged
        expected.adhanDuaa = Settings().adhanDuaa
        expected.soundsBeforeMute = Settings().soundsBeforeMute
        expected.geofenceRadius = Settings().geofenceRadius

        #expect(document.settings == expected)
        #expect(Set(document.revisions.values) == [Revision(saved)])
        #expect(document.revision(of: .adhanDuaa) == .legacy)
        #expect(document.revision(of: .soundsBeforeMute) == .legacy)
        #expect(document.revision(of: .geofenceRadius) == .legacy)
    }

    @Test
    func aCopyWithNoRevisionsReadAtTheLegacyTimeStaysUnrevised() throws {
        let document = SettingsDocument(
            wireFields: try Self.legacyRecord(of: .everyFieldChanged),
            base: Settings(),
            modifiedAt: Revision.legacy.date,
            previous: nil
        )

        #expect(SettingKey.allCases.allSatisfy { document.revision(of: $0) == .legacy })
    }

    @Test
    func anOlderVersionsChangeIsDetectedThoughItsRevisionStayed() {
        let previous = Self.revised.wireFields
        var incoming = previous
        incoming["snoozeMinutes"] = .int(45)

        let document = SettingsDocument(wireFields: incoming, base: Settings(), modifiedAt: saved, previous: previous)

        #expect(document.settings.snoozeMinutes == 45)
        #expect(document.revision(of: .snoozeMinutes) > Self.revised.revision(of: .snoozeMinutes))
        #expect(document.revision(of: .theme) == Self.revised.revision(of: .theme))
    }

    @Test
    func aSettingTheRecordNeverCarriedArrivesUnrevised() {
        // An upgraded device uploads a synced setting the record never had; its value is no edit
        var previous = Self.revised.wireFields
        previous["adhanDuaa"] = nil
        previous["adhanDuaaAt"] = nil
        var incoming = previous
        incoming["adhanDuaa"] = .string("off")

        let document = SettingsDocument(wireFields: incoming, base: Settings(), modifiedAt: saved, previous: previous)

        #expect(document.revision(of: .adhanDuaa) == .legacy)
    }

    @Test
    func anOlderVersionsChangeOutranksTheRevisionItReplaced() {
        // A newer device with a fast clock stamped the setting after the moment the older version saved
        let stampedAhead = saved + 30
        var previous = Self.revised.wireFields
        previous["snoozeMinutesAt"] = .int(Revision(stampedAhead).milliseconds)
        var incoming = previous
        incoming["snoozeMinutes"] = .int(45)

        let document = SettingsDocument(wireFields: incoming, base: Settings(), modifiedAt: saved, previous: previous)

        #expect(document.settings.snoozeMinutes == 45)
        #expect(document.revision(of: .snoozeMinutes) > Revision(stampedAhead))
    }

    @Test
    func anOlderVersionTurningDuhaOffRemovesTheField() {
        let previous = Self.revised.wireFields
        var incoming = previous
        incoming["duhaReminder"] = nil

        let document = SettingsDocument(wireFields: incoming, base: Settings(), modifiedAt: saved, previous: previous)

        #expect(document.settings.duhaReminder == nil)
        #expect(document.revision(of: .duhaReminder) > Self.revised.revision(of: .duhaReminder))
    }

    @Test
    func reencodingAnUnchangedMapIsNotAChange() throws {
        let previous = Self.revised.wireFields
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        var incoming = previous
        incoming["notificationSounds"] = .data(try encoder.encode(Settings.everyFieldChanged.notificationSounds))
        #expect(incoming["notificationSounds"] != previous["notificationSounds"])

        let document = SettingsDocument(wireFields: incoming, base: Settings(), modifiedAt: saved, previous: previous)

        #expect(document.revision(of: .notificationSounds) == Self.revised.revision(of: .notificationSounds))
    }

    @Test
    func reSavingTheSameSettingsGivesTheSameBytes() {
        var rebuilt = Self.revised.settings
        rebuilt.notificationSounds = NotificationSounds(rawValue: ["maghrib": .silent, "fajr": .chimes])
        rebuilt.preAdhanMinutes = PreAdhanMinutes(rawValue: ["dhuhr": 5, "fajr": 30])
        #expect(rebuilt == Self.revised.settings)

        #expect(SettingsDocument(settings: rebuilt, revisions: Self.revised.revisions).wireFields == Self.revised.wireFields)
    }

    @Test
    func anUnchangedFieldWithoutARevisionStaysLegacy() throws {
        let record = try Self.legacyRecord(of: .everyFieldChanged)
        var incoming = record
        incoming["theme"] = .string(AppTheme.dawn.rawValue)

        let document = SettingsDocument(wireFields: incoming, base: Settings(), modifiedAt: saved, previous: record)

        #expect(document.revision(of: .theme) == Revision(saved))
        #expect(document.revision(of: .snoozeMinutes) == .legacy)
    }
}

// MARK: - Round trip

extension SettingsWireTests {
    @Test
    func revisedSettingsRoundTrip() {
        let document = SettingsDocument(wireFields: Self.revised.wireFields, base: Settings(), modifiedAt: saved, previous: nil)

        var expected = Settings.everyFieldChanged
        expected.geofenceRadius = Settings().geofenceRadius

        #expect(document.settings == expected)
        #expect(document.revisions == Self.revised.revisions.filter { $0.key.isSynced })
    }

    @Test
    func aDeviceSettingNeverGoesOnTheWire() {
        let fields = Self.revised.wireFields

        #expect(fields["geofenceRadius"] == nil)
        #expect(fields["geofenceRadiusAt"] == nil)
    }

    @Test
    func anUndecodableFieldKeepsThisDevicesValueUnderTheCopysRevision() {
        var base = Settings()
        base.iqamaTimes = Settings.everyFieldChanged.iqamaTimes
        var incoming = Self.revised.wireFields
        incoming["iqamaTimes"] = .data(Data("not json".utf8))

        let document = SettingsDocument(wireFields: incoming, base: base, modifiedAt: saved, previous: nil)

        #expect(document.settings.iqamaTimes == base.iqamaTimes)
        #expect(document.revision(of: .iqamaTimes) == Self.revised.revision(of: .iqamaTimes))
    }

    @Test
    func aValueOnlyANewerVersionCanReadLeavesNeitherDeviceBehind() {
        var incoming = Self.revised.wireFields
        incoming["iqamaTimes"] = .data(Data("a newer version's value".utf8))

        let older = SettingsDocument(settings: Settings(), revisions: [:])
        let server = SettingsDocument(wireFields: incoming, base: older.settings, modifiedAt: saved, previous: nil)
        let merged = older.merging(server)
        let serverAgain = SettingsDocument(wireFields: incoming, base: merged.settings, modifiedAt: saved, previous: incoming)

        #expect(!merged.hasNewerRevisions(than: serverAgain))
    }

    @Test
    func aMissingSettingKeepsThisDevicesValue() {
        var base = Settings()
        base.adhanDuaa = .wasilahFadilah
        var incoming = Self.revised.wireFields
        incoming["adhanDuaa"] = nil
        incoming["adhanDuaaAt"] = nil

        let document = SettingsDocument(wireFields: incoming, base: base, modifiedAt: saved, previous: nil)

        #expect(document.settings.adhanDuaa == .wasilahFadilah)
        #expect(document.revision(of: .adhanDuaa) == .legacy)
    }
}

// MARK: - Foundation objects

extension SettingsWireTests {
    @Test
    func valuesSurviveTheTripThroughFoundationObjects() {
        let values: [WireValue] = [.int(-3), .int(1_800_000_000_123), .double(18.5), .double(4), .string("Turkey"), .data(Data([1, 2, 3]))]

        #expect(values.map { WireValue(object: $0.object) } == values)
    }

    @Test
    func aFlagSavedAsABoolReadsAsAnInteger() {
        #expect(WireValue(object: NSNumber(value: true)) == .int(1))
        #expect(WireValue(object: Date()) == nil)
    }
}

// MARK: - Following another device

extension SettingsWireTests {
    @Test
    func aFollowerAdoptsUnrevisedValues() {
        var phone = Settings()
        phone.snoozeMinutes = 10
        var watch = Settings()
        watch.snoozeMinutes = 45

        let adopted = SettingsDocument(settings: watch).adopting(SettingsDocument(settings: phone))

        #expect(adopted.settings.snoozeMinutes == 10)
    }

    @Test
    func aFollowerKeepsItsOwnNewerEdit() {
        var phone = Settings()
        phone.snoozeMinutes = 10
        let watch = SettingsDocument().editing(at: Date(timeIntervalSince1970: 5)) { $0.snoozeMinutes = 45 }

        #expect(watch.adopting(SettingsDocument(settings: phone)).settings.snoozeMinutes == 45)
    }

    @Test
    func aFollowerTakesANewerRevisionFromItsLeader() {
        let watch = SettingsDocument().editing(at: Date(timeIntervalSince1970: 5)) { $0.snoozeMinutes = 45 }
        let phone = SettingsDocument().editing(at: Date(timeIntervalSince1970: 9)) { $0.snoozeMinutes = 10 }

        #expect(watch.adopting(phone) == watch.merging(phone))
        #expect(watch.adopting(phone).settings.snoozeMinutes == 10)
    }
}

// MARK: - Comparing

extension SettingsWireTests {
    @Test
    func aNewerRevisionMeansTheOtherCopyIsBehind() {
        let server = Self.revised
        let local = server.editing(at: Date(timeIntervalSince1970: 1_900_000_000)) { $0.snoozeMinutes = 50 }

        #expect(local.hasNewerRevisions(than: server))
        #expect(!server.hasNewerRevisions(than: local))
        #expect(!local.hasNewerRevisions(than: local))
        #expect(local.keysNewer(than: server) == [.snoozeMinutes])
    }

    /// Two devices that edit a setting in the same millisecond tie: the copy whose value wins the merge uploads
    /// it, so iCloud carries the winner and every device converges.
    @Test
    func anEqualRevisionUploadsFromTheCopyWhoseValueWins() {
        let date = Date(timeIntervalSince1970: 1_900_000_000)
        let ten = SettingsDocument().editing(at: date) { $0.snoozeMinutes = 10 }
        let twenty = SettingsDocument().editing(at: date) { $0.snoozeMinutes = 20 }
        let (winning, losing) = ten.merging(twenty).settings.snoozeMinutes == 20 ? (twenty, ten) : (ten, twenty)

        #expect(ten.revision(of: .snoozeMinutes) == twenty.revision(of: .snoozeMinutes))
        #expect(winning.keysNewer(than: losing) == [.snoozeMinutes])
        #expect(losing.keysNewer(than: winning).isEmpty)
        #expect(losing.merging(winning).keysNewer(than: winning).isEmpty)
    }

    /// An offline edit older than the record's last save still uploads, which needs the saved copy compared
    /// by its own revisions rather than re-dated at its save time.
    @Test
    func aCopyReadAgainstItselfCarriesOnlyItsOwnRevisions() throws {
        let fields = try Self.legacyRecord(of: .everyFieldChanged)
        let server = SettingsDocument(wireFields: fields, base: Settings(), modifiedAt: saved, previous: fields)
        let local = SettingsDocument().editing(at: saved - 60) { $0.snoozeMinutes = 50 }

        #expect(SettingKey.allCases.allSatisfy { server.revision(of: $0) == .legacy })
        #expect(local.keysNewer(than: server) == [.snoozeMinutes])
    }

    @Test
    func aDeviceSettingNeverMakesTheServerBehind() {
        let server = SettingsDocument()
        let local = server.editing(at: Date(timeIntervalSince1970: 10)) { $0.geofenceRadius = 1_000 }

        #expect(!local.hasNewerRevisions(than: server))
    }

    @Test
    func restampingKeepsValuesAndOutranksEverySeenRevision() {
        let document = Self.revised.restamping([.theme, .snoozeMinutes], at: Date(timeIntervalSince1970: 1))

        #expect(document.settings == Self.revised.settings)
        #expect(document.revision(of: .theme) > (Self.revised.revisions.values.max() ?? .legacy))
        #expect(document.revision(of: .theme) == document.revision(of: .snoozeMinutes))
    }
}

// MARK: - Helpers

private extension WireValue {
    var isData: Bool {
        guard case .data = self else { return false }
        return true
    }
}

private extension SettingsWireTests {
    static let revised = SettingsDocument().editing(at: Date(timeIntervalSince1970: 1_800_000_000)) { $0 = .everyFieldChanged }

    /// Decodes a JSON field the way an older app version does.
    static func decode<T: Decodable>(_ type: T.Type, _ field: WireValue?) throws -> T {
        guard case let .data(data) = field else { throw CocoaError(.coderValueNotFound) }
        return try JSONDecoder().decode(type, from: data)
    }

    /// The fields an older app version saves, read back from CloudKit: flags as numbers, maps as JSON.
    static func legacyRecord(of settings: Settings) throws -> [String: WireValue] {
        let encoder = JSONEncoder()
        var fields: [String: WireValue] = [
            "calculationMethod": .string(settings.calculationMethod.rawValue),
            "juristicMethod": .string(settings.juristicMethod.rawValue),
            "fajrDegrees": .double(settings.fajrDegrees),
            "maghribDegrees": .double(settings.maghribDegrees),
            "ishaDegrees": .double(settings.ishaDegrees),
            "isGPSEnabled": .int(settings.isGPSEnabled ? 1 : 0),
            "isIqamaTimerEnabled": .int(settings.isIqamaTimerEnabled ? 1 : 0),
            "isIqamaHidden": .int(settings.isIqamaHidden ? 1 : 0),
            "enable24hTimeFormat": .int(settings.enable24hTimeFormat ? 1 : 0),
            "hijriDayOffset": .int(Int64(settings.hijriDayOffset)),
            "autoIncrementHijri": .int(settings.autoIncrementHijri ? 1 : 0),
            "stopwatchMinutes": .int(Int64(settings.stopwatchMinutes)),
            "snoozeMinutes": .int(Int64(settings.snoozeMinutes)),
            "preAdhanMinutes": .data(try encoder.encode(settings.preAdhanMinutes)),
            "iqamaTimes": .data(try encoder.encode(settings.iqamaTimes)),
            "iqamaReminders": .data(try encoder.encode(settings.iqamaReminders)),
            "notificationAdhan": .data(try encoder.encode(settings.notificationAdhan)),
            "notificationSounds": .data(try encoder.encode(settings.notificationSounds)),
            "reminderSounds": .data(try encoder.encode(settings.reminderSounds)),
            "isPlayOnTapEnabled": .int(settings.isPlayOnTapEnabled ? 1 : 0),
            "isPrayerAbbrEnabled": .int(settings.isPrayerAbbrEnabled ? 1 : 0),
            "sunriseAfterIsha": .int(settings.sunriseAfterIsha ? 1 : 0),
            "appearanceMode": .string(settings.appearanceMode.rawValue),
            "theme": .string(settings.theme.rawValue)
        ]

        fields["elavationMethod"] = settings.elevationRule.map { .string($0.rawValue) }
        fields["adjustmentMinutes"] = try settings.adjustmentMinutes.map { .data(try encoder.encode($0)) }
        fields["adjustmentElevation"] = settings.adjustmentElevation.map { .string($0.rawValue) }
        fields["duhaReminder"] = try settings.duhaReminder.map { .data(try encoder.encode($0)) }
        return fields
    }
}
