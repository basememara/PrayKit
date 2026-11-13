//
//  PickedPlaceTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
@testable import PrayCore
import Testing

/// Where each device calculates for: its own place while location is on, and the city picked for the account while it's
/// off. A place picked during first-run setup is the device's own, so it stays on the device that picked it.
struct PickedPlaceTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    private let cyberjaya = Coordinates(latitude: 2.9213, longitude: 101.6559)
    private let kualaLumpur = Coordinates(latitude: 3.139, longitude: 101.687)
    private let toronto = Coordinates(latitude: 43.6510, longitude: -79.3470)
}

extension PickedPlaceTests {
    @Test
    func aCityPickedOnOneDeviceMovesTheOthers() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let phone = SettingsStorage(defaults: .makeTest())
        let mac = SettingsStorage(defaults: .makeTest())
        phone.saveLocation(cyberjaya, timeZone: timeZone, at: date)
        mac.saveLocation(cyberjaya, timeZone: timeZone, at: date)

        // When
        phone.setManualPlace(kualaLumpur, timeZone: timeZone, regionName: "Kuala Lumpur", at: date + 60)
        let received = deliver(from: phone, to: mac, at: date + 120)

        // Then
        let place = try #require(received.place)
        #expect(place.coordinates == kualaLumpur)
        #expect(place.regionName == "Kuala Lumpur")
        #expect(!received.document.settings.followsLocation)
        #expect(LocationRule.apply(cyberjaya, timeZone: timeZone, at: date + 180, to: received) == nil, "A fix never replaces it")
    }

    /// Turning location off shares the place this device is on, so no device stays wherever it last was.
    @Test
    func turningAutomaticOffSharesThisDevicesPlace() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let phone = SettingsStorage(defaults: .makeTest())
        let mac = SettingsStorage(defaults: .makeTest())
        phone.saveLocation(kualaLumpur, timeZone: timeZone, at: date)
        mac.saveLocation(cyberjaya, timeZone: timeZone, at: date)

        // When
        let stopped = phone.stopFollowingLocation(at: date + 60)
        let received = deliver(from: phone, to: mac, at: date + 120)

        // Then
        #expect(stopped.place?.coordinates == kualaLumpur, "This device stays where it is")
        #expect(received.place?.coordinates == kualaLumpur)
        #expect(!received.document.settings.followsLocation)
    }

    @Test
    func turningAutomaticOnLetsEveryDeviceFollowItsOwnLocation() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let phone = SettingsStorage(defaults: .makeTest())
        let mac = SettingsStorage(defaults: .makeTest())
        mac.saveLocation(cyberjaya, timeZone: timeZone, at: date)
        phone.setManualPlace(kualaLumpur, timeZone: timeZone, regionName: "Kuala Lumpur", at: date)
        deliver(from: phone, to: mac, at: date + 60)

        // When
        phone.followLocation(at: date + 120)
        let received = deliver(from: phone, to: mac, at: date + 180)

        // Then
        #expect(received.document.settings.followsLocation)
        #expect(received.document.settings.pickedPlace == nil)
        #expect(received.place?.coordinates == cyberjaya, "Back on its own place until its next fix")

        let fixed = try #require(LocationRule.apply(kualaLumpur, timeZone: timeZone, at: date + 240, to: received))
        #expect(fixed.place?.coordinates == kualaLumpur)
    }

    /// The device that turns location on stays where it is until its fix, rather than going back to an old one of its own.
    @Test
    func turningAutomaticOnHereKeepsThisDeviceWhereItIsUntilItsFix() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let phone = SettingsStorage(defaults: .makeTest())
        phone.saveLocation(cyberjaya, timeZone: timeZone, at: date)
        phone.setManualPlace(kualaLumpur, timeZone: timeZone, regionName: "Kuala Lumpur", at: date + 60)

        // When
        let following = phone.followLocation(at: date + 120)

        // Then
        #expect(following.place?.coordinates == kualaLumpur)
        #expect(following.place?.fixedAt == nil)

        let fixed = try #require(LocationRule.apply(kualaLumpur, timeZone: timeZone, at: date + 180, to: following), "However near")
        #expect(fixed.place?.fixedAt == date + 180)
    }

    /// A new device's first-run pick is kept on it, so setting up a Mac never takes the iPhone off its location.
    @Test
    func aPlacePickedDuringSetupStaysOnItsDevice() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let phone = SettingsStorage(defaults: .makeTest())
        let mac = SettingsStorage(defaults: .makeTest())
        phone.saveLocation(cyberjaya, timeZone: timeZone, at: date)

        // When
        mac.setUpPlace(kualaLumpur, timeZone: timeZone, regionName: "Kuala Lumpur", at: date + 60)
        let received = deliver(from: mac, to: phone, at: date + 120)

        // Then
        #expect(received.place?.coordinates == cyberjaya)
        #expect(received.document.settings.followsLocation)
        #expect(mac.load().document.settings.pickedPlace == nil)
    }

    /// A new device set up on its own location never clears a city the account picked, so the others stay on it.
    @Test
    func settingUpOnLocationNeverClearsTheAccountsPick() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let phone = SettingsStorage(defaults: .makeTest())
        let mac = SettingsStorage(defaults: .makeTest())
        phone.setManualPlace(kualaLumpur, timeZone: timeZone, regionName: "Kuala Lumpur", at: date)
        deliver(from: phone, to: mac, at: date + 60)

        // When
        let setUp = mac.setUpLocation(at: date + 120)
        let received = deliver(from: mac, to: phone, at: date + 180)

        // Then
        #expect(setUp.place?.coordinates == kualaLumpur)
        #expect(received.place?.coordinates == kualaLumpur)
        #expect(!received.document.settings.followsLocation)
    }

    @Test
    func settingUpOnLocationFollowsItWhenNothingIsPicked() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let mac = SettingsStorage(defaults: .makeTest())
        mac.setUpPlace(cyberjaya, timeZone: timeZone, regionName: "Cyberjaya", at: date)

        // When
        let setUp = mac.setUpLocation(at: date + 60)

        // Then
        #expect(setUp.document.settings.followsLocation)
    }

    @Test
    func aDevicePinnedAtSetupStillTakesALaterPick() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let phone = SettingsStorage(defaults: .makeTest())
        let mac = SettingsStorage(defaults: .makeTest())
        mac.setUpPlace(cyberjaya, timeZone: timeZone, regionName: "Cyberjaya", at: date)

        // When
        phone.setManualPlace(kualaLumpur, timeZone: timeZone, regionName: "Kuala Lumpur", at: date + 60)
        let received = deliver(from: phone, to: mac, at: date + 120)

        // Then
        #expect(received.place?.coordinates == kualaLumpur)
    }

    /// A device pinned at setup keeps its city whenever the account is on location, until location changes on it.
    @Test
    func aDevicePinnedAtSetupGoesBackToItsCityWhenLocationIsTurnedOn() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let phone = SettingsStorage(defaults: .makeTest())
        let mac = SettingsStorage(defaults: .makeTest())
        mac.setUpPlace(cyberjaya, timeZone: timeZone, regionName: "Cyberjaya", at: date)
        phone.setManualPlace(kualaLumpur, timeZone: timeZone, regionName: "Kuala Lumpur", at: date + 60)
        deliver(from: phone, to: mac, at: date + 120)

        // When
        phone.followLocation(at: date + 180)
        let received = deliver(from: phone, to: mac, at: date + 240)

        // Then
        #expect(received.place?.coordinates == cyberjaya)
        #expect(!received.document.settings.followsLocation)
    }

    @Test
    func theLaterOfTwoPicksWinsOnEveryDevice() throws {
        // Given
        let kualaLumpurZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let torontoZone = try #require(TimeZone(identifier: "America/Toronto"))
        let phone = SettingsStorage(defaults: .makeTest())
        let mac = SettingsStorage(defaults: .makeTest())

        // When
        phone.setManualPlace(kualaLumpur, timeZone: kualaLumpurZone, regionName: "Kuala Lumpur", at: date)
        mac.setManualPlace(toronto, timeZone: torontoZone, regionName: "Toronto", at: date + 60)
        let phoneAfter = deliver(from: mac, to: phone, at: date + 120)
        let macAfter = deliver(from: phone, to: mac, at: date + 180)

        // Then
        #expect(phoneAfter.place?.coordinates == toronto)
        #expect(macAfter.place?.coordinates == toronto)
        #expect(phoneAfter.place?.timeZone == torontoZone)
    }

    /// A device that holds the account's pick without ever having moved to it, as one that fetched the pick before
    /// upgrading, is on it all the same: the place is read from the settings, not copied on arrival.
    @Test
    func aPickHeldButNeverAppliedIsWhereTheDeviceIs() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let mac = SettingsStorage(defaults: .makeTest())
        mac.saveLocation(cyberjaya, timeZone: timeZone, at: date)
        let picked = Place(coordinates: kualaLumpur, timeZone: timeZone, regionName: "Kuala Lumpur", fixedAt: date)

        // When
        mac.edit(at: date + 60) {
            $0.isGPSEnabled = false
            $0.pickedPlace = picked
        }

        // Then
        #expect(mac.load().place == picked)
    }

    /// The same copy arriving twice changes nothing the second time.
    @Test
    func aPickArrivingAgainLeavesTheDeviceAlone() throws {
        // Given
        let timeZone = try #require(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let phone = SettingsStorage(defaults: .makeTest())
        let mac = SettingsStorage(defaults: .makeTest())
        phone.setManualPlace(kualaLumpur, timeZone: timeZone, regionName: "Kuala Lumpur", at: date)
        let first = deliver(from: phone, to: mac, at: date + 60)

        // When
        let again = deliver(from: phone, to: mac, at: date + 60)

        // Then
        #expect(again == first)
    }
}

// MARK: - Helpers

private extension PickedPlaceTests {
    /// The sender's settings reaching the receiver as an iCloud record does: the synced settings with their revisions.
    @discardableResult
    func deliver(from sender: SettingsStorage, to receiver: SettingsStorage, at date: Date) -> DeviceState {
        let fields = sender.load().document.wireFields

        return receiver.update { state in
            let remote = SettingsDocument(wireFields: fields, base: state.document.settings, modifiedAt: date, previous: nil)
            return state.replacing(document: state.document.merging(remote))
        }
    }
}
