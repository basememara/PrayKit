//
//  TestCase.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import XCTest
import PrayCore
import PrayServices
import ZamzamCore

class TestCase: XCTestCase {
    let log = LogManager(services: [LogServiceConsole(minLevel: .none, subsystem: "PrayKitTests")])

    private(set) lazy var prayerManager = PrayerManager(
        service: PrayerServiceAdhan(log: log),
        londonService: PrayerServiceLondon(
            networkManager: NetworkManager(service: NetworkServiceFoundation()),
            apiKey: "{{your api key}}",
            log: log
        ),
        preferences: Preferences(defaults: .test),
        log: log
    )

    override func setUpWithError() throws {
        try super.setUpWithError()
        UserDefaults.testReset()
    }
}
