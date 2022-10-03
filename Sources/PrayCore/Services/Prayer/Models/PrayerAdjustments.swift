//
//  PrayerAdjustments.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public struct PrayerAdjustments: Equatable, Codable {
    public let fajr: Int
    public let sunrise: Int
    public let dhuhr: Int
    public let asr: Int
    public let maghrib: Int
    public let isha: Int
    public let isFajrSunriseRelative: Bool
    public let isIshaMaghribRelative: Bool
    public let elevation: ElevationRule?

    public init(
        fajr: Int,
        sunrise: Int,
        dhuhr: Int,
        asr: Int,
        maghrib: Int,
        isha: Int,
        isFajrSunriseRelative: Bool,
        isIshaMaghribRelative: Bool,
        elevation: ElevationRule?
    ) {
        self.fajr = fajr
        self.sunrise = sunrise
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.isFajrSunriseRelative = isFajrSunriseRelative
        self.isIshaMaghribRelative = isIshaMaghribRelative
        self.elevation = elevation
    }

    public init(
        adjustmentMinutes: AdjustmentMinutes?,
        adjustmentElevation: ElevationRule?
    ) {
        self.init(
            fajr: adjustmentMinutes?[.fajr] ?? 0,
            sunrise: adjustmentMinutes?[.sunrise] ?? 0,
            dhuhr: adjustmentMinutes?[.dhuhr] ?? 0,
            asr: adjustmentMinutes?[.asr] ?? 0,
            maghrib: adjustmentMinutes?[.maghrib] ?? 0,
            isha: adjustmentMinutes?[.isha] ?? 0,
            isFajrSunriseRelative: adjustmentMinutes?.isFajrSunriseRelative ?? false,
            isIshaMaghribRelative: adjustmentMinutes?.isIshaMaghribRelative ?? false,
            elevation: adjustmentElevation
        )
    }
}

public extension PrayerAdjustments {
    var isEmpty: Bool {
        fajr == 0
            && sunrise == 0
            && dhuhr == 0
            && asr == 0
            && maghrib == 0
            && isha == 0
            && elevation == nil
    }
}

extension PrayerAdjustments: CustomStringConvertible {
    public var description: String {
        """
        [
            fajr: \(fajr),
            sunrise: \(sunrise),
            dhuhr: \(dhuhr),
            asr: \(asr),
            maghrib: \(maghrib),
            isha: \(isha),
            is_fajr_sunrise_relative: \(isFajrSunriseRelative.description),
            is_isha_maghrib_relative: \(isIshaMaghribRelative.description),
            elevation: \(elevation?.rawValue ?? "none")
        ]
        """
    }
}
