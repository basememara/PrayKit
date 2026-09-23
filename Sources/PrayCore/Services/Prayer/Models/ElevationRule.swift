//
//  ElevationRule.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public enum ElevationRule: String, CaseIterable, Equatable, Codable, Sendable {
    case middleOfTheNight = "NightMiddle"
    case seventhOfTheNight = "OneSeventh"
    case twilightAngle = "AngleBased"
}

// MARK: - Conformances

extension ElevationRule: Identifiable {
    public var id: String { rawValue }
}
