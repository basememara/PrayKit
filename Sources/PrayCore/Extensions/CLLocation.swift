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
    /// - Parameters:
    ///   - completion: Async callback with retrived location details.
    func geocoder(completion: @escaping (String?, TimeZone?) -> Void) {
        geocoder { (meta: LocationMeta?) in
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

            completion(region, meta?.timeZone)
        }
    }

    /// Retrieves region details for coordinates.
    ///
    /// - Parameters:
    ///   - completion: Async callback with retrived location details.
    func geocoder() async -> (String?, TimeZone?) {
        await withCheckedContinuation { continuation in
            geocoder { continuation.resume(returning: ($0, $1)) }
        }
    }
}
