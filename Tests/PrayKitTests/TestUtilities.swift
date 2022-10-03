//
//  TestUtilities.swift
//  PrayCoreTests
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation.NSUserDefaults

extension UserDefaults {
    static let suiteName = UUID().uuidString
    static let test = UserDefaults(suiteName: suiteName) ?? .standard

    static func testReset() {
        UserDefaults.test.removePersistentDomain(forName: suiteName)
    }
}
