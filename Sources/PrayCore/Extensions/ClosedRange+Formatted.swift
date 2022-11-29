//
//  ClosedRange+Formatted.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-11-29.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation.NSDate

public extension ClosedRange<Date> {
    /// Formats the date range using the specified style.
    func formatted<S>(_ style: S) -> S.FormatOutput where S: FormatStyle, S.FormatInput == Range<Date> {
        (lowerBound..<upperBound).formatted(style)
    }
}
