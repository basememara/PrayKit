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
struct PrayTestFixture {
    let log: LogManager
    let storage: SettingsStorage
    let prayerManager: PrayerManager

    init() {
        let log = LogManager(services: [LogServiceConsole(minLevel: .none, subsystem: "PrayKitTests")])

        self.log = log
        storage = SettingsStorage(defaults: .makeTest())

        prayerManager = PrayerManager(
            service: PrayerServiceAdhan(log: log),
            londonService: PrayerServiceLondon(
                networkManager: NetworkManager(service: NetworkServiceFoundation()),
                apiKey: "{{your api key}}",
                log: log,
                defaults: .makeTest()
            ),
            log: log
        )
    }
}
