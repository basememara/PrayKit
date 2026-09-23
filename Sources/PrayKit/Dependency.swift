//
//  PrayKitDependency.swift
//  PrayKit
//
//  Created by Basem Emara on 2019-06-11.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import PrayCore
import Foundation.NSUserDefaults
import ZamzamCore
import ZamzamLocation

/// A dependency container where types conform to provide concrete instances.
public protocol PrayKitDependency {
    // Settings
    func constants() -> Constants
    func preferences() -> Preferences
    func localStorage() -> UserDefaults

    // Network
    func networkManager() -> NetworkManager
    func networkService() -> NetworkService
    func networkAdapter() -> URLRequestAdapter?

    // Services
    func prayerManager() -> PrayerManager
    func prayerService() -> PrayerService
    func prayerServiceLondon() -> PrayerService

    func qiblaService() -> QiblaService
    func hijriService() -> HijriService
    func notificationService() -> NotificationService

    // Location services drive UI and run on the main actor
    @MainActor func locationManager() -> LocationManager
    @MainActor func locationService() -> LocationService

    // Diagnostics
    func log() -> LogManager
    func logServices() -> [LogService]
}
