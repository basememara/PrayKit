//
//  LocationRuleTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import CoreLocation.CLLocation
import Foundation
import PrayCore
import Testing

struct LocationRuleTests {
    private let toronto = Coordinates(latitude: 43.6510, longitude: -79.3470)
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func theFirstFixSavesThePlaceAndKeepsTheMethod() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        var settings = Settings()
        settings.calculationMethod = .jakim
        let state = DeviceState(document: SettingsDocument(settings: settings))

        let saved = try #require(LocationRule.apply(toronto, timeZone: timeZone, at: date, to: state))

        #expect(saved.place == Place(coordinates: toronto, timeZone: timeZone, regionName: nil, fixedAt: date))
        #expect(saved.document.settings.calculationMethod == .jakim)
    }

    @Test
    func jitterUnderAKilometreIsIgnored() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let state = DeviceState(place: Place(coordinates: toronto, timeZone: timeZone, regionName: "Toronto", fixedAt: date))

        // About 220 m north
        let nearby = Coordinates(latitude: 43.6530, longitude: -79.3470)
        #expect(LocationRule.apply(nearby, timeZone: timeZone, at: date + 60, to: state) == nil)

        // About 2 km north
        let away = Coordinates(latitude: 43.6700, longitude: -79.3470)
        let moved = try #require(LocationRule.apply(away, timeZone: timeZone, at: date + 60, to: state))
        #expect(moved.place?.coordinates == away)
        #expect(moved.place?.fixedAt == date + 60)
    }

    @Test
    func jitterAcrossATimeZoneBoundarySwitchesToTheRecommendedMethod() throws {
        let saved = try #require(TimeZone(identifier: "Pacific/Chatham"))
        let current = try #require(TimeZone(identifier: "Asia/Riyadh"))
        var settings = Settings()
        settings.calculationMethod = .northAmerica
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            place: Place(coordinates: toronto, timeZone: saved, regionName: "Toronto", fixedAt: date)
        )

        let nearby = Coordinates(latitude: 43.6530, longitude: -79.3470)
        let updated = try #require(LocationRule.apply(nearby, timeZone: current, at: date + 60, to: state))

        #expect(updated.place?.timeZone == current)
        #expect(updated.document.settings.calculationMethod == CalculationMethod.recommended(for: current) ?? .moonsightingCommittee)
        #expect(updated.document.revision(of: .calculationMethod) > state.document.revision(of: .calculationMethod))
    }

    @Test(arguments: [CalculationMethod.moonsightingCommittee, .muslimWorldLeague])
    func universalMethodsSurviveATimeZoneChange(method: CalculationMethod) throws {
        let saved = try #require(TimeZone(identifier: "America/Toronto"))
        let current = try #require(TimeZone(identifier: "Asia/Riyadh"))
        var settings = Settings()
        settings.calculationMethod = method
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            place: Place(coordinates: toronto, timeZone: saved, regionName: "Toronto", fixedAt: date)
        )

        let updated = try #require(LocationRule.apply(toronto, timeZone: current, at: date, to: state))

        #expect(updated.document.settings.calculationMethod == method)
    }

    @Test
    func aManualPlaceIsNeverOverwritten() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        var settings = Settings()
        settings.isGPSEnabled = false
        let state = DeviceState(document: SettingsDocument(settings: settings))

        #expect(LocationRule.apply(toronto, timeZone: timeZone, at: date, to: state) == nil)
    }

    @Test
    func aPlaceWithoutANameOrFixTimeIsRefreshed() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let unnamed = DeviceState(place: Place(coordinates: toronto, timeZone: timeZone, regionName: nil, fixedAt: date))
        let unfixed = DeviceState(place: Place(coordinates: toronto, timeZone: timeZone, regionName: "Toronto", fixedAt: nil))

        #expect(LocationRule.apply(toronto, timeZone: timeZone, at: date, to: unnamed) != nil)
        #expect(LocationRule.apply(toronto, timeZone: timeZone, at: date, to: unfixed) != nil)
    }
}

// MARK: - Storage

extension LocationRuleTests {
    @Test
    func savingAFixReportsWhetherTheRuleKeptIt() {
        let storage = SettingsStorage(defaults: .makeTest())
        storage.saveRegionName("Toronto", for: toronto)

        #expect(storage.saveLocation(CLLocation(latitude: 43.6510, longitude: -79.3470)))
        storage.saveRegionName("Toronto", for: toronto)
        #expect(!storage.saveLocation(CLLocation(latitude: 43.6530, longitude: -79.3470)))
    }

    @Test
    func theRegionNameLandsOnlyOnTheFixItWasLookedUpFor() throws {
        let storage = SettingsStorage(defaults: .makeTest())
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let away = Coordinates(latitude: 43.6700, longitude: -79.3470)

        storage.saveLocation(toronto, timeZone: timeZone, at: date)
        storage.saveRegionName("Toronto", for: toronto)
        #expect(storage.load().place?.regionName == "Toronto")

        storage.saveLocation(away, timeZone: timeZone, at: date + 60)
        storage.saveRegionName("Somewhere stale", for: toronto)
        #expect(storage.load().place?.regionName == "Toronto")
        #expect(storage.load().place?.coordinates == away)
    }
}
