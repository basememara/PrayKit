//
//  CalculationParameters.swift
//  PrayServices
//
//  Created by Basem Emara on 2021-06-28.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Adhan
import PrayCore

extension CalculationParameters {
    // swiftlint:disable:next function_body_length
    init(from request: PrayerAPI.Request) {
        switch request.method {
        case .muslimWorldLeague:
            self = Adhan.CalculationMethod.muslimWorldLeague.params
        case .northAmerica:
            self = Adhan.CalculationMethod.northAmerica.params
        case .moonsightingCommittee:
            self = Adhan.CalculationMethod.moonsightingCommittee.params
        case .egyptian:
            self = Adhan.CalculationMethod.egyptian.params
        case .algerian:
            self = Adhan.CalculationMethod.other.params
            // http://www.marw.dz
            self.fajrAngle = 18
            self.ishaAngle = 17
        case .tunisian:
            self = Adhan.CalculationMethod.other.params
            // http://www.affaires-religieuses.tn/public/ar
            self.fajrAngle = 18
            self.ishaAngle = 18
        case .ummAlQura:
            self = Adhan.CalculationMethod.ummAlQura.params
        case .ummAlQuraRamadan:
            self = Adhan.CalculationMethod.ummAlQura.params
        case .dubai:
            self = Adhan.CalculationMethod.dubai.params
        case .kuwait:
            self = Adhan.CalculationMethod.kuwait.params
        case .qatar:
            self = Adhan.CalculationMethod.qatar.params
        case .karachi:
            self = Adhan.CalculationMethod.karachi.params
        case .singapore:
            self = Adhan.CalculationMethod.singapore.params
        case .jakim:
            self = Adhan.CalculationMethod.singapore.params
        case .indonesia:
            self = Adhan.CalculationMethod.other.params
            // https://github.com/cpfair/pebble-qibla-www/blob/master/praytimes.py
            self.fajrAngle = 20
            self.ishaAngle = 18
            self.adjustments.fajr = 2
            self.adjustments.sunrise = -2
            self.adjustments.dhuhr = 3
            self.adjustments.asr = 2
            self.adjustments.maghrib = 2
            self.adjustments.isha = 2
        case .turkey:
            self = Adhan.CalculationMethod.turkey.params
        case .morocco:
            self = Adhan.CalculationMethod.other.params
            // https://www.habous.gov.ma
            // https://github.com/Five-Prayers/five-prayers-android/blob/main/app/src/main/java/com/hbouzidi/fiveprayers/timings/calculations/CalculationMethodEnum.java
            self.fajrAngle = 19.1
            self.ishaAngle = 17
            self.adjustments.dhuhr = 5
            self.adjustments.maghrib = 4
        case .tehran:
            self = Adhan.CalculationMethod.tehran.params
        case .uiof:
            self = Adhan.CalculationMethod.other.params
            self.fajrAngle = 12
            self.ishaAngle = 12
            self.highLatitudeRule = .twilightAngle
        case .france15:
            self = Adhan.CalculationMethod.other.params
            self.fajrAngle = 15
            self.ishaAngle = 15
            self.highLatitudeRule = .twilightAngle
        case .france18:
            self = Adhan.CalculationMethod.other.params
            self.fajrAngle = 18
            self.ishaAngle = 18
            self.highLatitudeRule = .twilightAngle
        case .russia:
            self = Adhan.CalculationMethod.other.params
            self.fajrAngle = 16
            self.ishaAngle = 15
            self.highLatitudeRule = .twilightAngle
        case .shia:
            self = Adhan.CalculationMethod.other.params
            self.fajrAngle = 16
            self.maghribAngle = 4
            self.ishaAngle = 14
        case .london:
            // https://www.londonprayertimes.com
            self = Adhan.CalculationMethod.other.params
        case .custom:
            self = Adhan.CalculationMethod.other.params
            self.fajrAngle = request.fajrDegrees ?? 0
            self.maghribAngle = request.maghribDegrees ?? 0
            self.ishaAngle = request.ishaDegrees ?? 0

            switch request.elevation {
            case .middleOfTheNight:
                self.highLatitudeRule = .middleOfTheNight
            case .seventhOfTheNight:
                self.highLatitudeRule = .seventhOfTheNight
            case .twilightAngle:
                self.highLatitudeRule = .twilightAngle
            case nil:
                break
            }
        }

        switch request.jurisprudence {
        case .standard:
            self.madhab = .shafi
        case .hanafi:
            self.madhab = .hanafi
        }

        if let adjustments = request.adjustments, !adjustments.isEmpty {
            if adjustments.fajr != 0, !adjustments.isFajrSunriseRelative {
                self.adjustments.fajr += adjustments.fajr
            }

            if adjustments.sunrise != 0 {
                self.adjustments.sunrise += adjustments.sunrise
            }

            if adjustments.dhuhr != 0 {
                self.adjustments.dhuhr += adjustments.dhuhr
            }

            if adjustments.asr != 0 {
                self.adjustments.asr += adjustments.asr
            }

            if adjustments.maghrib != 0 {
                self.adjustments.maghrib += adjustments.maghrib
            }

            if adjustments.isha != 0, !adjustments.isIshaMaghribRelative {
                self.adjustments.isha += adjustments.isha
            }

            if let elevation = adjustments.elevation, request.method != .custom {
                switch elevation {
                case .middleOfTheNight:
                    self.highLatitudeRule = .middleOfTheNight
                case .seventhOfTheNight:
                    self.highLatitudeRule = .seventhOfTheNight
                case .twilightAngle:
                    self.highLatitudeRule = .twilightAngle
                }
            }
        }
    }
}
