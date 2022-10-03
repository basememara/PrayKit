//
//  Qibla.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-07-12.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

public struct Qibla: Codable {
    public let direction: Double

    public init(direction: Double) {
        self.direction = direction
    }
}
