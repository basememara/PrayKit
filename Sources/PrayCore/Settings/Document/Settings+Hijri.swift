//
//  Settings+Hijri.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import ZamzamCore

public extension Settings {
    /// Today's Hijri date at `moment`, in the locale's format for `template`: the date `hijriDayOffset` days on, and
    /// with `autoIncrementHijri` a day further once Maghrib has begun. `prayerDay` is the day holding `moment`; one
    /// that doesn't hold it leaves the Maghrib turn out, as a day being browsed does.
    func hijriString(
        at moment: Date,
        in prayerDay: PrayerDay,
        timeZone: TimeZone,
        template: String = "yyyyMMMMd",
        locale: Locale = .current
    ) -> String {
        moment.hijriString(
            template: template,
            offset: hijriOffset(at: moment, in: prayerDay, timeZone: timeZone),
            timeZone: timeZone,
            locale: locale
        )
    }

    /// Today's Hijri day then its month at `moment`, such as 27 Raj., in every locale, turning at Maghrib as
    /// `hijriString` does.
    func hijriDayAndMonth(
        at moment: Date,
        in prayerDay: PrayerDay,
        timeZone: TimeZone,
        locale: Locale = .current
    ) -> String {
        moment.hijriDayAndMonth(
            offset: hijriOffset(at: moment, in: prayerDay, timeZone: timeZone),
            timeZone: timeZone,
            locale: locale
        )
    }
}

private extension Settings {
    func hijriOffset(at moment: Date, in prayerDay: PrayerDay, timeZone: TimeZone) -> Int {
        moment.hijriDayOffset(
            for: prayerDay,
            hijriDayOffset: hijriDayOffset,
            autoIncrementHijri: autoIncrementHijri,
            timeZone: timeZone
        )
    }
}
