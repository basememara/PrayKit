//
//  MapTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import CoreLocation
import PrayCore
import Testing

struct MapTests {
    private let kualaLumpur = CLLocationCoordinate2D(latitude: 3.139, longitude: 101.6869)
    private let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

    @Test
    func theSearchForMosquesIsTheMapsOwnAddress() {
        #expect(Map.google.nearestMasjidURL().absoluteString == "https://www.google.com/maps/search/?api=1&query=mosque")
        #expect(Map.apple.nearestMasjidURL().absoluteString == "http://maps.apple.com/?q=mosque")
    }

    @Test
    func theSearchForMosquesIsCenteredOnACoordinate() {
        #expect(Map.google.nearestMasjidURL(from: kualaLumpur).absoluteString == "https://www.google.com/maps/search/?api=1&query=mosque&center=3.139,101.6869")
        #expect(Map.google.nearestMasjidURL(from: london).absoluteString == "https://www.google.com/maps/search/?api=1&query=mosque&center=51.5074,-0.1278")
        #expect(Map.apple.nearestMasjidURL(from: london).absoluteString == "http://maps.apple.com/?q=mosque&sll=51.5074,-0.1278")
    }
}
