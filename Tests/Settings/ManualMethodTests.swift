//
//  ManualMethodTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-09.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct ManualMethodTests {
    private let winnipeg = TimeZone(identifier: "America/Winnipeg")
    private let chicago = TimeZone(identifier: "America/Chicago")
    private let riyadh = TimeZone(identifier: "Asia/Riyadh")
    private let utc = TimeZone(identifier: "UTC")
}

// MARK: - Picking

extension ManualMethodTests {
    @Test
    func pickingAMethodKeepsItWhereItWasPicked() throws {
        let winnipeg = try #require(winnipeg)
        var settings = Settings()

        settings.pickMethod(.northAmerica, at: .zone(winnipeg))

        #expect(settings.calculationMethod == .northAmerica)
        #expect(settings.manualMethod == ManualMethod(keptTimeZones: ["America/Winnipeg"]))
        #expect(settings.methodSuggestion(at: .zone(winnipeg)) == nil)
    }

    @Test
    func pickingAgainForgetsWhereTheLastPickWasKept() throws {
        let winnipeg = try #require(winnipeg)
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.pickMethod(.northAmerica, at: .zone(winnipeg))
        settings.keepMethod(at: .zone(riyadh))

        settings.pickMethod(.muslimWorldLeague, at: .zone(riyadh))

        #expect(settings.manualMethod == ManualMethod(keptTimeZones: ["Asia/Riyadh"]))
    }

    @Test
    func theRecommendedMethodFollowsThePlaceAgain() throws {
        let winnipeg = try #require(winnipeg)
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.pickMethod(.northAmerica, at: .zone(winnipeg))

        settings.recommendMethod(at: .zone(riyadh))

        #expect(settings.calculationMethod == .ummAlQura)
        #expect(settings.manualMethod == nil)
    }
}

// MARK: - Suggesting

extension ManualMethodTests {
    @Test
    func aNewPlaceRecommendingAnotherMethodSuggestsIt() throws {
        let winnipeg = try #require(winnipeg)
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.pickMethod(.northAmerica, at: .zone(winnipeg))

        #expect(settings.methodSuggestion(at: .zone(riyadh)) == .ummAlQura)
    }

    @Test
    func aPlaceRecommendingThePickedMethodSuggestsNothing() throws {
        let winnipeg = try #require(winnipeg)
        let chicago = try #require(chicago)
        var settings = Settings()
        settings.pickMethod(.northAmerica, at: .zone(winnipeg))

        #expect(settings.methodSuggestion(at: .zone(chicago)) == nil)
    }

    @Test
    func aPlaceWithoutARecommendationSuggestsNothing() throws {
        let winnipeg = try #require(winnipeg)
        let utc = try #require(utc)
        var settings = Settings()
        settings.pickMethod(.ummAlQura, at: .zone(winnipeg))

        #expect(CalculationMethod.recommended(for: utc, at: nil) == nil)
        #expect(settings.methodSuggestion(at: .zone(utc)) == nil)
    }

    @Test
    func keepingTheMethodSomewhereStopsAskingThere() throws {
        let winnipeg = try #require(winnipeg)
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.pickMethod(.northAmerica, at: .zone(winnipeg))

        settings.keepMethod(at: .zone(riyadh))

        #expect(settings.calculationMethod == .northAmerica)
        #expect(settings.manualMethod == ManualMethod(keptTimeZones: ["America/Winnipeg", "Asia/Riyadh"]))
        #expect(settings.methodSuggestion(at: .zone(riyadh)) == nil)
    }

    @Test
    func aMethodThatFollowsThePlaceIsNeverSuggested() throws {
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.calculationMethod = .northAmerica

        settings.keepMethod(at: .zone(riyadh))

        #expect(settings.manualMethod == nil)
        #expect(settings.methodSuggestion(at: .zone(riyadh)) == nil)
    }
}

// MARK: - Upgrading

extension ManualMethodTests {
    // Old defaults and the old fallback left many on a method the place doesn't use, so the place asks once, and a
    // method kept there is never asked about again
    @Test
    func aMethodOtherThanThePlacesIsKeptAndAskedAboutOnce() throws {
        let winnipeg = try #require(winnipeg)
        var settings = Settings()
        settings.calculationMethod = .northAmerica

        settings.upgradeMethod(at: .zone(winnipeg))

        #expect(settings.calculationMethod == .northAmerica)
        #expect(settings.manualMethod == ManualMethod(keptTimeZones: []))
        #expect(settings.methodSuggestion(at: .zone(winnipeg)) == .moonsightingCommittee)

        settings.keepMethod(at: .zone(winnipeg))

        #expect(settings.methodSuggestion(at: .zone(winnipeg)) == nil)
    }

    @Test(arguments: [CalculationMethod.moonsightingCommittee, .muslimWorldLeague])
    func aUniversalMethodOtherThanThePlacesIsKeptAndAskedAboutOnce(method: CalculationMethod) throws {
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.calculationMethod = method

        settings.upgradeMethod(at: .zone(riyadh))

        #expect(settings.calculationMethod == method)
        #expect(settings.manualMethod == ManualMethod(keptTimeZones: []))
        #expect(settings.methodSuggestion(at: .zone(riyadh)) != nil)

        settings.keepMethod(at: .zone(riyadh))

        #expect(settings.methodSuggestion(at: .zone(riyadh)) == nil)
    }

    @Test
    func theDefaultWhereNoMethodIsRecommendedIsNotTakenForAPick() throws {
        let utc = try #require(utc)
        var settings = Settings()
        settings.calculationMethod = .moonsightingCommittee

        settings.upgradeMethod(at: .zone(utc))

        #expect(settings.manualMethod == nil)
    }

    @Test
    func thePlacesOwnMethodIsNotTakenForAPick() throws {
        let chicago = try #require(chicago)
        var settings = Settings()
        settings.calculationMethod = .northAmerica

        settings.upgradeMethod(at: .zone(chicago))

        #expect(settings.manualMethod == nil)
    }

    @Test
    func anExistingPickIsLeftAlone() throws {
        let winnipeg = try #require(winnipeg)
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.pickMethod(.northAmerica, at: .zone(winnipeg))

        settings.upgradeMethod(at: .zone(riyadh))

        #expect(settings.manualMethod == ManualMethod(keptTimeZones: ["America/Winnipeg"]))
    }
}

// MARK: - Encoding

extension ManualMethodTests {
    @Test
    func theKeptTimeZonesEncodeSorted() throws {
        let method = ManualMethod(keptTimeZones: ["Europe/London", "America/Winnipeg", "Asia/Riyadh"])

        let json = try String(decoding: JSONEncoder().encode(method), as: UTF8.self)

        #expect(json == #"{"keptTimeZones":["America\/Winnipeg","Asia\/Riyadh","Europe\/London"]}"#)
        #expect(try JSONDecoder().decode(ManualMethod.self, from: Data(json.utf8)) == method)
    }
}
