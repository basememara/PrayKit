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

// MARK: - Compatibility with Preferences

extension SettingsStorageTests {
    @Test
    func freshSuiteReadsThePreferencesDefaults() {
        let preferences = Preferences(defaults: defaults)

        #expect(storage.load().document.settings == Settings(preferences: preferences))
        #expect(storage.load().document.settings == Settings())
        #expect(storage.unreadableKeys().isEmpty)
    }

    @Test
    func readsWhatPreferencesWrote() {
        Settings.everyFieldChanged.write(to: Preferences(defaults: defaults))

        let state = storage.load()
        #expect(state.document.settings == .everyFieldChanged)
        #expect(state.document.revisions.isEmpty)
        #expect(storage.unreadableKeys().isEmpty)
    }

    @Test
    func preferencesReadsWhatStorageWrote() {
        storage.edit { $0 = .everyFieldChanged }

        #expect(Settings(preferences: Preferences(defaults: defaults)) == .everyFieldChanged)
    }

    @Test
    func elevationRuleKeepsItsMisspelledKey() {
        storage.edit { $0.elevationRule = .seventhOfTheNight }

        #expect(defaults.string(forKey: "elavationMethod") == ElevationRule.seventhOfTheNight.rawValue)
        #expect(defaults.object(forKey: "elevationRule") == nil)
        #expect(defaults.object(forKey: "elavationMethod_at") != nil)
    }

    @Test
    func clearingAnOptionalRemovesItsKeyAndStampsTheChange() throws {
        let added = storage.edit(at: Date(timeIntervalSince1970: 1_000)) { $0.duhaReminder = .minutes(20) }
        let cleared = storage.edit(at: Date(timeIntervalSince1970: 2_000)) { $0.duhaReminder = nil }

        #expect(defaults.object(forKey: "duhaReminder") == nil)
        #expect(cleared.document.settings.duhaReminder == nil)
        #expect(cleared.document.revision(of: .duhaReminder) > added.document.revision(of: .duhaReminder))
        #expect(Preferences(defaults: defaults).duhaReminder == nil)
    }
}

// MARK: - Unreadable values

extension SettingsStorageTests {
    @Test
    func undecodableValuesAreReportedNotGuessed() {
        defaults.set(Data("not json".utf8), forKey: "iqamaTimes")
        defaults.set("NotAMethod", forKey: "calculationMethod")
        defaults.set(["fajr": "adhan", "isha": "no.such.sound"], forKey: "notificationSounds")

        let settings = storage.load().document.settings
        #expect(Set(storage.unreadableKeys()) == [.iqamaTimes, .calculationMethod, .notificationSounds])
        #expect(settings.iqamaTimes == Settings().iqamaTimes)
        #expect(settings.calculationMethod == Settings().calculationMethod)
        #expect(settings.notificationSounds == NotificationSounds(rawValue: ["fajr": .adhan]))
        #expect(settings.notificationSounds == Preferences(defaults: defaults).notificationSounds)
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

        let stored = try #require(defaults.object(forKey: "theme_at") as? NSNumber)
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

        #expect(Preferences(defaults: defaults).calculationMethod == .karachi)
        #expect(storage.load().document.revision(of: .calculationMethod) == remote.revision(of: .calculationMethod))
    }
}

// MARK: - Place

extension SettingsStorageTests {
    @Test
    func readsThePlacePreferencesWrote() throws {
        let preferences = Preferences(defaults: defaults)
        let coordinates = Coordinates(latitude: 2.9, longitude: 101.6)
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        preferences.set(manualAddress: coordinates, timeZone: timeZone, regionName: "Somewhere")

        let place = try #require(storage.load().place)
        #expect(place.coordinates == coordinates)
        #expect(place.timeZone == timeZone)
        #expect(place.regionName == "Somewhere")
        #expect(place.fixedAt == preferences.lastCacheDate)
    }

    @Test
    func preferencesReadsThePlaceStorageWrote() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let place = Place(
            coordinates: Coordinates(latitude: 51.5, longitude: -0.1),
            timeZone: timeZone,
            regionName: "Elsewhere",
            fixedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        storage.update { DeviceState(document: $0.document, place: place) }

        let preferences = Preferences(defaults: defaults)
        #expect(preferences.prayersCoordinates == place.coordinates)
        #expect(preferences.lastTimeZone == timeZone)
        #expect(preferences.lastRegionName == "Elsewhere")
        #expect(preferences.lastCacheDate == place.fixedAt)
    }

    @Test
    func noCoordinatesMeansNoPlace() {
        #expect(storage.load().place == nil)
    }
}
