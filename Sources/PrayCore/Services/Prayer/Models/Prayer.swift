//
//  Prayer.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-11.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate

public enum Prayer: String, Codable, Equatable, CaseIterable, Sendable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha
    case midnight
    case lastThird
}

// MARK: - Conformances

extension Prayer: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Helpers

public extension Prayer {
    var isObligation: Bool { [.fajr, .dhuhr, .asr, .maghrib, .isha].contains(self) }
    var isEssential: Bool { isObligation || self == .sunrise }
}
