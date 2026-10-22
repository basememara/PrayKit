//
//  Holiday.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-03-17.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation

public struct Holiday: Identifiable, Equatable, Sendable {
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

public extension Holiday {
    /// The day the holiday falls on in a Hijri year, as dated with the user's Hijri day offset.
    func date(inYear year: Int, offset: Int) -> Date? {
        Date(hijriYear: year, month: month, day: day, offset: offset)
    }
}
