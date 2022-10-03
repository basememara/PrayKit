//
//  QiblaServiceAdhan.swift
//  PrayServices
//
//  Created by Basem Emara on 2019-07-12.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Adhan
import PrayCore
import ZamzamCore

public struct QiblaServiceAdhan: QiblaService {
    public init() {}
}

public extension QiblaServiceAdhan {
    func fetch(with request: QiblaAPI.DirectionRequest) -> PrayCore.Qibla {
        let coordinates = Adhan.Coordinates(
            latitude: request.coordinate.latitude,
            longitude: request.coordinate.longitude
        )

        let model = PrayCore.Qibla(
            direction: Adhan.Qibla(coordinates: coordinates).direction
        )

        return model
    }
}
