//
//  PrayError.swift
//  PrayWatch
//
//  Created by Basem Emara on 2019-06-21.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import ZamzamLocation

public enum PrayError: Error {
    case invalidParameters
    case invalidTimes
    case invalidElevation
    case locationDenied
    case locationFailure
    case noInternet
    case compassFailure
    case notificationsDenied
    case backgroundRefreshDenied
    case unknownReason(Error?)
}

public extension PrayError {
    init(_ error: LocationError) {
        switch error {
        case .denied:
            self = .locationDenied
        case .unavailable:
            self = .locationFailure
        }
    }
}
