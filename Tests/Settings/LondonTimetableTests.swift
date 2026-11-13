//
//  LondonTimetableTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
@testable import PrayCore
import Testing

/// London's timetable holds only near London, so the rest of `Europe/London` is recommended the Moonsighting
/// Committee's method, and a move across that line re-recommends as a time-zone change does.
struct LondonTimetableTests {
    private let london = Coordinates(latitude: 51.5074, longitude: -0.1278)
    private let thirtyKilometresNorth = Coordinates(latitude: 51.7772, longitude: -0.1278)
    private let seventyKilometresNorth = Coordinates(latitude: 52.1369, longitude: -0.1278)
    private let luton = Coordinates(latitude: 51.8787, longitude: -0.4200)
    private let manchester = Coordinates(latitude: 53.4808, longitude: -2.2426)
    private let edinburgh = Coordinates(latitude: 55.9533, longitude: -3.1883)
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
}

extension LondonTimetableTests {
    @Test
    func theTimetableIsRecommendedOnlyNearLondon() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))

        #expect(CalculationMethod.recommended(for: timeZone, at: london) == .london)
        #expect(CalculationMethod.recommended(for: timeZone, at: thirtyKilometresNorth) == .london)
        #expect(CalculationMethod.recommended(for: timeZone, at: luton) == .london)
        #expect(CalculationMethod.recommended(for: timeZone, at: seventyKilometresNorth) == .moonsightingCommittee)
        #expect(CalculationMethod.recommended(for: timeZone, at: manchester) == .moonsightingCommittee)
        #expect(CalculationMethod.recommended(for: timeZone, at: edinburgh) == .moonsightingCommittee)
    }

    @Test
    func withoutAPlaceTheZoneDecides() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        #expect(CalculationMethod.recommended(for: timeZone, at: nil) == .london)
    }

    @Test
    func anotherZoneIgnoresTheLondonRadius() throws {
        let paris = try #require(TimeZone(identifier: "Europe/Paris"))
        #expect(CalculationMethod.recommended(for: paris, at: london) == .muslimWorldLeague)
    }
}

// MARK: - Moving

extension LondonTimetableTests {
    @Test
    func aFollowedTimetableSwitchesOnLeavingLondonAndBackOnReturning() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var settings = Settings()
        settings.recommendMethod(at: .zone(timeZone, at: london))
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            ownPlace: Place(coordinates: london, timeZone: timeZone, regionName: "London", fixedAt: date)
        )

        let away = try #require(LocationRule.apply(manchester, timeZone: timeZone, at: date + 60, to: state))
        #expect(away.document.settings.calculationMethod == .moonsightingCommittee)
        #expect(away.document.revision(of: .calculationMethod) > state.document.revision(of: .calculationMethod))

        let back = try #require(LocationRule.apply(london, timeZone: timeZone, at: date + 120, to: away))
        #expect(back.document.settings.calculationMethod == .london)
    }

    @Test
    func aMoveWithinLondonKeepsTheMethod() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var settings = Settings()
        settings.recommendMethod(at: .zone(timeZone, at: london))
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            ownPlace: Place(coordinates: london, timeZone: timeZone, regionName: "London", fixedAt: date)
        )

        let moved = try #require(LocationRule.apply(thirtyKilometresNorth, timeZone: timeZone, at: date + 60, to: state))

        #expect(moved.document == state.document)
    }

    @Test
    func aPickedTimetableSurvivesLeavingLondonAndIsSuggestedAway() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var settings = Settings()
        settings.pickMethod(.london, at: .zone(timeZone, at: london))
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            ownPlace: Place(coordinates: london, timeZone: timeZone, regionName: "London", fixedAt: date)
        )

        let away = try #require(LocationRule.apply(edinburgh, timeZone: timeZone, at: date + 60, to: state))

        #expect(away.document == state.document)
        #expect(away.document.settings.methodSuggestion(at: .zone(timeZone, at: edinburgh)) == .moonsightingCommittee)
        #expect(away.document.settings.methodSuggestion(at: .zone(timeZone, at: luton)) == nil)
    }

    @Test
    func keepingTheTimetableOutsideLondonStopsAskingThere() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var settings = Settings()
        settings.pickMethod(.london, at: .zone(timeZone, at: london))

        settings.keepMethod(at: .zone(timeZone, at: edinburgh))

        #expect(settings.methodSuggestion(at: .zone(timeZone, at: edinburgh)) == nil)
        #expect(settings.methodSuggestion(at: .zone(timeZone, at: manchester)) == nil)
        #expect(settings.calculationMethod == .london)
    }
}

// MARK: - Places picked by hand

extension LondonTimetableTests {
    @Test
    func aManualPlaceOutsideLondonTakesTheMoonsightingCommittee() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let storage = SettingsStorage(defaults: .makeTest())

        let saved = storage.setManualPlace(edinburgh, timeZone: timeZone, regionName: "Edinburgh", at: date)

        #expect(saved.document.settings.calculationMethod == .moonsightingCommittee)
    }

    @Test
    func aFirstRunPlaceOutsideLondonProposesTheMoonsightingCommittee() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let storage = SettingsStorage(defaults: .makeTest())

        let saved = storage.setUpPlace(edinburgh, timeZone: timeZone, regionName: "Edinburgh", at: date)

        #expect(saved.document.settings.calculationMethod == .moonsightingCommittee)
    }
}

// MARK: - Upgrading

extension LondonTimetableTests {
    @Test
    func anUpgradeOutsideLondonMovesTheTimetableTheZoneSetToTheMoonsightingCommittee() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var settings = Settings()
        settings.calculationMethod = .london

        settings.upgradeMethod(at: .zone(timeZone, at: edinburgh))

        #expect(settings.calculationMethod == .moonsightingCommittee)
        #expect(settings.manualMethod == nil)
    }

    // Edinburgh's Maghrib moved 10 minutes later to match its sunset would land 10 minutes late on the Moonsighting
    // Committee's, which already uses it
    @Test
    func anUpgradeOutsideLondonWithAdjustmentsKeepsTheTimetableAndAsks() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var settings = Settings()
        settings.calculationMethod = .london
        settings.adjustmentMinutes = AdjustmentMinutes(rawValue: ["maghrib": 10])

        settings.upgradeMethod(at: .zone(timeZone, at: edinburgh))

        #expect(settings.calculationMethod == .london)
        #expect(settings.methodSuggestion(at: .zone(timeZone, at: edinburgh)) == .moonsightingCommittee)
    }

    @Test
    func leavingLondonWithAdjustmentsKeepsTheTimetableAndAsks() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var settings = Settings()
        settings.recommendMethod(at: .zone(timeZone, at: london))
        settings.adjustmentMinutes = AdjustmentMinutes(rawValue: ["asr": 5])
        let state = DeviceState(document: SettingsDocument(settings: settings), ownPlace: .zone(timeZone, at: london))

        let updated = try #require(LocationRule.apply(edinburgh, timeZone: timeZone, at: date, to: state))

        #expect(updated.document.settings.calculationMethod == .london)
        #expect(updated.document.settings.methodSuggestion(at: .zone(timeZone, at: edinburgh)) == .moonsightingCommittee)

        // Counted as picked by hand from then on, so crossing back and forth no longer flips it
        let back = try #require(LocationRule.apply(london, timeZone: timeZone, at: date + 60, to: updated))
        #expect(back.document.settings.calculationMethod == .london)
        #expect(back.document.settings.methodSuggestion(at: .zone(timeZone, at: london)) == nil)
    }

    @Test
    func aManualPlaceOutsideLondonWithAdjustmentsKeepsTheTimetableAndAsks() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let storage = SettingsStorage(defaults: .makeTest())
        storage.edit {
            $0.recommendMethod(at: .zone(timeZone, at: london))
            $0.adjustmentMinutes = AdjustmentMinutes(rawValue: ["asr": 5])
        }

        let saved = storage.setManualPlace(edinburgh, timeZone: timeZone, regionName: "Edinburgh", at: date)

        #expect(saved.document.settings.calculationMethod == .london)
        #expect(saved.document.settings.methodSuggestion(at: saved.place) == .moonsightingCommittee)
    }

    @Test
    func anUpgradeInLondonKeepsTheTimetable() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var settings = Settings()
        settings.calculationMethod = .london

        settings.upgradeMethod(at: .zone(timeZone, at: london))

        #expect(settings.calculationMethod == .london)
        #expect(settings.manualMethod == nil)
    }

    @Test
    func anUpgradeKeepsAMethodPickedOutsideLondonAndAsksOnce() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        var settings = Settings()
        settings.calculationMethod = .muslimWorldLeague

        settings.upgradeMethod(at: .zone(timeZone, at: edinburgh))

        #expect(settings.calculationMethod == .muslimWorldLeague)
        #expect(settings.methodSuggestion(at: .zone(timeZone, at: edinburgh)) == .moonsightingCommittee)
        #expect(settings.methodSuggestion(at: .zone(timeZone, at: london)) == .london)
    }
}
