//
//  Map.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-15.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import CoreLocation
import ZamzamCore

public enum Map: Int, Equatable, CaseIterable, Sendable {
    case apple
    case google
}

// MARK: - Conformances

extension Map: Identifiable {
    public var id: Int { rawValue }
}

// MARK: - Services

public extension Map {
    /// The map's search for mosques, centered on the coordinate when one is given.
    func nearestMasjidURL(from coordinate: CLLocationCoordinate2D? = nil) -> URL {
        let (search, center): (URL, String) = switch self {
        case .apple:
            (URL(safeString: "http://maps.apple.com/?q=mosque"), "sll")
        case .google:
            (URL(safeString: "https://www.google.com/maps/search/?api=1&query=mosque"), "center")
        }

        guard let coordinate else { return search }

        return search.appending(
            queryItems: [URLQueryItem(name: center, value: "\(coordinate.latitude),\(coordinate.longitude)")]
        )
    }
}
