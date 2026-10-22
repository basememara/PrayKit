//
//  Qibla.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-07-12.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

public struct Qibla: Codable, Sendable {
    /// Degrees clockwise from true north.
    public let direction: Double
    /// Metres to the Kaaba along the earth's surface.
    public let distance: Double

    public init(direction: Double, distance: Double) {
        self.direction = direction
        self.distance = distance
    }
}

public extension Coordinates {
    /// The Kaaba in Makkah, as the Qibla direction is calculated toward it.
    static let kaaba = Coordinates(latitude: 21.4225241, longitude: 39.8261818)
}
