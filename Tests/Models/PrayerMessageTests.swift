//
//  PrayerMessageTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-29.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct PrayerMessageTests {
    private let start = Date(timeIntervalSince1970: 1_799_798_400)

    /// Fajr 05:00, sunrise 06:30, Dhuhr 12:00, Asr 15:30, Maghrib 18:00, Isha 19:30, the middle of the night 23:30.
    private var day: PrayerDay {
        PrayerDay(date: start, times: times(from: start), tomorrow: times(from: start + 24 * 3600))
    }

    private func times(from start: Date, middleAt middleHour: Double = 23.5) -> [PrayerTime] {
        let middle = PrayerTime(type: .midnight, dateInterval: DateInterval(start: start + middleHour * 3600, end: start + 26 * 3600))
        return (PrayerTime.day(from: start) + [middle]).sorted { $0.dateInterval.start < $1.dateInterval.start }
    }

    private func hour(_ value: Double) -> Date { start + value * 3600 }
}

// MARK: - Building

extension PrayerMessageTests {
    @Test
    func theTimetableListsTheEssentialPrayersOnly() throws {
        guard case let .timetable(times) = day.timetable else { throw Failure.wrongCase }
        #expect(times.map(\.type) == [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])
    }

    @Test
    func aMeetingAfterIsSomeMinutesAfterTheAdhan() throws {
        let content = try #require(day.meeting(.asr, minutes: 30, .after, together: false, at: hour(10)))
        #expect(content == .meet(PrayerMessage.Meeting(prayer: .asr, adhan: hour(15.5), minutes: 30, timing: .after, together: false)))
        #expect(content.target == hour(16))
    }

    @Test
    func aMeetingDuringThePrayersTimeCountsFromNow() throws {
        let content = try #require(day.meeting(.asr, minutes: 30, .after, together: false, at: hour(15.75)))
        #expect(content == .meet(PrayerMessage.Meeting(prayer: .asr, adhan: hour(15.5), minutes: 45, timing: .during, together: false)))
        #expect(content.target == hour(16.25))
    }

    @Test
    func noMinutesDuringThePrayersTimeIsNow() throws {
        let content = try #require(day.meeting(.asr, minutes: 0, .before, together: true, at: hour(16)))
        #expect(content.target == hour(16))
    }

    @Test
    func ishaAfterMidnightIsStillUnderWay() throws {
        let content = try #require(day.meeting(.isha, minutes: 10, .before, together: true, at: hour(25)))
        guard case let .meet(meeting) = content else { throw Failure.wrongCase }
        #expect(meeting.timing == .during)
        #expect(meeting.adhan == hour(19.5))
        #expect(content.target == hour(25) + 600)
    }

    @Test
    func aMeetingAfterAPrayerWhoseTimeHasEndedMovesToTomorrow() throws {
        let content = try #require(day.meeting(.asr, minutes: 30, .after, together: false, at: hour(18.5)))
        #expect(content.target == hour(40))
    }

    @Test
    func aMeetingBeforeIsSomeMinutesBeforeTheAdhan() throws {
        let content = try #require(day.meeting(.isha, minutes: 10, .before, together: true, at: hour(12)))
        #expect(content == .meet(PrayerMessage.Meeting(prayer: .isha, adhan: hour(19.5), minutes: 10, timing: .before, together: true)))
        #expect(content.target == hour(19.5) - 600)
    }

    @Test
    func aMeetingBeforeCloserThanItsMinutesKeepsThisAdhan() throws {
        let content = try #require(day.meeting(.isha, minutes: 10, .before, together: true, at: hour(19.5) - 300))
        guard case let .meet(meeting) = content else { throw Failure.wrongCase }
        #expect(meeting.adhan == hour(19.5))
    }

    @Test
    func aMeetingBeforeOnceThePrayerHasBegunCountsFromNow() throws {
        let content = try #require(day.meeting(.asr, minutes: 10, .before, together: true, at: hour(15.5)))
        guard case let .meet(meeting) = content else { throw Failure.wrongCase }
        #expect(meeting.timing == .during)
        #expect(content.target == hour(15.5) + 600)
    }

    @Test
    func aMeetingForAPrayerWhoseTimeHasEndedIsTomorrows() throws {
        let content = try #require(day.meeting(.fajr, minutes: 10, .before, together: true, at: hour(12)))
        guard case let .meet(meeting) = content else { throw Failure.wrongCase }
        #expect(meeting.timing == .before)
        #expect(meeting.adhan == hour(29))
    }
}

// MARK: - When a prayer runs out

extension PrayerMessageTests {
    @Test(arguments: [(Prayer.fajr, 5.5, 5.0, 6.5), (.dhuhr, 13, 12, 15.5), (.asr, 16, 15.5, 18), (.maghrib, 19, 18, 19.5)])
    func aPrayerRunsOutWhereTheNextTimeBegins(prayer: Prayer, at moment: Double, starts start: Double, ends end: Double) throws {
        let content = try #require(day.reminder(at: hour(moment)))
        #expect(content == .reminder(prayer: prayer, starts: hour(start), ends: hour(end)))
        #expect(content.datedAt == hour(start))
    }

    @Test
    func ishasPreferredTimeRunsOutAtTheMiddleOfTheNight() throws {
        let content = try #require(day.reminder(at: hour(21)))
        #expect(content == .reminder(prayer: .isha, starts: hour(19.5), ends: hour(23.5)))
    }

    @Test
    func afterTheMiddleOfTheNightThereIsNoReminder() {
        #expect(day.reminder(at: hour(23.5)) == nil)
        #expect(day.reminder(at: hour(28)) == nil)
    }

    @Test
    func betweenSunriseAndDhuhrThereIsNoReminder() {
        #expect(day.reminder(at: hour(6.5)) == nil)
        #expect(day.reminder(at: hour(11)) == nil)
    }

    @Test
    func beforeFajrTheDayHasNoReminder() {
        #expect(day.reminder(at: hour(4)) == nil)
    }

    @Test
    func withoutTheMiddleOfTheNightIshaRunsToFajr() throws {
        let day = PrayerDay(date: start, times: PrayerTime.day(from: start), tomorrow: PrayerTime.day(from: start + 24 * 3600))
        let deadline = try #require(day.deadline(at: hour(25)))

        #expect(deadline.type == .isha)
        #expect(deadline.dateInterval == DateInterval(start: hour(19.5), end: hour(29)))
    }

    @Test
    func aMiddleOfTheNightBeforeIshaLeavesIshaToFajr() throws {
        let day = PrayerDay(date: start, times: times(from: start, middleAt: 19), tomorrow: times(from: start + 24 * 3600))
        let deadline = try #require(day.deadline(at: hour(21)))

        #expect(deadline.dateInterval.end == hour(29))
    }
}

// MARK: - Hijri date

extension PrayerMessageTests {
    private var tomorrow: PrayerDay {
        PrayerDay(date: start + 24 * 3600, times: times(from: start + 24 * 3600), tomorrow: times(from: start + 48 * 3600))
    }

    @Test
    func theHijriDateTurnsAtMaghribOfTheDayHoldingTheMoment() {
        var settings = Settings()
        settings.autoIncrementHijri = true
        settings.hijriDayOffset = 1

        #expect(settings.shownHijriDayOffset(at: hour(17), in: [day, tomorrow], timeZone: .gmt) == 1)
        #expect(settings.shownHijriDayOffset(at: hour(18), in: [day, tomorrow], timeZone: .gmt) == 2)
        #expect(settings.shownHijriDayOffset(at: hour(41), in: [day, tomorrow], timeZone: .gmt) == 1)
        #expect(settings.shownHijriDayOffset(at: hour(42), in: [day, tomorrow], timeZone: .gmt) == 2)
    }

    @Test
    func withoutTheDayHoldingTheMomentOnlyTheAdjustmentCounts() {
        var settings = Settings()
        settings.autoIncrementHijri = true
        settings.hijriDayOffset = -1

        #expect(settings.shownHijriDayOffset(at: hour(42), in: [day], timeZone: .gmt) == -1)
    }
}

// MARK: - URL

extension PrayerMessageTests {
    private var timeZone: TimeZone { TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .gmt }

    @Test(arguments: [
        PrayerMessage.Content.meet(.init(prayer: .asr, adhan: Date(timeIntervalSince1970: 1_799_854_200), minutes: 30, timing: .after, together: false)),
        .meet(.init(prayer: .isha, adhan: Date(timeIntervalSince1970: 1_799_868_600), minutes: 10, timing: .before, together: true)),
        .meet(.init(prayer: .dhuhr, adhan: Date(timeIntervalSince1970: 1_799_841_600), minutes: 47, timing: .during, together: true)),
        .reminder(prayer: .dhuhr, starts: Date(timeIntervalSince1970: 1_799_841_600), ends: Date(timeIntervalSince1970: 1_799_854_200)),
        .timetable(times: PrayerTime.day(from: Date(timeIntervalSince1970: 1_799_798_400)))
    ])
    func aMessageReadsBackFromItsLink(content: PrayerMessage.Content) throws {
        let message = PrayerMessage(content: content, placeName: "Cyberjaya, Selangor", timeZone: timeZone, uses24hTime: true, hijriDayOffset: 1)
        #expect(PrayerMessage(url: message.url) == message)
    }

    @Test
    func aMessageWithoutAPlaceReadsBack() throws {
        let message = PrayerMessage(content: day.timetable, placeName: nil, timeZone: timeZone, uses24hTime: false, hijriDayOffset: -2)
        #expect(PrayerMessage(url: message.url) == message)
    }

    @Test(arguments: [
        "https://praywatch.app/m",
        "https://praywatch.app/m?v=2&tz=Asia/Kuala_Lumpur&hijri=0&kind=reminder&prayer=asr&starts=1799841600&ends=1799854200",
        "https://praywatch.app/m?v=1&tz=Mars/Olympus&hijri=0&kind=reminder&prayer=asr&starts=1799841600&ends=1799854200",
        "https://praywatch.app/m?v=1&tz=Asia/Kuala_Lumpur&hijri=0&kind=reminder&prayer=dinner&starts=1799841600&ends=1799854200",
        "https://praywatch.app/m?v=1&tz=Asia/Kuala_Lumpur&kind=reminder&prayer=asr&starts=1799841600&ends=1799854200",
        "https://praywatch.app/m?v=1&tz=Asia/Kuala_Lumpur&hijri=0&kind=reminder&prayer=asr&starts=1799854200&ends=1799841600",
        "https://praywatch.app/m?v=1&tz=Asia/Kuala_Lumpur&kind=meet&prayer=asr&adhan=soon&minutes=30&timing=after",
        "https://praywatch.app/m?v=1&tz=Asia/Kuala_Lumpur&kind=meet&prayer=isha&adhan=1799868600&minutes=-5&timing=before",
        "https://praywatch.app/m?v=1&tz=Asia/Kuala_Lumpur&kind=meet&prayer=isha&adhan=1799868600&minutes=5&timing=whenever",
        "https://praywatch.app/m?v=1&tz=Asia/Kuala_Lumpur&kind=timetable&times=fajr:1:2,sunrise:x:3",
        "https://praywatch.app/m?v=1&tz=Asia/Kuala_Lumpur&kind=party"
    ])
    func aMalformedOrNewerLinkReadsAsNothing(link: String) throws {
        let url = try #require(URL(string: link))
        #expect(PrayerMessage(url: url) == nil)
    }
}

private enum Failure: Error {
    case wrongCase
}
