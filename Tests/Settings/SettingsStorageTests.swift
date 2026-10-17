//
//  SettingsStorageTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct SettingsStorageTests {
    private let defaults = UserDefaults.makeTest()
    private var storage: SettingsStorage { SettingsStorage(defaults: defaults) }
}

// MARK: - On-disk format

extension SettingsStorageTests {
    @Test
    func freshSuiteReadsTheDefaults() {
        let state = storage.load()

        #expect(state.document.settings == Settings())
        #expect(state.place == nil)
    }

    @Test
    func readsWhatEarlierVersionsWrote() throws {
        let expectedPlace = try Self.goldenPlace()
        Self.golden.forEach { defaults.set($0.value, forKey: $0.key) }

        let state = storage.load()
        #expect(state.document.settings == .everyFieldChanged)
        #expect(state.document.revisions.isEmpty)
        #expect(state.place == expectedPlace)
    }

    @Test
    func writesWhatEarlierVersionsRead() throws {
        let place = try Self.goldenPlace()
        storage.update { DeviceState(document: $0.document.editing(at: .now) { $0 = .everyFieldChanged }, place: place) }

        for (key, expected) in Self.golden {
            try expectStored(key, equals: expected)
        }
    }

    @Test
    func elevationRuleKeepsItsMisspelledKey() {
        storage.edit { $0.elevationRule = .seventhOfTheNight }

        #expect(defaults.string(forKey: "elavationMethod") == ElevationRule.seventhOfTheNight.rawValue)
        #expect(defaults.object(forKey: "elevationRule") == nil)
        #expect(defaults.object(forKey: "elavationMethodAt") != nil)
    }

    @Test
    func clearingAnOptionalRemovesItsKeyAndStampsTheChange() throws {
        let added = storage.edit(at: Date(timeIntervalSince1970: 1_000)) { $0.duhaReminder = .minutes(20) }
        let cleared = storage.edit(at: Date(timeIntervalSince1970: 2_000)) { $0.duhaReminder = nil }

        #expect(defaults.object(forKey: "duhaReminder") == nil)
        #expect(cleared.document.settings.duhaReminder == nil)
        #expect(cleared.document.revision(of: .duhaReminder) > added.document.revision(of: .duhaReminder))
    }
}

// MARK: - Unreadable values

extension SettingsStorageTests {
    @Test
    func undecodableValuesKeepTheirDefaultsNotAGuess() {
        defaults.set(Data("not json".utf8), forKey: "iqamaTimes")
        defaults.set("NotAMethod", forKey: "calculationMethod")
        defaults.set(["fajr": "adhan", "isha": "no.such.sound"], forKey: "notificationSounds")

        let settings = storage.load().document.settings
        #expect(settings.iqamaTimes == Settings().iqamaTimes)
        #expect(settings.calculationMethod == Settings().calculationMethod)
        #expect(settings.notificationSounds == NotificationSounds(rawValue: ["fajr": .adhan]))
    }

    @Test
    func anUnrelatedEditLeavesUndecodableBytesInPlace() {
        let garbage = Data("not json".utf8)
        defaults.set(garbage, forKey: "iqamaTimes")

        storage.edit { $0.snoozeMinutes = 5 }

        #expect(defaults.data(forKey: "iqamaTimes") == garbage)
        #expect(defaults.integer(forKey: "snoozeMinutes") == 5)
    }
}

// MARK: - Revisions

extension SettingsStorageTests {
    @Test
    func revisionsAreStoredAsWholeMilliseconds() throws {
        storage.edit(at: Date(timeIntervalSince1970: 1_760_000_000.123_9)) { $0.theme = .dawn }

        let stored = try #require(defaults.object(forKey: "themeAt") as? NSNumber)
        #expect(stored.int64Value == 1_760_000_000_123)
        #expect(storage.load().document.revision(of: .theme) == Revision(milliseconds: 1_760_000_000_123))
    }

    @Test
    func anEditStampsOnlyTheSettingsItChanged() {
        storage.edit { $0.snoozeMinutes = 5 }
        storage.edit {
            $0.snoozeMinutes = 5
            $0.theme = .calm
        }

        let revisions = storage.load().document.revisions
        #expect(Set(revisions.keys) == [.snoozeMinutes, .theme])
        #expect(revisions[.theme, default: .legacy] > revisions[.snoozeMinutes, default: .legacy])
    }

    @Test
    func mergingARemoteCopyWritesItsValuesAndRevisions() {
        let remote = SettingsDocument().editing(at: Date(timeIntervalSince1970: 5_000)) { $0.calculationMethod = .karachi }

        storage.update { DeviceState(document: $0.document.merging(remote), place: $0.place) }

        #expect(storage.load().document.settings.calculationMethod == .karachi)
        #expect(defaults.string(forKey: "calculationMethod") == CalculationMethod.karachi.rawValue)
        #expect(storage.load().document.revision(of: .calculationMethod) == remote.revision(of: .calculationMethod))
    }
}

// MARK: - Place

extension SettingsStorageTests {
    @Test
    func readsThePlaceFromItsKeys() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let fixedAt = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set([2.9, 101.6], forKey: "prayersCoordinates")
        defaults.set("Asia/Kuala_Lumpur", forKey: "lastTimeZoneIdentifier")
        defaults.set("Somewhere", forKey: "lastRegionName")
        defaults.set(fixedAt, forKey: "lastCacheDate")

        let place = try #require(storage.load().place)
        #expect(place.coordinates == Coordinates(latitude: 2.9, longitude: 101.6))
        #expect(place.timeZone == timeZone)
        #expect(place.regionName == "Somewhere")
        #expect(place.fixedAt == fixedAt)
    }

    @Test
    func writesThePlaceToItsKeys() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let place = Place(
            coordinates: Coordinates(latitude: 51.5, longitude: -0.1),
            timeZone: timeZone,
            regionName: "Elsewhere",
            fixedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        storage.update { DeviceState(document: $0.document, place: place) }

        #expect(defaults.array(forKey: "prayersCoordinates") as? [Double] == [51.5, -0.1])
        #expect(defaults.string(forKey: "lastTimeZoneIdentifier") == "Europe/London")
        #expect(defaults.string(forKey: "lastRegionName") == "Elsewhere")
        #expect(defaults.object(forKey: "lastCacheDate") as? Date == place.fixedAt)
    }

    @Test
    func noCoordinatesMeansNoPlace() {
        #expect(storage.load().place == nil)
    }
}

// MARK: - Concurrency

extension SettingsStorageTests {
    @Test
    func concurrentEditsInOneProcessAreNeverLost() async {
        let storage = storage

        await withTaskGroup { group in
            (0..<200).forEach { _ in
                group.addTask { storage.edit { $0.hijriDayOffset += 1 } }
            }
        }

        #expect(storage.load().document.settings.hijriDayOffset == 200)
    }

    @Test
    func aReadNeverPairsAValueWithAnotherValuesRevision() throws {
        let defaults = try #require(InterleavingDefaults(suiteName: UUID().uuidString))
        let storage = SettingsStorage(defaults: defaults)
        let writing = DispatchGroup()
        storage.edit { $0.snoozeMinutes = 10 }

        // Between reading the value and its revision, another thread saves a new value with a new revision
        defaults.afterReading(SettingKey.snoozeMinutes.rawValue) {
            writing.enter()
            Thread {
                storage.edit { $0.snoozeMinutes = 20 }
                writing.leave()
            }.start()
            _ = writing.wait(timeout: .now() + 0.2)
        }

        let read = storage.load().document
        writing.wait()
        let stored = storage.load().document

        #expect(read.revision(of: .snoozeMinutes) != stored.revision(of: .snoozeMinutes) || read.settings.snoozeMinutes == 20)
    }
}

// MARK: - Helpers

private extension SettingsStorageTests {
    func expectStored(_ key: String, equals expected: Any) throws {
        let stored: Any? = defaults.object(forKey: key)
        let matches = try Self.isEqual(stored, expected)
        #expect(matches, "\(key) is \(String(describing: stored))")
    }

    /// Compares JSON by its decoded objects, since the order of keys in encoded JSON is not stable.
    static func isEqual(_ stored: Any?, _ expected: Any) throws -> Bool {
        guard let stored else { return false }

        guard let expectedData = expected as? Data else {
            return (stored as AnyObject).isEqual(expected)
        }

        guard let storedData = stored as? Data else { return false }
        let storedJSON = try JSONSerialization.jsonObject(with: storedData) as AnyObject
        let expectedJSON = try JSONSerialization.jsonObject(with: expectedData) as AnyObject
        return storedJSON.isEqual(expectedJSON)
    }

    static var golden: [String: Any] {
        [
            "adhanDuaa": "wasilah.fadilah",
            "adjustmentElevation": "AngleBased",
            "adjustmentMinutes": ["fajr": 2, "is_fajr_sunrise_relative": 1, "isha": -3],
            "appearanceMode": "light",
            "autoIncrementHijri": false,
            "calculationMethod": "Turkey",
            "duhaReminder": Data(#"{"time":{"hour":8,"minutes":15}}"#.utf8),
            "elavationMethod": "OneSeventh",
            "enable24hTimeFormat": true,
            "fajrDegrees": 18.5,
            "geofenceRadius": 20_000.0,
            "hijriDayOffset": -1,
            "iqamaReminders": Data(#"{"minutes":10,"sound":"chime","jumuahMinutes":30,"updateInterval":"weekly"}"#.utf8),
            "iqamaTimes": Data(
                #"{"jumuah":{"time":{"minutes":0,"hour":13}},"maghrib":{"minutes":{"_0":5}},"fajr":{"minutes":{"_0":20}},"dhuhr":{"time":{"minutes":30,"hour":13}}}"#.utf8
            ),
            "isGPSEnabled": false,
            "isIqamaHidden": true,
            "isIqamaTimerEnabled": false,
            "isPlayOnTapEnabled": false,
            "isPrayerAbbrEnabled": true,
            "ishaDegrees": 17.0,
            "juristicMethod": "Hanafi",
            "lastCacheDate": Date(timeIntervalSince1970: 1_700_000_000),
            "lastRegionName": "Somewhere",
            "lastTimeZoneIdentifier": "Asia/Kuala_Lumpur",
            "maghribDegrees": 4.0,
            "notificationAdhan": ["fajr": "abdul.basit", "isha": "ahmad.al.batal"],
            "notificationSounds": ["fajr": "chimes", "maghrib": "silent"],
            "prayersCoordinates": [2.9, 101.6],
            "preAdhanMinutes": ["dhuhr": 5, "fajr": 30],
            "reminderSounds": ["asr": "beep", "isha": "off"],
            "snoozeMinutes": 10,
            "soundsBeforeMute": ["maghrib": "beep"],
            "stopwatchMinutes": 15,
            "sunriseAfterIsha": true,
            "theme": "aqua"
        ]
    }

    static func goldenPlace() throws -> Place {
        Place(
            coordinates: Coordinates(latitude: 2.9, longitude: 101.6),
            timeZone: try #require(TimeZone(identifier: "Asia/Kuala_Lumpur")),
            regionName: "Somewhere",
            fixedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

/// Runs a step once, right after a key is read, to land a write between two reads.
private final class InterleavingDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: (key: String, step: () -> Void)?

    func afterReading(_ key: String, _ step: @escaping () -> Void) {
        lock.withLock { pending = (key, step) }
    }

    override func object(forKey defaultName: String) -> Any? {
        let value = super.object(forKey: defaultName)
        let step = lock.withLock {
            guard let pending, pending.key == defaultName else { return nil as (() -> Void)? }
            self.pending = nil
            return pending.step
        }
        step?()
        return value
    }
}
