//
//  SettingsAdjustmentsTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import PrayCore
import Testing

struct SettingsAdjustmentsTests {
    @Test
    func anAdjustmentIsSaved() throws {
        var settings = Settings()
        settings.editAdjustments { $0[.asr] = 5 }

        let adjustments = try #require(settings.adjustmentMinutes)
        #expect(adjustments[.asr] == 5)
    }

    @Test
    func adjustmentsBackToZeroSaveNone() {
        var settings = Settings()
        settings.editAdjustments {
            $0[.fajr] = -10
            $0.isFajrSunriseRelative = true
        }

        settings.editAdjustments { $0[.fajr] = 0 }

        #expect(settings.adjustmentMinutes == nil)
    }
}
