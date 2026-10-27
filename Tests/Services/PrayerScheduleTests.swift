//
//  PrayerScheduleTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import PrayServices
import Testing
import ZamzamCore

/// The timeline built from a `Settings` value stays the one recorded for the same inputs.
struct PrayerScheduleTests {
    private let fixture = PrayTestFixture()

    @Test(arguments: RecordedTimeline.all)
    func settingsBuildTheRecordedTimeline(recorded: RecordedTimeline) async throws {
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let formatter = DateFormatter(dateFormat: "yyyy/MM/dd HH:mm:ss", timeZone: timeZone, calendar: Calendar(identifier: .gregorian), locale: .posix)
        let date = try #require(formatter.date(from: "2022/02/25 06:00:00"))
        let place = Place(coordinates: Coordinates(latitude: 43.651070, longitude: -79.347015), timeZone: timeZone, regionName: nil, fixedAt: nil)

        var settings = Settings()
        settings.calculationMethod = .northAmerica
        settings.preAdhanMinutes = PreAdhanMinutes(rawValue: ["fajr": 34, "sunrise": 27, "dhuhr": 14, "asr": 16, "maghrib": 22, "isha": 9])
        settings.iqamaTimes = IqamaTimes(
            fajr: .time(hour: 6, minutes: 31),
            dhuhr: .minutes(12),
            asr: .time(hour: 16, minutes: 38),
            maghrib: .minutes(8),
            isha: nil,
            jumuah: .time(hour: 13, minutes: 30)
        )
        settings.stopwatchMinutes = 18
        settings.sunriseAfterIsha = true

        let timeline = try await fixture.prayerManager.fetch(
            from: date,
            expanded: recorded.expanded,
            limit: 40,
            with: try #require(PrayerAPI.Request(settings: settings, place: place)),
            settings: settings,
            timeZone: timeZone
        )

        #expect(timeline.map { "\(formatter.string(from: $0.date)) \($0.type.rawValue) \($0.timerType.rawValue)" } == recorded.timeline)
        #expect(zip(timeline, timeline.dropFirst()).allSatisfy { $0.date < $1.date })
    }

    @Test
    func aRequestNeedsAPlace() {
        #expect(PrayerAPI.Request(settings: Settings(), place: nil) == nil)
    }
}

/// A timeline recorded from the settings-built schedule: each timer's date in New York, prayer and timer type.
struct RecordedTimeline: Sendable, CustomTestStringConvertible {
    let expanded: PrayerManager.Expanded
    let timeline: [String]

    var testDescription: String { "\(expanded)" }
}

private extension RecordedTimeline {
    static let all = [
        RecordedTimeline(
            expanded: .none,
            timeline: [
                "2022/02/25 05:42:00 fajr stopwatch",
                "2022/02/25 06:00:00 fajr iqama",
                "2022/02/25 07:00:00 dhuhr iqama",
                "2022/02/25 12:31:00 dhuhr stopwatch",
                "2022/02/25 15:32:00 asr stopwatch",
                "2022/02/25 18:01:00 maghrib iqama",
                "2022/02/25 19:20:00 isha stopwatch",
                "2022/02/25 23:51:00 fajr iqama",
                "2022/02/26 00:00:00 fajr iqama",
                "2022/02/26 01:47:00 fajr iqama",
                "2022/02/26 05:40:00 fajr stopwatch",
                "2022/02/26 06:59:00 dhuhr countdown",
                "2022/02/26 12:31:00 dhuhr stopwatch",
                "2022/02/26 15:33:00 asr stopwatch",
                "2022/02/26 18:02:00 maghrib iqama",
                "2022/02/26 19:21:00 isha stopwatch",
                "2022/02/26 23:51:00 fajr iqama",
                "2022/02/27 00:00:00 fajr iqama",
                "2022/02/27 01:47:00 fajr iqama",
                "2022/02/27 05:39:00 fajr stopwatch",
                "2022/02/27 06:57:00 dhuhr countdown",
                "2022/02/27 12:31:00 dhuhr stopwatch",
                "2022/02/27 15:34:00 asr stopwatch",
                "2022/02/27 18:04:00 maghrib iqama",
                "2022/02/27 19:22:00 isha stopwatch",
                "2022/02/27 23:51:00 fajr iqama",
                "2022/02/28 00:00:00 fajr iqama",
                "2022/02/28 01:46:00 fajr iqama",
                "2022/02/28 05:37:00 fajr stopwatch",
                "2022/02/28 06:56:00 dhuhr countdown",
                "2022/02/28 12:31:00 dhuhr stopwatch",
                "2022/02/28 15:35:00 asr stopwatch",
                "2022/02/28 18:05:00 maghrib iqama",
                "2022/02/28 19:24:00 isha stopwatch",
                "2022/02/28 23:50:00 fajr iqama",
                "2022/03/01 00:00:00 fajr iqama",
                "2022/03/01 01:45:00 fajr iqama",
                "2022/03/01 05:35:00 fajr stopwatch",
                "2022/03/01 06:54:00 dhuhr countdown",
                "2022/03/01 12:31:00 dhuhr stopwatch",
                "2022/03/01 15:36:00 asr stopwatch"
            ]
        ),
        RecordedTimeline(
            expanded: .intervals(0),
            timeline: [
                "2022/02/25 05:42:00 fajr stopwatch",
                "2022/02/25 06:00:00 fajr iqama",
                "2022/02/25 06:31:00 sunrise countdown",
                "2022/02/25 06:33:00 sunrise countdown",
                "2022/02/25 07:00:00 dhuhr iqama",
                "2022/02/25 07:18:00 dhuhr iqama",
                "2022/02/25 12:17:00 dhuhr iqama",
                "2022/02/25 12:31:00 dhuhr stopwatch",
                "2022/02/25 12:49:00 dhuhr iqama",
                "2022/02/25 13:30:00 dhuhr stopwatch",
                "2022/02/25 15:16:00 asr countdown",
                "2022/02/25 15:32:00 asr stopwatch",
                "2022/02/25 15:50:00 asr iqama",
                "2022/02/25 16:38:00 maghrib countdown",
                "2022/02/25 17:39:00 maghrib countdown",
                "2022/02/25 18:01:00 maghrib iqama",
                "2022/02/25 18:09:00 maghrib stopwatch",
                "2022/02/25 18:19:00 isha countdown",
                "2022/02/25 19:11:00 isha countdown",
                "2022/02/25 19:20:00 isha stopwatch",
                "2022/02/25 19:38:00 fajr iqama",
                "2022/02/26 00:00:00 fajr iqama",
                "2022/02/26 05:06:00 fajr iqama",
                "2022/02/26 05:40:00 fajr stopwatch",
                "2022/02/26 05:58:00 fajr iqama",
                "2022/02/26 06:31:00 sunrise countdown",
                "2022/02/26 06:32:00 sunrise countdown",
                "2022/02/26 06:59:00 dhuhr countdown",
                "2022/02/26 07:17:00 dhuhr countdown",
                "2022/02/26 12:17:00 dhuhr countdown",
                "2022/02/26 12:31:00 dhuhr stopwatch",
                "2022/02/26 12:43:00 dhuhr stopwatch",
                "2022/02/26 12:49:00 asr countdown",
                "2022/02/26 15:17:00 asr countdown",
                "2022/02/26 15:33:00 asr stopwatch",
                "2022/02/26 15:51:00 asr iqama",
                "2022/02/26 16:38:00 maghrib countdown",
                "2022/02/26 17:40:00 maghrib countdown",
                "2022/02/26 18:02:00 maghrib iqama",
                "2022/02/26 18:10:00 maghrib stopwatch"
            ]
        ),
        RecordedTimeline(
            expanded: .intervals(5),
            timeline: [
                "2022/02/25 05:42:00 fajr stopwatch",
                "2022/02/25 05:57:36 fajr stopwatch",
                "2022/02/25 06:00:00 fajr iqama",
                "2022/02/25 06:13:12 fajr iqama",
                "2022/02/25 06:28:48 fajr iqama",
                "2022/02/25 06:31:00 sunrise countdown",
                "2022/02/25 06:33:00 sunrise countdown",
                "2022/02/25 06:44:24 sunrise countdown",
                "2022/02/25 07:00:00 dhuhr iqama",
                "2022/02/25 07:18:00 dhuhr iqama",
                "2022/02/25 08:06:12 dhuhr iqama",
                "2022/02/25 09:12:24 dhuhr iqama",
                "2022/02/25 10:18:36 dhuhr iqama",
                "2022/02/25 11:24:48 dhuhr iqama",
                "2022/02/25 12:17:00 dhuhr iqama",
                "2022/02/25 12:31:00 dhuhr stopwatch",
                "2022/02/25 12:49:00 dhuhr iqama",
                "2022/02/25 13:07:12 dhuhr iqama",
                "2022/02/25 13:30:00 dhuhr stopwatch",
                "2022/02/25 13:43:24 dhuhr stopwatch",
                "2022/02/25 14:19:36 asr countdown",
                "2022/02/25 14:55:48 asr countdown",
                "2022/02/25 15:16:00 asr countdown",
                "2022/02/25 15:32:00 asr stopwatch",
                "2022/02/25 15:50:00 asr iqama",
                "2022/02/25 16:01:48 asr iqama",
                "2022/02/25 16:31:36 asr iqama",
                "2022/02/25 16:38:00 maghrib countdown",
                "2022/02/25 17:01:24 maghrib countdown",
                "2022/02/25 17:31:12 maghrib countdown",
                "2022/02/25 17:39:00 maghrib countdown",
                "2022/02/25 18:01:00 maghrib iqama",
                "2022/02/25 18:09:00 maghrib stopwatch",
                "2022/02/25 18:16:48 maghrib stopwatch",
                "2022/02/25 18:19:00 isha countdown",
                "2022/02/25 18:32:36 isha countdown",
                "2022/02/25 18:48:24 isha countdown",
                "2022/02/25 19:04:12 isha countdown",
                "2022/02/25 19:11:00 isha countdown",
                "2022/02/25 19:20:00 isha stopwatch"
            ]
        ),
        RecordedTimeline(
            expanded: .hourly,
            timeline: [
                "2022/02/25 05:42:00 fajr stopwatch",
                "2022/02/25 06:00:00 fajr iqama",
                "2022/02/25 06:05:00 fajr iqama",
                "2022/02/25 06:10:00 fajr iqama",
                "2022/02/25 06:15:00 fajr iqama",
                "2022/02/25 06:20:00 fajr iqama",
                "2022/02/25 06:25:00 fajr iqama",
                "2022/02/25 06:30:00 fajr iqama",
                "2022/02/25 06:31:00 sunrise countdown",
                "2022/02/25 06:33:00 sunrise countdown",
                "2022/02/25 06:35:00 sunrise countdown",
                "2022/02/25 06:40:00 sunrise countdown",
                "2022/02/25 06:45:00 sunrise countdown",
                "2022/02/25 06:50:00 sunrise countdown",
                "2022/02/25 06:55:00 sunrise countdown",
                "2022/02/25 07:00:00 dhuhr iqama",
                "2022/02/25 07:18:00 dhuhr iqama",
                "2022/02/25 07:31:00 dhuhr iqama",
                "2022/02/25 08:31:00 dhuhr iqama",
                "2022/02/25 09:31:00 dhuhr iqama",
                "2022/02/25 10:31:00 dhuhr iqama",
                "2022/02/25 11:31:00 dhuhr iqama",
                "2022/02/25 11:36:00 dhuhr iqama",
                "2022/02/25 11:41:00 dhuhr iqama",
                "2022/02/25 11:46:00 dhuhr iqama",
                "2022/02/25 11:51:00 dhuhr iqama",
                "2022/02/25 11:56:00 dhuhr iqama",
                "2022/02/25 12:01:00 dhuhr iqama",
                "2022/02/25 12:06:00 dhuhr iqama",
                "2022/02/25 12:11:00 dhuhr iqama",
                "2022/02/25 12:16:00 dhuhr iqama",
                "2022/02/25 12:17:00 dhuhr iqama",
                "2022/02/25 12:21:00 dhuhr iqama",
                "2022/02/25 12:26:00 dhuhr iqama",
                "2022/02/25 12:31:00 dhuhr stopwatch",
                "2022/02/25 12:32:00 dhuhr stopwatch",
                "2022/02/25 12:49:00 dhuhr iqama",
                "2022/02/25 13:30:00 dhuhr stopwatch",
                "2022/02/25 13:32:00 dhuhr stopwatch",
                "2022/02/25 14:32:00 asr countdown",
                "2022/02/25 14:37:00 asr countdown",
                "2022/02/25 14:42:00 asr countdown",
                "2022/02/25 14:47:00 asr countdown",
                "2022/02/25 14:52:00 asr countdown",
                "2022/02/25 14:57:00 asr countdown",
                "2022/02/25 15:02:00 asr countdown",
                "2022/02/25 15:07:00 asr countdown",
                "2022/02/25 15:12:00 asr countdown",
                "2022/02/25 15:16:00 asr countdown",
                "2022/02/25 15:17:00 asr countdown",
                "2022/02/25 15:22:00 asr countdown",
                "2022/02/25 15:27:00 asr countdown",
                "2022/02/25 15:32:00 asr stopwatch"
            ]
        ),
        RecordedTimeline(
            expanded: .finalHour,
            timeline: [
                "2022/02/25 05:42:00 fajr stopwatch",
                "2022/02/25 06:00:00 fajr iqama",
                "2022/02/25 06:31:00 sunrise countdown",
                "2022/02/25 06:33:00 sunrise countdown",
                "2022/02/25 07:00:00 dhuhr iqama",
                "2022/02/25 07:18:00 dhuhr iqama",
                "2022/02/25 11:31:00 dhuhr iqama",
                "2022/02/25 12:17:00 dhuhr iqama",
                "2022/02/25 12:31:00 dhuhr stopwatch",
                "2022/02/25 12:49:00 dhuhr iqama",
                "2022/02/25 13:30:00 dhuhr stopwatch",
                "2022/02/25 14:32:00 asr countdown",
                "2022/02/25 15:16:00 asr countdown",
                "2022/02/25 15:32:00 asr stopwatch",
                "2022/02/25 15:50:00 asr iqama",
                "2022/02/25 16:38:00 maghrib countdown",
                "2022/02/25 17:01:00 maghrib countdown",
                "2022/02/25 17:39:00 maghrib countdown",
                "2022/02/25 18:01:00 maghrib iqama",
                "2022/02/25 18:09:00 maghrib stopwatch",
                "2022/02/25 18:19:00 isha countdown",
                "2022/02/25 18:20:00 isha countdown",
                "2022/02/25 19:11:00 isha countdown",
                "2022/02/25 19:20:00 isha stopwatch",
                "2022/02/25 19:38:00 fajr iqama",
                "2022/02/26 00:00:00 fajr iqama",
                "2022/02/26 04:40:00 fajr iqama",
                "2022/02/26 05:06:00 fajr iqama",
                "2022/02/26 05:40:00 fajr stopwatch",
                "2022/02/26 05:58:00 fajr iqama",
                "2022/02/26 05:59:00 fajr iqama",
                "2022/02/26 06:31:00 sunrise countdown",
                "2022/02/26 06:32:00 sunrise countdown",
                "2022/02/26 06:59:00 dhuhr countdown",
                "2022/02/26 07:17:00 dhuhr countdown",
                "2022/02/26 11:31:00 dhuhr countdown",
                "2022/02/26 12:17:00 dhuhr countdown",
                "2022/02/26 12:31:00 dhuhr stopwatch",
                "2022/02/26 12:43:00 dhuhr stopwatch",
                "2022/02/26 12:49:00 asr countdown",
                "2022/02/26 14:33:00 asr countdown",
                "2022/02/26 15:17:00 asr countdown",
                "2022/02/26 15:33:00 asr stopwatch"
            ]
        )
    ]
}
