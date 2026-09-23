//
//  TestFixture.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import PrayCore
import PrayServices
import ZamzamCore

/// The dependencies a suite needs, wired against a private defaults suite.
///
/// The prayer manager and the suite share one `Preferences`, so a value written by a
/// test is the value the manager reads.
struct PrayTestFixture {
    let log: LogManager
    let preferences: Preferences
    let prayerManager: PrayerManager

    init() {
        let log = LogManager(services: [LogServiceConsole(minLevel: .none, subsystem: "PrayKitTests")])
        let preferences = Preferences(defaults: .makeTest())

        self.log = log
        self.preferences = preferences

        prayerManager = PrayerManager(
            service: PrayerServiceAdhan(log: log),
            londonService: PrayerServiceLondon(
                networkManager: NetworkManager(service: NetworkServiceFoundation()),
                apiKey: "{{your api key}}",
                log: log
            ),
            preferences: preferences,
            log: log
        )
    }
}
