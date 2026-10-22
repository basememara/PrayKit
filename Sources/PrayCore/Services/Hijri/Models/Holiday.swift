//
//  Holiday.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-03-17.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation
import ZamzamCore

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
    /// The day the holiday falls on in a Hijri year, as dated with the user's Hijri day offset: an offset that shows
    /// the Hijri date a day ahead brings the holiday a day sooner.
    func date(inYear year: Int, offset: Int) -> Date? {
        let calendar = Date.islamicCalendar
        return DateComponents(calendar: calendar, year: year, month: month, day: day).date
            .flatMap { calendar.date(byAdding: .day, value: -offset, to: $0) }
    }
}
