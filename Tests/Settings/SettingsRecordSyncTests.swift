//
//  SettingsRecordSyncTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-25.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

/// Two devices syncing through one record the way the app's iCloud sync does: an upload carries the settings
/// this copy revised past the record, a download merges the record over the copy, and each keeps the record it
/// last saw to read the next one against.
struct SettingsRecordSyncTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func aDeviceThatTookTheRecordHasNothingToSendBack() throws {
        let phone = SettingsDocument().editing(at: start) {
            $0.theme = .aqua
            $0.calculationMethod = .muslimWorldLeague
        }
        let firstSave = Record.firstSave(of: phone, at: start + 1)
        var record = firstSave

        var mac = Device(document: SettingsDocument())
        mac.receive(record)
        record = record.saving(mac.document, at: start + 2)
        mac.saw(record)

        var phoneDevice = Device(document: phone, lastRecord: firstSave)
        phoneDevice.receive(record)
        #expect(phoneDevice.keysToSend(over: record).isEmpty)

        mac.edit(at: start + 10) { $0.duhaReminder = .minutes(20) }
        record = record.saving(mac.document, at: start + 11)
        mac.saw(record)

        phoneDevice.receive(record)
        #expect(phoneDevice.document.settings.duhaReminder == .minutes(20))
        #expect(phoneDevice.keysToSend(over: record).isEmpty)
        #expect(mac.keysToSend(over: record).isEmpty)
        #expect(phoneDevice.document.settings.theme == .aqua)
    }

    /// The Pray Watch Mac on 2026-11-18: back after weeks away, it held another reminder sound than the record under
    /// the same revision, won the tie and saved its value, and the phone and watch each sent it back again. A tied
    /// device now takes the record's value and sends nothing, for any value either side holds.
    @Test(arguments: [NotificationSound.chime, .tone, .xylophone, .alert])
    func aDeviceTiedWithTheRecordTakesItsValueAndSendsNothing(macSound: NotificationSound) {
        let phone = SettingsDocument().editing(at: start) { $0.reminderSounds[.fajr] = .beep }
        let record = Record.firstSave(of: phone, at: start + 1)

        var settings = phone.settings
        settings.reminderSounds[.fajr] = macSound
        var mac = Device(document: SettingsDocument(settings: settings, revisions: phone.revisions), lastRecord: record)

        #expect(mac.keysToSend(over: record).isEmpty)

        var waiting = mac
        waiting.settleTies(with: record)
        #expect(waiting.document.settings.reminderSounds[.fajr] == .beep)
        #expect(waiting.keysToSend(over: record).isEmpty)

        mac.receive(record)
        #expect(mac.document.settings.reminderSounds[.fajr] == .beep)
        #expect(mac.document.revision(of: .reminderSounds) == phone.revision(of: .reminderSounds))
        #expect(mac.keysToSend(over: record).isEmpty)
    }
}

// MARK: - Helpers

private struct Record {
    var fields: [String: WireValue]
    var modifiedAt: Date

    static func firstSave(of document: SettingsDocument, at date: Date) -> Record {
        Record(fields: document.wireFields, modifiedAt: date)
    }

    /// The record after `document` saves the settings it revised past it, as the upload sends them.
    func saving(_ document: SettingsDocument, at date: Date) -> Record {
        let server = SettingsDocument(wireFields: fields, base: document.settings, modifiedAt: modifiedAt, previous: fields)
        let wire = document.wireFields
        let saved = document.keysNewer(than: server).reduce(into: fields) { fields, key in
            fields[key.rawValue] = wire[key.rawValue]
            fields[key.revisionKey] = wire[key.revisionKey]
        }

        return Record(fields: saved, modifiedAt: date)
    }
}

private struct Device {
    var document: SettingsDocument
    var lastRecord: Record?

    mutating func receive(_ record: Record) {
        let remote = SettingsDocument(
            wireFields: record.fields,
            base: document.settings,
            modifiedAt: record.modifiedAt,
            previous: lastRecord?.fields
        )

        document = document.merging(record: remote)
        lastRecord = record
    }

    /// What every reconcile does with the last record seen, without a new one arriving.
    mutating func settleTies(with record: Record) {
        let server = SettingsDocument(wireFields: record.fields, base: document.settings, modifiedAt: record.modifiedAt, previous: record.fields)
        document = document.adoptingTies(from: server)
    }

    mutating func saw(_ record: Record) {
        lastRecord = record
    }

    mutating func edit(at date: Date, _ change: (inout Settings) -> Void) {
        document = document.editing(at: date, change)
    }

    func keysToSend(over record: Record) -> [SettingKey] {
        let server = SettingsDocument(wireFields: record.fields, base: document.settings, modifiedAt: record.modifiedAt, previous: record.fields)
        return document.keysNewer(than: server)
    }
}
