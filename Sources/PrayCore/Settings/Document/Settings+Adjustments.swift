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

    /// Edits the prayer time adjustments, saving none at all once every adjustment is back to zero; a relative
    /// choice always has minutes, so it keeps them saved.
    mutating func editAdjustments(_ edit: (inout AdjustmentMinutes) -> Void) {
        var adjustments = adjustmentMinutes ?? AdjustmentMinutes(rawValue: [:])
        edit(&adjustments)
        adjustmentMinutes = adjustments.isEmpty ? nil : adjustments
    }
}
