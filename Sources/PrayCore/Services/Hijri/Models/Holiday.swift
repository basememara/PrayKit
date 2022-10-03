//
//  Holiday.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-03-17.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

public struct Holiday: Identifiable, Equatable {
    public let id: String
    public let month: Int
    public let day: Int

    public init(
        id: String,
        month: Int,
        day: Int
    ) {
        self.id = id
        self.month = month
        self.day = day
    }
}
