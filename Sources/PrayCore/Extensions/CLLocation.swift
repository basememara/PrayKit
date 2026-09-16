//
//  CLLocation.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-06-23.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import CoreLocation.CLLocation
import ZamzamCore

public extension CLLocation {
    /// Retrieves region details for coordinates.
    ///
    /// - Parameter timeout: A timeout after which the lookup gives up. Default is 10 seconds.
    /// - Returns: The display name of the region and its time zone, either of which may be `nil`.
    func geocoder(timeout: TimeInterval = 10) async -> (String?, TimeZone?) {
        let meta: LocationMeta? = await geocoder(timeout: timeout)
        let region: String?

        switch (meta?.locality, meta?.administrativeArea, meta?.country) {
        case let (.some(city), .some(state), _):
            region = 1...3 ~= state.count ? "\(city), \(state)" : city
        case let (.some(city), _, .some(country)) where city != country:
            region = "\(city), \(country)"
        case let (.some(city), _, _):
            region = city
        case let (_, _, .some(country)):
            region = country
        default:
            region = nil
        }

        return (region, meta?.timeZone)
    }
}
