//
//  PrayerAPI.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-11.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate
import Foundation.NSDateInterval
import Foundation.NSTimeZone

public protocol PrayerService {
    func calculate(for date: Date, using calendar: Calendar, with request: PrayerAPI.Request) async throws -> [PrayerTime]
}

// MARK: - Namespace

public enum PrayerAPI {}

public extension PrayerAPI {
    struct Request: Equatable, Codable {
        public let coordinates: Coordinates
        public let timeZone: TimeZone
        public let method: CalculationMethod
        public let jurisprudence: Madhab
        public let elevation: ElevationRule?
        public let fajrDegrees: Double?
        public let maghribDegrees: Double?
        public let ishaDegrees: Double?
        public let adjustments: PrayerAdjustments?
        public let filter: PrayerFilter

        public init(
            coordinates: Coordinates,
            timeZone: TimeZone,
            method: CalculationMethod,
            jurisprudence: Madhab = .standard,
            elevation: ElevationRule? = nil,
            fajrDegrees: Double? = nil,
            maghribDegrees: Double? = nil,
            ishaDegrees: Double? = nil,
            adjustments: PrayerAdjustments? = nil,
            filter: PrayerFilter = .all
        ) {
            self.coordinates = coordinates
            self.timeZone = timeZone
            self.method = method
            self.jurisprudence = jurisprudence
            self.elevation = elevation
            self.fajrDegrees = fajrDegrees
            self.maghribDegrees = maghribDegrees
            self.ishaDegrees = ishaDegrees
            self.adjustments = adjustments
            self.filter = filter
        }

        public init?(
            from preferences: Preferences,
            coordinates: Coordinates? = nil,
            timeZone: TimeZone? = nil,
            method: CalculationMethod? = nil,
            filter: PrayerFilter = .all
        ) {
            guard let coordinates = coordinates ?? preferences.prayersCoordinates else {
                return nil
            }

            self.coordinates = coordinates
            self.timeZone = timeZone ?? preferences.lastTimeZone
            self.method = method ?? preferences.calculationMethod
            self.jurisprudence = preferences.juristicMethod
            self.elevation = preferences.elevationRule
            self.fajrDegrees = preferences.fajrDegrees
            self.maghribDegrees = preferences.maghribDegrees
            self.ishaDegrees = preferences.ishaDegrees
            self.adjustments = PrayerAdjustments(
                adjustmentMinutes: preferences.adjustmentMinutes,
                adjustmentElevation: preferences.adjustmentElevation
            )
            self.filter = filter
        }
    }
}

public extension PrayerAPI {
    struct TimelineEntry: Equatable, Codable {
        public let date: Date
        public let prayerDay: PrayerDay

        public init(date: Date, prayerDay: PrayerDay) {
            self.date = date
            self.prayerDay = prayerDay
        }
    }
}
