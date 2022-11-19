//
//  PostAdhanMinutes.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public struct PostAdhanMinutes: Equatable, Codable {
    public let fajr: Int
    public let dhuhr: Int
    public let asr: Int
    public let maghrib: Int
    public let isha: Int

    public init(
        fajr: Int,
        dhuhr: Int,
        asr: Int,
        maghrib: Int,
        isha: Int
    ) {
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
    }
}

public extension PostAdhanMinutes {
    subscript(_ prayer: Prayer) -> Int {
        switch prayer {
        case .fajr:
            return fajr
        case .dhuhr:
            return dhuhr
        case .asr:
            return asr
        case .maghrib:
            return maghrib
        case .isha:
            return isha
        default:
            return 0
        }
    }
}

public extension PostAdhanMinutes {
    var isEmpty: Bool {
        fajr == 0
            && dhuhr == 0
            && asr == 0
            && maghrib == 0
            && isha == 0
    }
}

extension PostAdhanMinutes: CustomStringConvertible {
    public var description: String {
        """
        [
            fajr: \(fajr),
            dhuhr: \(dhuhr),
            asr: \(asr),
            maghrib: \(maghrib),
            isha: \(isha)
        ]
        """
    }
}
