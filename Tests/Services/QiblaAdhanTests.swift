//
//  QiblaAdhanTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2022-04-29.
//

import CoreLocation
import PrayCore
import PrayServices
import Foundation
import Testing

struct QiblaAdhanTests {
    private let qiblaService = QiblaServiceAdhan()

    @Test
    func directionForAntwerp() {
        // Given
        let coordinate = CLLocationCoordinate2D(
            latitude: 51.2901,
            longitude: 4.4916
        )

        // When
        let request = QiblaAPI.DirectionRequest(coordinate: coordinate)
        let qibla = qiblaService.fetch(with: request)

        // Then
        #expect(abs(qibla.direction - 124) <= 1)
    }

    /// About 4,508 km on a sphere; the ellipsoid the device measures on moves it by a few kilometres.
    @Test
    func distanceForAntwerp() {
        let request = QiblaAPI.DirectionRequest(coordinate: CLLocationCoordinate2D(latitude: 51.2901, longitude: 4.4916))
        let qibla = qiblaService.fetch(with: request)

        #expect(abs(qibla.distance / 1000 - 4508) <= 25)
    }

    @Test
    func noDistanceAtTheKaaba() {
        let request = QiblaAPI.DirectionRequest(coordinate: Coordinates.kaaba.location)
        let qibla = qiblaService.fetch(with: request)

        #expect(qibla.distance < 100)
    }
}
