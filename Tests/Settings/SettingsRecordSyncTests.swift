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
        var phone = SettingsDocument().editing(at: start) {
            $0.theme = .aqua
            $0.calculationMethod = .muslimWorldLeague
        }
        var record = Record.firstSave(of: phone, at: start + 1)

        var mac = Device(document: SettingsDocument())
        mac.receive(record)
        record = record.saving(mac.document, at: start + 2)
        mac.saw(record)

        var phoneDevice = Device(document: phone, lastRecord: Record.firstSave(of: phone, at: start + 1))
        phoneDevice.receive(record)
        #expect(phoneDevice.keysToSend(over: record) == [])

        mac.edit(at: start + 10) { $0.duhaReminder = .minutes(20) }
        record = record.saving(mac.document, at: start + 11)
        mac.saw(record)

        phoneDevice.receive(record)
        #expect(phoneDevice.document.settings.duhaReminder == .minutes(20))
        #expect(phoneDevice.keysToSend(over: record) == [])
        #expect(mac.keysToSend(over: record) == [])

        phone = phoneDevice.document
        #expect(phone.settings.theme == .aqua)
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

        document = document.merging(remote)
        lastRecord = record
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
