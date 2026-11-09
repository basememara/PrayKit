//
//  SetUpTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-09.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct SetUpTests {
    private let kualaLumpur = TimeZone(identifier: "Asia/Kuala_Lumpur")
    private let coordinates = Coordinates(latitude: 3.139, longitude: 101.687)
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
}

// MARK: - Proposing

extension SetUpTests {
    @Test
    func aProposalSetsOnlyUnrevisedSettingsAndLeavesThemUnrevised() throws {
        let kualaLumpur = try #require(kualaLumpur)
        let edited = SettingsDocument().editing(at: date) { $0.snoozeMinutes = 10 }

        let proposed = edited.proposing {
            $0.recommendMethod(at: .zone(kualaLumpur))
            $0.snoozeMinutes = 5
        }

        #expect(proposed.settings.calculationMethod == .jakim)
        #expect(proposed.revision(of: .calculationMethod) == .legacy)
        #expect(proposed.settings.snoozeMinutes == 10)
        #expect(proposed.revision(of: .snoozeMinutes) == edited.revision(of: .snoozeMinutes))
    }

    @Test
    func aMethodPickedOnAnotherDeviceBeatsTheProposalWheneverItArrives() throws {
        let kualaLumpur = try #require(kualaLumpur)
        // Picked well before the Mac's first launch, as an existing user's choice always is
        let phone = SettingsDocument().editing(at: Date(timeIntervalSince1970: 1_600_000_000)) { $0.pickMethod(.northAmerica, at: .zone(kualaLumpur)) }
        let mac = SettingsDocument().proposing { $0.recommendMethod(at: .zone(kualaLumpur)) }

        let onTheMac = mac.merging(phone)
        let onThePhone = phone.merging(mac)

        #expect(onTheMac.settings.calculationMethod == .northAmerica)
        #expect(onTheMac.settings.manualMethod == phone.settings.manualMethod)
        #expect(onThePhone == phone)
        #expect(mac.keysNewer(than: phone).isEmpty)
    }

    @Test
    func theFirstDeviceStillSuppliesItsProposedMethod() throws {
        let kualaLumpur = try #require(kualaLumpur)
        let proposed = SettingsDocument().proposing { $0.recommendMethod(at: .zone(kualaLumpur)) }

        #expect(proposed.keysMissing(from: [:]).contains(.calculationMethod))
    }
}

// MARK: - Storage

extension SetUpTests {
    @Test
    func settingUpAPlaceProposesItsMethodAndTurnsGPSOff() throws {
        let kualaLumpur = try #require(kualaLumpur)
        let storage = SettingsStorage(defaults: .makeTest())

        let set = storage.setUpPlace(coordinates, timeZone: kualaLumpur, regionName: "Kuala Lumpur", at: date)

        #expect(set.place == Place(coordinates: coordinates, timeZone: kualaLumpur, regionName: "Kuala Lumpur", fixedAt: date))
        #expect(!set.document.settings.isGPSEnabled)
        #expect(set.document.settings.calculationMethod == .jakim)
        #expect(set.document.revision(of: .calculationMethod) == .legacy)
        #expect(storage.load() == set)
    }

    @Test
    func settingUpAPlaceKeepsAMethodThisDeviceAlreadyHas() throws {
        let kualaLumpur = try #require(kualaLumpur)
        let storage = SettingsStorage(defaults: .makeTest())
        storage.edit(at: date) { $0.pickMethod(.northAmerica, at: .zone(kualaLumpur)) }

        let set = storage.setUpPlace(coordinates, timeZone: kualaLumpur, regionName: "Kuala Lumpur", at: date + 60)

        #expect(set.document.settings.calculationMethod == .northAmerica)
        #expect(set.document.settings.manualMethod == ManualMethod(keptTimeZones: ["Asia/Kuala_Lumpur"]))
    }

    @Test
    func aProposedMethodIsStoredWithoutARevision() throws {
        let kualaLumpur = try #require(kualaLumpur)
        let storage = SettingsStorage(defaults: .makeTest())

        storage.propose { $0.recommendMethod(at: .zone(kualaLumpur)) }

        let stored = storage.load().document
        #expect(stored.settings.calculationMethod == .jakim)
        #expect(stored.revision(of: .calculationMethod) == .legacy)
    }
}
