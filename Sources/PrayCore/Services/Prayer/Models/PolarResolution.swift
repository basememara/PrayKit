//
//  PolarResolution.swift
//  PrayCore
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

/// Where a day's times come from when the sun doesn't rise, set or reach a prayer's angle, near the polar circles.
public enum PolarResolution: String, CaseIterable, Equatable, Codable, Sendable {
    /// The nearest latitude toward the equator where the day can be calculated.
    case nearestLatitude = "AqrabBalad"
    /// The nearest day, before or after, that can be calculated at the place.
    case nearestDay = "AqrabYaum"
}

public extension PolarResolution {
    /// Whether a day at the place can borrow its times with these settings: under every method from 65.5°, and from
    /// 57° under one that times Maghrib by an angle, whose Maghrib can fall within 5 minutes of Isha in summer.
    static func applies(at place: Place, with settings: Settings) -> Bool {
        let latitude = abs(place.coordinates.latitude)
        return latitude >= 65.5 || (latitude >= 57 && settings.method(at: place).timesMaghribByAngle(with: settings))
    }
}

private extension CalculationMethod {
    func timesMaghribByAngle(with settings: Settings) -> Bool {
        switch self {
        case .tehran, .shia:
            true
        case .custom:
            settings.maghribDegrees > 0
        default:
            false
        }
    }
}

// MARK: - Conformances

extension PolarResolution: Identifiable {
    public var id: String { rawValue }
}
