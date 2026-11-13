//
//  TestFixture.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation
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
            timetables: [
                .london: PrayerServiceTimetable.london(
                    apiKey: "",
                    networkManager: NetworkManager(service: OfflineNetwork()),
                    directory: .temporaryDirectory.appending(path: "PrayKitTests-Timetables-\(UUID().uuidString)", directoryHint: .isDirectory),
                    log: log
                )
            ],
            log: log
        )
    }
}

/// No suite reaches a real timetable API: a table it would fetch fails as it does offline.
struct OfflineNetwork: NetworkService {
    func send(_ request: URLRequest) async throws -> NetworkResponse {
        throw URLError(.notConnectedToInternet)
    }
}
