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

        settings.pickMethod(.northAmerica, in: winnipeg)

        #expect(settings.calculationMethod == .northAmerica)
        #expect(settings.manualMethod == ManualMethod(keptTimeZones: ["America/Winnipeg"]))
        #expect(settings.methodSuggestion(in: winnipeg) == nil)
    }

    @Test
    func pickingAgainForgetsWhereTheLastPickWasKept() throws {
        let winnipeg = try #require(winnipeg)
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.pickMethod(.northAmerica, in: winnipeg)
        settings.keepMethod(in: riyadh)

        settings.pickMethod(.muslimWorldLeague, in: riyadh)

        #expect(settings.manualMethod == ManualMethod(keptTimeZones: ["Asia/Riyadh"]))
    }

    @Test
    func theRecommendedMethodFollowsThePlaceAgain() throws {
        let winnipeg = try #require(winnipeg)
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.pickMethod(.northAmerica, in: winnipeg)

        settings.recommendMethod(for: riyadh)

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
        settings.pickMethod(.northAmerica, in: winnipeg)

        #expect(settings.methodSuggestion(in: riyadh) == .ummAlQura)
    }

    @Test
    func aPlaceRecommendingThePickedMethodSuggestsNothing() throws {
        let winnipeg = try #require(winnipeg)
        let chicago = try #require(chicago)
        var settings = Settings()
        settings.pickMethod(.northAmerica, in: winnipeg)

        #expect(settings.methodSuggestion(in: chicago) == nil)
    }

    @Test
    func aPlaceWithoutARecommendationSuggestsNothing() throws {
        let winnipeg = try #require(winnipeg)
        let utc = try #require(utc)
        var settings = Settings()
        settings.pickMethod(.ummAlQura, in: winnipeg)

        #expect(CalculationMethod.recommended(for: utc) == nil)
        #expect(settings.methodSuggestion(in: utc) == nil)
    }

    @Test
    func keepingTheMethodSomewhereStopsAskingThere() throws {
        let winnipeg = try #require(winnipeg)
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.pickMethod(.northAmerica, in: winnipeg)

        settings.keepMethod(in: riyadh)

        #expect(settings.calculationMethod == .northAmerica)
        #expect(settings.manualMethod == ManualMethod(keptTimeZones: ["America/Winnipeg", "Asia/Riyadh"]))
        #expect(settings.methodSuggestion(in: riyadh) == nil)
    }

    @Test
    func aMethodThatFollowsThePlaceIsNeverSuggested() throws {
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.calculationMethod = .northAmerica

        settings.keepMethod(in: riyadh)

        #expect(settings.manualMethod == nil)
        #expect(settings.methodSuggestion(in: riyadh) == nil)
    }
}

// MARK: - Upgrading

extension ManualMethodTests {
    @Test
    func aMethodOtherThanThePlacesWasPickedByHand() throws {
        let winnipeg = try #require(winnipeg)
        var settings = Settings()
        settings.calculationMethod = .northAmerica

        settings.inferManualMethod(in: winnipeg)

        #expect(settings.manualMethod == ManualMethod(keptTimeZones: ["America/Winnipeg"]))
    }

    @Test(arguments: [CalculationMethod.moonsightingCommittee, .muslimWorldLeague])
    func aUniversalMethodOtherThanThePlacesWasPickedByHand(method: CalculationMethod) throws {
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.calculationMethod = method

        settings.inferManualMethod(in: riyadh)

        #expect(settings.manualMethod == ManualMethod(keptTimeZones: ["Asia/Riyadh"]))
    }

    @Test
    func theDefaultWhereNoMethodIsRecommendedIsNotTakenForAPick() throws {
        let utc = try #require(utc)
        var settings = Settings()
        settings.calculationMethod = .moonsightingCommittee

        settings.inferManualMethod(in: utc)

        #expect(settings.manualMethod == nil)
    }

    @Test
    func thePlacesOwnMethodIsNotTakenForAPick() throws {
        let chicago = try #require(chicago)
        var settings = Settings()
        settings.calculationMethod = .northAmerica

        settings.inferManualMethod(in: chicago)

        #expect(settings.manualMethod == nil)
    }

    @Test
    func anExistingPickIsLeftAlone() throws {
        let winnipeg = try #require(winnipeg)
        let riyadh = try #require(riyadh)
        var settings = Settings()
        settings.pickMethod(.northAmerica, in: winnipeg)

        settings.inferManualMethod(in: riyadh)

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
