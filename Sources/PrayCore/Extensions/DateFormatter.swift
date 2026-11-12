//
//  DateFormatter.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-02-23.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation.NSDateFormatter
import Foundation.NSLocale
import ZamzamCore

public extension DateFormatter {
    /// Creates the formatter every prayer time is written with, on the clock of a place's time zone.
    ///
    /// A 24-hour time is written as the locale writes one, such as 23:43, and `showsPeriod` has no effect on it. A
    /// 12-hour time without its period, 8:43 for 8:43 AM, is the locale's 12-hour time with AM and PM blanked, so it
    /// keeps whatever the locale writes beside them: in US English, the narrow no-break space before them. Without a
    /// `locale` the formatter keeps its own, the device's with the user's 12 or 24-hour choice.
    static func prayerTime(is24Hour: Bool, showsPeriod: Bool = true, using timeZone: TimeZone, locale: Locale? = nil) -> DateFormatter {
        DateFormatter(dateFormatTemplate: is24Hour ? "Hmm" : "hmm", timeZone: timeZone, locale: locale).apply {
            guard !is24Hour, !showsPeriod else { return }
            $0.amSymbol = ""
            $0.pmSymbol = ""
        }
    }
}
