//
//  Settings+Adjustments.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

public extension Settings {
    /// Edits the prayer time adjustments, saving none at all once every adjustment is back to zero.
    mutating func editAdjustments(_ edit: (inout AdjustmentMinutes) -> Void) {
        var adjustments = adjustmentMinutes ?? AdjustmentMinutes(rawValue: [:])
        edit(&adjustments)
        adjustmentMinutes = adjustments.isEmpty ? nil : adjustments
    }
}
