//
//  PrayError.swift
//  PrayWatch
//
//  Created by Basem Emara on 2019-06-21.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

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
