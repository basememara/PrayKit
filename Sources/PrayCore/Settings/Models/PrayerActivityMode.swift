//
//  PrayerActivityMode.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-11-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

/// When this device shows the prayer's Live Activity.
public enum PrayerActivityMode: String, Equatable, CaseIterable, Codable, Sendable {
    case off
    /// Before every prayer, on the Lock Screen and in the Dynamic Island.
    case always
    /// Only while the phone is in the car, started and ended by Shortcuts automations on CarPlay.
    case inCar
}

extension PrayerActivityMode: Identifiable {
    public var id: String { rawValue }
}
