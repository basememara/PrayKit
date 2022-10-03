//
//  Map.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-15.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import CoreLocation

public enum Map: Int, Equatable, CaseIterable {
    case apple
    case google
}

// MARK: - Conformances

extension Map: Identifiable {
    public var id: Int { rawValue }
}

// MARK: - Services

public extension Map {
    func nearestMasjidURL(from coordinate: CLLocationCoordinate2D? = nil) -> String {
        var url = ""

        switch self {
        case .apple:
            url = "http://maps.apple.com/?q=mosque"
            if let coordinate {
                url += "&sll=\(coordinate.latitude),\(coordinate.longitude)"
            }
        case .google:
            url = "https://www.google.com/maps/search/?api=1&query=mosque"
            if let coordinate {
                url += "&center=\(coordinate.latitude),\(coordinate.longitude)"
            }
        }

        return url
    }
}
