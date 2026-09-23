//
//  QiblaInterfaces.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-07-12.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import CoreLocation.CLLocation
import ZamzamCore

public protocol QiblaService: Sendable {
    func fetch(with request: QiblaAPI.DirectionRequest) -> Qibla
}

// MARK: - Namespace

public enum QiblaAPI {}

public extension QiblaAPI {
    struct DirectionRequest: Sendable {
        public let coordinate: CLLocationCoordinate2D

        public init(coordinate: CLLocationCoordinate2D) {
            self.coordinate = coordinate
        }
    }
}
