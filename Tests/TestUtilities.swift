//
//  TestUtilities.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation.NSUserDefaults

extension UserDefaults {
    /// Returns a defaults suite private to the caller.
    ///
    /// Swift Testing builds a fresh suite instance for every test and runs tests in
    /// parallel, so each one gets its own store instead of sharing a process-wide
    /// suite that has to be reset between runs.
    static func makeTest() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString) ?? .standard
    }
}
