//
//  DateInterval.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-28.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation

public extension DateInterval {
    /// Returns the total, remaining, percentage countdown between the date interval.
    func countdown(at date: Date) -> (total: Double, remaining: Double, percent: Double)? {
        let seconds = end.timeIntervalSince(start)
        let remaining = end.timeIntervalSince(date)

        guard remaining > 0 else { return (seconds, 0, 0) }
        let percent = (remaining / seconds).rounded(toPlaces: 2)
        return (seconds, remaining, percent)
    }
}
