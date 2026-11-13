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
    func theFirstFixSavesThePlaceAndProposesItsMethod() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let kualaLumpur = Coordinates(latitude: 3.139, longitude: 101.687)

        let saved = try #require(LocationRule.apply(kualaLumpur, timeZone: timeZone, at: date, to: DeviceState()))

        #expect(saved.place == Place(coordinates: kualaLumpur, timeZone: timeZone, regionName: nil, fixedAt: date))
        #expect(saved.document.settings.calculationMethod == .jakim)
        #expect(saved.document.revision(of: .calculationMethod) == .legacy)
    }

    @Test
    func theFirstFixKeepsAMethodAlreadyChosen() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let picked = SettingsDocument().editing(at: date - 60) { $0.pickMethod(.jakim, at: nil) }

        let saved = try #require(LocationRule.apply(toronto, timeZone: timeZone, at: date, to: DeviceState(document: picked)))

        #expect(saved.document == picked)
    }

    @Test
    func aFirstFixOutsideLondonLeavesTheTimeZonesProposal() throws {
        let timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let edinburgh = Coordinates(latitude: 55.9533, longitude: -3.1883)
        var settings = Settings()
        settings.calculationMethod = .london
        let proposedByZone = SettingsDocument(settings: settings)

        let saved = try #require(LocationRule.apply(edinburgh, timeZone: timeZone, at: date, to: DeviceState(document: proposedByZone)))

        #expect(saved.document.settings.calculationMethod == .moonsightingCommittee)
    }

    @Test
    func aFollowersMethodIsReadFromThisDevicesPlace() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let home = Place(coordinates: Coordinates(latitude: 3.139, longitude: 101.687), timeZone: timeZone, regionName: nil, fixedAt: date)
        var settings = Settings()
        // As stored by another of the account's devices, following its own place
        settings.calculationMethod = .ummAlQura

        #expect(settings.method(at: home) == .jakim)
        #expect(settings.chosenMethod(at: home) == .jakim)

        settings.pickMethod(.ummAlQura, at: home)

        #expect(settings.method(at: home) == .ummAlQura)
        #expect(settings.chosenMethod(at: home) == .ummAlQura)
    }

    @Test
    func aPlacePickedHereIsTheAccountsWithLocationOff() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let storage = SettingsStorage(defaults: .makeTest())

        let picked = storage.setManualPlace(toronto, timeZone: timeZone, regionName: "Toronto", at: date)

        #expect(!picked.document.settings.isGPSEnabled)
        #expect(!picked.document.settings.isPlacePinned)
        #expect(!picked.document.settings.followsLocation)
        #expect(picked.document.settings.pickedPlace == picked.place)
        #expect(picked.document.wireFields[SettingKey.pickedPlace.rawValue] != nil)
        #expect(LocationRule.apply(Coordinates(latitude: 45.5, longitude: -73.6), timeZone: timeZone, at: date + 60, to: picked) == nil)

        var settings = picked.document.settings
        settings.followLocation()

        #expect(settings.followsLocation)
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
        #expect(updated.document.settings.calculationMethod == .ummAlQuraRamadan)
        #expect(updated.document.revision(of: .calculationMethod) > state.document.revision(of: .calculationMethod))
    }

    @Test(arguments: [CalculationMethod.moonsightingCommittee, .muslimWorldLeague])
    func universalMethodsTheAppSetFollowThePlace(method: CalculationMethod) throws {
        let saved = try #require(TimeZone(identifier: "America/Toronto"))
        let current = try #require(TimeZone(identifier: "Asia/Riyadh"))
        var settings = Settings()
        settings.calculationMethod = method
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            place: Place(coordinates: toronto, timeZone: saved, regionName: "Toronto", fixedAt: date)
        )

        let updated = try #require(LocationRule.apply(toronto, timeZone: current, at: date, to: state))

        #expect(updated.document.settings.calculationMethod == .ummAlQuraRamadan)
    }

    @Test(arguments: [CalculationMethod.moonsightingCommittee, .muslimWorldLeague])
    func universalMethodsPickedByHandSurviveATimeZoneChange(method: CalculationMethod) throws {
        let saved = try #require(TimeZone(identifier: "America/Toronto"))
        let current = try #require(TimeZone(identifier: "Asia/Riyadh"))
        var settings = Settings()
        settings.pickMethod(method, at: .zone(saved))
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            place: Place(coordinates: toronto, timeZone: saved, regionName: "Toronto", fixedAt: date)
        )

        let updated = try #require(LocationRule.apply(toronto, timeZone: current, at: date, to: state))

        #expect(updated.document.settings.calculationMethod == method)
    }

    @Test
    func aMethodPickedByHandSurvivesATimeZoneChange() throws {
        let saved = try #require(TimeZone(identifier: "America/Winnipeg"))
        let current = try #require(TimeZone(identifier: "Asia/Riyadh"))
        var settings = Settings()
        settings.pickMethod(.northAmerica, at: .zone(saved))
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            place: Place(coordinates: toronto, timeZone: saved, regionName: "Fort Frances", fixedAt: date)
        )

        let updated = try #require(LocationRule.apply(toronto, timeZone: current, at: date + 60, to: state))

        #expect(updated.place?.timeZone == current)
        #expect(updated.document == state.document)
        #expect(updated.document.settings.methodSuggestion(at: .zone(current)) == .ummAlQuraRamadan)
    }

    // London's timetable is printed for London's clock: read in Riyadh it put Maghrib an hour and a half early
    @Test
    func londonPickedByHandIsReadAsThePlacesMethodOutsideItsTimeZoneAndKept() throws {
        let london = try #require(TimeZone(identifier: "Europe/London"))
        let riyadh = try #require(TimeZone(identifier: "Asia/Riyadh"))
        let makkah = Coordinates(latitude: 21.4225, longitude: 39.8262)
        var settings = Settings()
        settings.pickMethod(.london, at: .zone(london))
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            place: Place(coordinates: Coordinates(latitude: 51.5074, longitude: -0.1278), timeZone: london, regionName: "London", fixedAt: date)
        )

        let updated = try #require(LocationRule.apply(makkah, timeZone: riyadh, at: date + 60, to: state))
        let abroad = updated.document.settings
        let place = try #require(updated.place)

        #expect(abroad.calculationMethod == .london)
        #expect(abroad.method(at: place) == .ummAlQuraRamadan)
        #expect(PrayerAPI.Request(settings: abroad, place: place)?.method == .ummAlQuraRamadan)
        #expect(abroad.methodSuggestion(at: place) == nil)

        let home = try #require(LocationRule.apply(Coordinates(latitude: 51.5074, longitude: -0.1278), timeZone: london, at: date + 120, to: updated))
        #expect(try home.document.settings.method(at: #require(home.place)) == .london)
    }

    // iCloud brings the pick without a fix, so the device it lands on must read it by its own place
    @Test
    func londonPickedOnAnotherDeviceIsReadAsThePlacesMethod() throws {
        let london = try #require(TimeZone(identifier: "Europe/London"))
        let riyadh = try #require(TimeZone(identifier: "Asia/Riyadh"))
        var settings = Settings()
        settings.pickMethod(.london, at: .zone(london))
        let place = Place(coordinates: Coordinates(latitude: 21.4225, longitude: 39.8262), timeZone: riyadh, regionName: "Makkah", fixedAt: date)

        #expect(PrayerAPI.Request(settings: settings, place: place)?.method == .ummAlQuraRamadan)
    }

    @Test
    func londonPickedByHandStaysAcrossTheUK() throws {
        let london = try #require(TimeZone(identifier: "Europe/London"))
        let manchester = Coordinates(latitude: 53.4808, longitude: -2.2426)
        var settings = Settings()
        settings.pickMethod(.london, at: .zone(london))
        let state = DeviceState(
            document: SettingsDocument(settings: settings),
            place: Place(coordinates: Coordinates(latitude: 51.5074, longitude: -0.1278), timeZone: london, regionName: "London", fixedAt: date)
        )

        let updated = try #require(LocationRule.apply(manchester, timeZone: london, at: date + 60, to: state))

        #expect(updated.document.settings.calculationMethod == .london)
        #expect(updated.document.settings.manualMethod != nil)
    }

    @Test
    func aCityPickedAbroadKeepsLondonPickedByHandAndReadsTheCitysMethod() throws {
        let london = try #require(TimeZone(identifier: "Europe/London"))
        let riyadh = try #require(TimeZone(identifier: "Asia/Riyadh"))
        let storage = SettingsStorage(defaults: .makeTest())
        storage.edit { $0.pickMethod(.london, at: .zone(london)) }

        let saved = storage.setManualPlace(Coordinates(latitude: 21.4225, longitude: 39.8262), timeZone: riyadh, regionName: "Makkah", at: date)

        #expect(saved.document.settings.calculationMethod == .london)
        #expect(try saved.document.settings.method(at: #require(saved.place)) == .ummAlQuraRamadan)
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
    func aFixIsDatedWhenItWasTakenNotWhenItWasSaved() throws {
        let storage = SettingsStorage(defaults: .makeTest())
        let cached = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: toronto.latitude, longitude: toronto.longitude),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: date
        )

        storage.saveLocation(cached)

        let place = try #require(storage.load().place)
        #expect(place.fixedAt == date)
    }

    @Test
    func aMoveClearsTheNameAndOnlyTheNewPlacesLookupNamesIt() throws {
        let storage = SettingsStorage(defaults: .makeTest())
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let away = Coordinates(latitude: 43.6700, longitude: -79.3470)

        storage.saveLocation(toronto, timeZone: timeZone, at: date)
        storage.saveRegionName("Toronto", for: toronto)
        let named = try #require(storage.load().place)
        #expect(named.regionName == "Toronto")

        storage.saveLocation(away, timeZone: timeZone, at: date + 60)
        storage.saveRegionName("Somewhere stale", for: toronto)
        let moved = try #require(storage.load().place)
        #expect(moved.regionName == nil)
        #expect(moved.coordinates == away)

        storage.saveRegionName("East York", for: away)
        let renamed = try #require(storage.load().place)
        #expect(renamed.regionName == "East York")
    }

    @Test
    func aManualPlaceIsTheAccountsAndTakesItsRecommendedMethod() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let storage = SettingsStorage(defaults: .makeTest())
        storage.edit { $0.calculationMethod = .muslimWorldLeague }

        let saved = storage.setManualPlace(toronto, timeZone: timeZone, regionName: "Kuala Lumpur", at: date)

        #expect(saved.place == Place(coordinates: toronto, timeZone: timeZone, regionName: "Kuala Lumpur", fixedAt: date))
        #expect(saved.document.settings.pickedPlace == saved.place)
        #expect(!saved.document.settings.isGPSEnabled)
        #expect(saved.document.settings.calculationMethod == .jakim)
        #expect(storage.load() == saved)
    }

    @Test
    func aMethodAPlacePickedByHandSetIsReplacedWhenGPSComesBack() throws {
        let kualaLumpur = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let paris = try #require(TimeZone(identifier: "Europe/Paris"))
        let kualaLumpurCoordinates = Coordinates(latitude: 3.139, longitude: 101.687)
        let storage = SettingsStorage(defaults: .makeTest())
        storage.saveLocation(kualaLumpurCoordinates, timeZone: kualaLumpur, at: date)
        storage.edit { $0.calculationMethod = .jakim }

        let manual = storage.setManualPlace(Coordinates(latitude: 48.857, longitude: 2.352), timeZone: paris, regionName: "Paris", at: date + 60)
        #expect(manual.document.settings.calculationMethod == .muslimWorldLeague)

        storage.edit { $0.followLocation() }
        let back = storage.saveLocation(kualaLumpurCoordinates, timeZone: kualaLumpur, at: date + 120)

        #expect(back.document.settings.calculationMethod == .jakim)
    }

    @Test
    func aManualPlaceKeepsAMethodPickedByHand() throws {
        let picked = try #require(TimeZone(identifier: "America/Winnipeg"))
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let storage = SettingsStorage(defaults: .makeTest())
        storage.edit { $0.pickMethod(.northAmerica, at: .zone(picked)) }

        let saved = storage.setManualPlace(toronto, timeZone: timeZone, regionName: "Kuala Lumpur", at: date)

        #expect(saved.document.settings.pickedPlace == saved.place)
        #expect(saved.document.settings.calculationMethod == .northAmerica)
        #expect(saved.document.settings.methodSuggestion(at: .zone(timeZone)) == .jakim)
    }
}
