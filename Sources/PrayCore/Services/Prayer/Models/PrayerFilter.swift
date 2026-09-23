//
//  FilterType.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public enum PrayerFilter: String, Equatable, Codable, Sendable {
    case all
    case obligation
    case essential
    case sunnah
}
