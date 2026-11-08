//
//  MoonPhaseTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-08.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct MoonPhaseTests {
    @Test
    func theMonthOpensOnAThinWaxingCrescent() {
        let phase = MoonPhase(hijriDay: 1)
        #expect(phase.illumination < 0.05)
        #expect(phase.isWaxing)
    }

    @Test
    func theMoonIsFullMidMonth() {
        #expect(MoonPhase(hijriDay: 15).illumination > 0.98)
    }

    @Test
    func theLastQuarterIsHalfLitAndWaning() {
        let phase = MoonPhase(hijriDay: 22)
        #expect(abs(phase.illumination - 0.5) <= 0.1)
        #expect(!phase.isWaxing)
    }

    @Test
    func theMonthClosesOnAThinWaningCrescent() {
        let phase = MoonPhase(hijriDay: 29)
        #expect(phase.illumination < 0.05)
        #expect(!phase.isWaxing)
    }
}
