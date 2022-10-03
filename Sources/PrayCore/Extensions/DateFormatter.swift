//
//  DateFormatter.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-02-23.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation.NSLocale
import Foundation.NSDateFormatter
import ZamzamCore

public extension DateFormatter {
    /// Create a time formatter for 24hr notion, i.e. 23:43.
    static func time24Hrs(using timeZone: TimeZone) -> DateFormatter {
        DateFormatter(dateFormatTemplate: "Hmm", timeZone: timeZone)
    }

    /// Create a time formatter for short notion, i.e. 8:43.
    static func timeShort(using timeZone: TimeZone) -> DateFormatter {
        DateFormatter(dateFormatTemplate: "hmm", timeZone: timeZone).apply {
            $0.amSymbol = ""
            $0.pmSymbol = ""
        }
    }

    /// Create a time formatter, i.e. 8:43 AM.
    static func timeAMPM(using timeZone: TimeZone) -> DateFormatter {
        DateFormatter(dateFormatTemplate: "hmm", timeZone: timeZone)
    }
}
