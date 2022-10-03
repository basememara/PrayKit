//
//  QiblaAdhanTests.swift
//  PrayServicesTests
//
//  Created by Basem Emara on 2022-04-29.
//

import XCTest
import CoreLocation
import PrayCore
import PrayServices

final class QiblaAdhanTests: TestCase {
    private let qiblaService = QiblaServiceAdhan()
}

extension QiblaAdhanTests {
    func testLocation() async throws {
        // Given
        let coordinate = CLLocationCoordinate2D(
            latitude: 51.2901,
            longitude: 4.4916
        )

        // When
        let request = QiblaAPI.DirectionRequest(coordinate: coordinate)
        let qibla = qiblaService.fetch(with: request)

        // Then
        XCTAssertEqual(qibla.direction, 124, accuracy: 1)
    }
}
