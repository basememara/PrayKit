//
//  UserDefaults+Diagnostics.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation.NSUserDefaults

public extension UserDefaults {
    /// When the user last sent a diagnostics report, which keeps logging verbose for a while afterwards.
    var lastDiagnosticsDate: Date? {
        get { object(forKey: "lastDiagnosticsDate") as? Date }
        set { set(newValue, forKey: "lastDiagnosticsDate") }
    }
}
