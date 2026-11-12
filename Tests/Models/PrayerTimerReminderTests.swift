//
//  PrayerTimerReminderTests.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import PrayCore
import Testing

// MARK: - The Reminder of the Prayer Counted To

extension PrayerTimerTests {
    /// 25 minutes before the khutba, over the 80 minutes from Dhuhr's adhan to it.
    @Test(arguments: [(30, 10), (10, 30)])
    func theWarningBeforeTheKhutbaIsAsLongAsDhuhrsReminder(dhuhrMinutes: Int, asrMinutes: Int) throws {
        let prayerTimer = try prayerTimer(
            at: friday(hour: 13, minute: 5),
            preAdhanMinutes: PreAdhanMinutes(rawValue: ["dhuhr": dhuhrMinutes, "asr": asrMinutes])
        )

        #expect(prayerTimer.type == .dhuhr)
        #expect(prayerTimer.timerType == .iqama)
        #expect(prayerTimer.countdownDate == friday(hour: 13, minute: 30))
        #expect(prayerTimer.isDangerZone == (dhuhrMinutes >= 25))
        #expect(abs(prayerTimer.dangerZone - (Double(dhuhrMinutes) / 80)) <= 0.0001)
    }
}
