//
//  Settings+Adjustments.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

public extension Settings {
    /// The adjustments to bind a screen to: none saved reads as all zero, and a write follows `editAdjustments`.
    var adjustments: AdjustmentMinutes {
        get { adjustmentMinutes ?? AdjustmentMinutes(rawValue: [:]) }
        set { editAdjustments { $0 = newValue } }
    }

    /// Edits the prayer time adjustments, saving none at all once every adjustment is back to zero and
    /// neither prayer counts from sunrise or Maghrib; a relative choice stays while its minutes are zero.
    mutating func editAdjustments(_ edit: (inout AdjustmentMinutes) -> Void) {
        var adjustments = adjustmentMinutes ?? AdjustmentMinutes(rawValue: [:])
        edit(&adjustments)

        let isRelative = adjustments.isFajrSunriseRelative || adjustments.isIshaMaghribRelative
        adjustmentMinutes = adjustments.isEmpty && !isRelative ? nil : adjustments
    }
}
