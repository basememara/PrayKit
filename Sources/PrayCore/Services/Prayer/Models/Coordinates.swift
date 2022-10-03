//
//  Coordinates.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-05-19.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import CoreLocation.CLLocation
import Foundation.NSMeasurement
import ZamzamCore

public struct Coordinates: Equatable, Codable {
    public let latitude: Double
    public let longitude: Double

    // About 100 meters accuracy
    // https://gis.stackexchange.com/a/8674
    private static let decimalPrecision = 3

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude.rounded(toPlaces: Self.decimalPrecision)
        self.longitude = longitude.rounded(toPlaces: Self.decimalPrecision)
    }

    public init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude.rounded(toPlaces: Self.decimalPrecision)
        self.longitude = coordinate.longitude.rounded(toPlaces: Self.decimalPrecision)
    }
}

// MARK: - Helpers

public extension Coordinates {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Conformances

extension Coordinates: CustomStringConvertible {
    private func format(number: Double) -> String {
        let degrees = Measurement(value: number.rounded(toPlaces: 2), unit: UnitAngle.degrees)
        return degrees.formatted(.measurement(width: .narrow))
    }

    public var description: String {
        String(format: "%@, %@", format(number: latitude), format(number: longitude))
    }
}
