//
//  PrayerDayRuleTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import PrayMocks
@testable import PrayServices
import Testing
import ZamzamCore

/// A prayer day runs from its Fajr to the next Fajr: its essential prayers tile that span, and the days tile in turn.
struct PrayerDayRuleTests {
    private let fixture = PrayTestFixture()
}

extension PrayerDayRuleTests {
    @Test(arguments: DayFixture.all)
    func essentialPrayersTileEachDayAndTheDaysTileInTurn(place: DayFixture) async throws {
        let days = try await place.days(4, using: fixture.prayerManager)

        for (day, next) in zip(days, days.dropFirst()) {
            let essentials = day.times.filter(\.type.isEssential)
            #expect(essentials.map(\.type) == [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])

            for (prayer, following) in zip(essentials, essentials.dropFirst()) {
                #expect(prayer.dateInterval.end == following.dateInterval.start, "\(prayer.type) ends where \(following.type) begins")
            }

            #expect(day.times[.isha]?.dateInterval.end == next.times[.fajr]?.dateInterval.start, "Isha ends at the next Fajr")
            #expect(day.times[.lastThird]?.dateInterval.end == day.times[.isha]?.dateInterval.end, "The night ends with Isha")

            let maghrib = try #require(day.times[.maghrib]).dateInterval.start
            let nextFajr = try #require(day.times[.isha]).dateInterval.end
            let lastThird = try #require(day.times[.lastThird]).dateInterval.start
            #expect(
                abs(lastThird.timeIntervalSince(maghrib) - nextFajr.timeIntervalSince(maghrib) * 2 / 3) <= 30,
                "The last third begins two-thirds into the night"
            )
        }
    }
}

// MARK: - The day a moment belongs to

extension PrayerDayRuleTests {
    /// Every moment across three days, sampled every five minutes and a second either side of each prayer boundary.
    @Test(arguments: DayFixture.all)
    func everyMomentBelongsToTheOneDayWhoseSpanHoldsIt(place: DayFixture) async throws {
        let request = try place.request()
        let days = try await place.days(4, using: fixture.prayerManager)
        let spanStart = try #require(days[0].times[.fajr]).dateInterval.start
        let spanEnd = try #require(days[2].times[.isha]).dateInterval.end

        let boundaries = days.prefix(3)
            .flatMap { $0.times.filter(\.type.isEssential) }
            .flatMap { [$0.dateInterval.start - 1, $0.dateInterval.start, $0.dateInterval.end - 1, $0.dateInterval.end] }
        let samples = Array(stride(from: spanStart, to: spanEnd, by: 300))
        let instants = (boundaries + samples).filter { spanStart <= $0 && $0 < spanEnd }.sorted()

        var problems = [String]()
        var previousDate = Date.distantPast

        for instant in instants {
            let day = try await fixture.prayerManager.fetch(at: instant, with: request)
            let expected = days.first { $0.contains(instant) }
            let current = day.current(at: instant)

            if !day.contains(instant) { problems.append("\(instant): the day doesn't contain it") }
            if day.date != expected?.date || day.times != expected?.times { problems.append("\(instant): not the day whose span holds it") }
            if current.map({ !$0.dateInterval.contains(instant) || !$0.type.isEssential }) ?? true { problems.append("\(instant): no current prayer holds it") }
            if day.next(at: instant).map({ $0.dateInterval.start <= instant }) ?? true { problems.append("\(instant): no next prayer after it") }
            if day.date < previousDate { problems.append("\(instant): the day went backwards") }
            previousDate = day.date
        }

        let problemCount = problems.count
        #expect(problemCount == 0, "\(instants.count) moments checked, first problems: \(problems.prefix(5))")
    }

    @Test
    func parisIshaAfterMidnightBelongsToTheDayBefore() async throws {
        let place = try #require(DayFixture.all.first { $0.method == .france18 })
        let request = try place.request()
        let calendar = try place.calendar()
        let june21 = calendar.startOfDay(for: try place.date(2026, 6, 21))
        let june22 = calendar.startOfDay(for: try place.date(2026, 6, 22))

        // Maghrib 21:58, Isha 00:19, the next Fajr 03:26
        let beforeIsha = try place.date(2026, 6, 22, 0, 10)
        let ishaBegins = try place.date(2026, 6, 22, 0, 19)
        let duringIsha = try place.date(2026, 6, 22, 0, 30)
        let lastSecond = try place.date(2026, 6, 22, 3, 25, 59)
        let fajrBegins = try place.date(2026, 6, 22, 3, 26)

        let dayBeforeIsha = try await fixture.prayerManager.fetch(at: beforeIsha, with: request)
        #expect(dayBeforeIsha.date == june21)
        #expect(dayBeforeIsha.current(at: beforeIsha)?.type == .maghrib)
        #expect(dayBeforeIsha.next(at: beforeIsha)?.dateInterval.start == ishaBegins)

        let dayDuringIsha = try await fixture.prayerManager.fetch(at: duringIsha, with: request)
        #expect(dayDuringIsha.date == june21)
        #expect(dayDuringIsha.current(at: duringIsha)?.type == .isha)
        #expect(dayDuringIsha.next(at: duringIsha)?.dateInterval.start == fajrBegins)

        let dayAtLastSecond = try await fixture.prayerManager.fetch(at: lastSecond, with: request)
        let dayAtFajr = try await fixture.prayerManager.fetch(at: fajrBegins, with: request)
        #expect(dayAtLastSecond.date == june21)
        #expect(dayAtFajr.date == june22)
        #expect(dayAtFajr.current(at: fajrBegins)?.type == .fajr)
    }

    @Test
    func reykjavikMaghribAfterMidnightBelongsToTheDayBefore() async throws {
        let place = try #require(DayFixture.all.first { $0.timeZoneIdentifier == "Atlantic/Reykjavik" })
        let request = try place.request()
        let calendar = try place.calendar()
        let june21 = calendar.startOfDay(for: try place.date(2026, 6, 21))

        // Maghrib 00:07 and Isha 00:29, both after midnight, then Fajr 02:31
        let beforeMaghrib = try place.date(2026, 6, 22, 0, 3)
        let maghribBegins = try place.date(2026, 6, 22, 0, 7)
        let duringMaghrib = try place.date(2026, 6, 22, 0, 20)
        let ishaBegins = try place.date(2026, 6, 22, 0, 29)
        let dayBeforeMaghrib = try await fixture.prayerManager.fetch(at: beforeMaghrib, with: request)
        let dayDuringMaghrib = try await fixture.prayerManager.fetch(at: duringMaghrib, with: request)

        #expect(dayBeforeMaghrib.date == june21)
        #expect(dayBeforeMaghrib.current(at: beforeMaghrib)?.type == .asr)
        #expect(dayBeforeMaghrib.next(at: beforeMaghrib)?.dateInterval.start == maghribBegins)
        #expect(dayDuringMaghrib.date == june21)
        #expect(dayDuringMaghrib.current(at: duringMaghrib)?.type == .maghrib)
        #expect(dayDuringMaghrib.next(at: duringMaghrib)?.dateInterval.start == ishaBegins)
    }

    @Test
    func beforeFajrIsThePreviousDaysIsha() async throws {
        let place = try #require(DayFixture.all.first)
        let request = try place.request()
        let calendar = try place.calendar()
        let threeAM = try place.date(2021, 1, 3, 3, 0)

        let january2 = calendar.startOfDay(for: try place.date(2021, 1, 2))

        let day = try await fixture.prayerManager.fetch(at: threeAM, with: request)
        let next = try #require(day.next(at: threeAM))

        #expect(day.date == january2)
        #expect(day.current(at: threeAM)?.type == .isha)
        #expect(next.type == .fajr)
        #expect(next.dateInterval.start > threeAM)
    }

    /// Fajr set 300 minutes before sunrise lands before midnight in an Edinburgh June: from then the moment belongs to
    /// the next calendar day's prayer day.
    @Test
    func aFajrBeforeMidnightStartsTheNextDay() async throws {
        let place = try #require(DayFixture.all.first { $0.name.hasPrefix("Edinburgh") })
        let request = try place.request()
        let calendar = try place.calendar()
        let june20 = calendar.startOfDay(for: try place.date(2026, 6, 20))
        let june21 = calendar.startOfDay(for: try place.date(2026, 6, 21))
        let eveningIsha = try place.date(2026, 6, 20, 23, 0)
        let lateEvening = try place.date(2026, 6, 20, 23, 45)

        let ishaDay = try await fixture.prayerManager.fetch(at: eveningIsha, with: request)
        let fajrDay = try await fixture.prayerManager.fetch(at: lateEvening, with: request)
        let fajr = try #require(fajrDay.times[.fajr])

        #expect(ishaDay.date == june20)
        #expect(ishaDay.current(at: eveningIsha)?.type == .isha)
        #expect(fajrDay.date == june21)
        #expect(fajr.dateInterval.start < june21)
        #expect(fajrDay.current(at: lateEvening)?.type == .fajr)
    }

    @Test
    func aDayHoldsItsFajrButNotTheNextOne() async throws {
        let place = try #require(DayFixture.all.first)
        let day = try #require(try await place.days(1, using: fixture.prayerManager).first)
        let fajr = try #require(day.times[.fajr]).dateInterval.start
        let nextFajr = try #require(day.times[.isha]).dateInterval.end

        #expect(!day.contains(fajr - 1))
        #expect(day.contains(fajr))
        #expect(day.contains(nextFajr - 1))
        #expect(!day.contains(nextFajr))
    }

    @Test
    func aDayWithoutTimesIsNeverChosen() async throws {
        let place = DayFixture("London timetable after its last day", 51.5074, -0.1278, "Europe/London", .london, 2100, 6, 1)

        let error = await #expect(throws: PrayError.self) {
            try await fixture.prayerManager.fetch(at: try place.firstNoon(), with: try place.request())
        }

        guard case .invalidTimes = error else {
            Issue.record("Expected invalid times, got \(String(describing: error))")
            return
        }
    }
}

// MARK: - Timelines

extension PrayerDayRuleTests {
    /// Timelines started every three hours across two days: each entry comes from the day that holds it, in order,
    /// and every later Fajr keeps the reminder before it, which belongs to the night before.
    @Test(arguments: DayFixture.all)
    func everyTimelineEntryComesFromTheDayThatHoldsIt(place: DayFixture) async throws {
        let request = try place.request()
        let noon = try place.firstNoon()
        let days = try await place.days(4, using: fixture.prayerManager)
        var settings = Settings()
        settings.preAdhanMinutes[.fajr] = 30
        settings.stopwatchMinutes = 10

        var problems = [String]()

        for hours in stride(from: 0, to: 48, by: 3) {
            let start = noon + TimeInterval(hours * 3600)
            let timeline = try await fixture.prayerManager.fetch(
                from: start,
                expanded: .intervals(0),
                limit: 30,
                with: request,
                settings: settings,
                timeZone: request.timeZone
            )
            let end = timeline.last?.date ?? start
            // A reminder is only set when the prayer lasts longer than it, as Reykjavik's Fajr in June doesn't
            let fajrReminders = days
                .compactMap { $0.times[.fajr] }
                .filter { $0.dateInterval.duration > 1800 && $0.dateInterval.start < end }
                .map { $0.dateInterval.start - 1800 }
                .filter { $0 > start }

            if !zip(timeline, timeline.dropFirst()).allSatisfy({ $0.date < $1.date }) { problems.append("\(start): out of order") }
            if !timeline.contains(where: { $0.date == start }) { problems.append("\(start): no entry for the moment itself") }
            problems += timeline.filter { !$0.prayerDay.contains($0.date) }.map { "\(start): \($0.date) from a day that doesn't hold it" }
            problems += fajrReminders.filter { reminder in !timeline.contains { $0.date == reminder } }.map { "\(start): no reminder at \($0)" }
        }

        let problemCount = problems.count
        #expect(problemCount == 0, "first problems: \(problems.prefix(5))")
    }

    @Test
    func aTimelineBuiltAfterMidnightCountsToTheIshaStillToCome() async throws {
        let place = try #require(DayFixture.all.first { $0.method == .france18 })
        let request = try place.request()
        let calendar = try place.calendar()
        let june21 = calendar.startOfDay(for: try place.date(2026, 6, 21))
        let start = try place.date(2026, 6, 22, 0, 10)
        let ishaBegins = try place.date(2026, 6, 22, 0, 19)
        // Without the count-up, Isha's own entry counts on to the next day's Fajr
        var settings = Settings()
        settings.stopwatchMinutes = 0

        let timeline = try await fixture.prayerManager.fetch(
            from: start,
            limit: 10,
            with: request,
            settings: settings,
            timeZone: request.timeZone
        )
        let now = try #require(timeline.first { $0.date == start })
        let isha = try #require(timeline.first { $0.date == ishaBegins })

        #expect(now.prayerDay.date == june21)
        #expect(now.type == .isha)
        #expect(now.countdownDate == ishaBegins)
        #expect(isha.prayerDay.date == june21)
        #expect(isha.type == .fajr)
    }
}

// MARK: - Stages

extension PrayerDayRuleTests {
    @Test
    func anIshaAfterMidnightIsStillTheDaysCurrentPrayer() async throws {
        let place = try #require(DayFixture.all.first { $0.method == .france18 })
        let now = try place.date(2026, 6, 22, 0, 25)
        let day = try await fixture.prayerManager.fetch(at: now, with: try place.request())
        let isha = try #require(day.times[.isha])
        let maghrib = try #require(day.times[.maghrib])
        let tomorrowsFajr = try #require(day.tomorrow[.fajr])

        #expect(day.stage(of: isha, at: now) == .current)
        #expect(day.stage(of: maghrib, at: now) == .passed)
        #expect(day.stage(of: tomorrowsFajr, at: now) == .upcoming)
    }

    @Test
    func aDayWhoseIshaHasEndedPicksOutNoPrayer() async throws {
        let place = try #require(DayFixture.all.first { $0.method == .france18 })
        let day = try await fixture.prayerManager.fetch(at: try place.date(2026, 6, 22, 0, 25), with: try place.request())
        let isha = try #require(day.times[.isha])
        let later = isha.dateInterval.end + 60

        #expect(day.stage(of: isha, at: later) == .passed)
        #expect(day.times.allSatisfy { day.stage(of: $0, at: later) == .passed })
    }
}

// MARK: - Notifications

extension PrayerDayRuleTests {
    @Test
    func aLateIshaIsStillNotifiedAfterMidnightUnderItsOwnDay() async throws {
        let place = try #require(DayFixture.all.first { $0.method == .france18 })
        let request = try place.request()
        let calendar = try place.calendar()
        let now = try place.date(2026, 6, 22, 0, 10)
        let ishaBegins = try place.date(2026, 6, 22, 0, 19)
        let week = DateInterval(start: now, duration: 7 * 24 * 3600)

        let days = try await fixture.prayerManager.fetch(spanning: week, with: request)
        let scheduled = NotificationServiceUN.prayersToNotify(in: days, from: now, calendar: calendar)
        let isha = try #require(scheduled.first { $0.prayerTime.type == .isha })
        let june21 = try #require(days.first)

        #expect(isha.prayerTime.dateInterval.start == ishaBegins)
        #expect(isha.prefix == june21.date.shortString(calendar: calendar))

        // The calendar days from now leave that Isha out
        let calendarDays = try await fixture.prayerManager.fetch(between: week, with: request)
        let fromCalendarDays = NotificationServiceUN.prayersToNotify(in: calendarDays, from: now, calendar: calendar)
        #expect(!fromCalendarDays.contains { $0.prayerTime.dateInterval.start == ishaBegins })
    }

    /// The days a span reaches are those holding its moments, so an end after a Fajr that begins before midnight
    /// reaches the next calendar day's, and a span inside one evening is that one day.
    @Test
    func aSpanEndsWithTheDayHoldingItsLastMoment() async throws {
        let place = try #require(DayFixture.all.first { $0.name.hasPrefix("Edinburgh") })
        let request = try place.request()
        let calendar = try place.calendar()
        let june21 = calendar.startOfDay(for: try place.date(2026, 6, 21))
        let june28 = calendar.startOfDay(for: try place.date(2026, 6, 28))
        let start = try place.date(2026, 6, 20, 23, 45)

        let week = try await fixture.prayerManager.fetch(spanning: DateInterval(start: start, duration: 7 * 24 * 3600), with: request)
        let evening = try await fixture.prayerManager.fetch(spanning: DateInterval(start: start, duration: 300), with: request)

        #expect(week.first?.date == june21)
        #expect(week.last?.date == june28)
        #expect(week.count == 8)
        #expect(evening.map(\.date) == [june21])
    }

    /// A span calculates only the days it reaches, and one it reaches that can't be calculated ends it there, so the
    /// days before it still count: May 26 puts Fajr past sunrise, so May 25, whose Isha ends at May 26's Fajr, can't be.
    @Test
    func aDayThatCantBeCalculatedNeverCostsTheDaysBeforeIt() async throws {
        let place = DayFixture(
            "Edinburgh, Fajr 60 minutes later, past sunrise by May 26", 55.9533, -3.1883, "Europe/London", .muslimWorldLeague, 2026, 5, 17,
            adjustments: .absolute(fajr: 60)
        )
        let request = try place.request()
        let start = try place.date(2026, 5, 17, 12, 0)

        await #expect(throws: PrayError.self) {
            try await fixture.prayerManager.fetch(for: try place.date(2026, 5, 25), with: request)
        }

        let week = try await fixture.prayerManager.fetch(spanning: DateInterval(start: start, duration: 7 * 24 * 3600), with: request)
        #expect(week.count == 8)

        let weekReachingMay25 = try await fixture.prayerManager.fetch(
            spanning: DateInterval(start: try place.date(2026, 5, 18, 12, 0), duration: 7 * 24 * 3600),
            with: request
        )
        #expect(weekReachingMay25.count == 7)
        #expect(weekReachingMay25.last?.date == (try place.calendar()).startOfDay(for: try place.date(2026, 5, 24)))
    }

    /// A night too short to order its middle and last third keeps its day: the prayers stand, without those two times.
    @Test
    func aNightTooShortForItsMarkersKeepsTheDay() async throws {
        let place = DayFixture(
            "Reykjavik, Fajr, Maghrib and Isha moved into a two-minute night", 64.1466, -21.9426, "Atlantic/Reykjavik", .moonsightingCommittee,
            2026, 6, 21,
            adjustments: PrayerAdjustments(
                fajr: -22, sunrise: 0, dhuhr: 0, asr: 0, maghrib: 120, isha: 99,
                isFajrSunriseRelative: false, isIshaMaghribRelative: false, elevation: nil
            )
        )

        let day = try await fixture.prayerManager.fetch(for: try place.date(2026, 6, 21), with: try place.request())

        #expect(day.times.filter(\.type.isEssential).map(\.type) == [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])
        #expect(day.times[.midnight] == nil)
        #expect(day.times[.lastThird] == nil)
    }

    @Test(arguments: DayFixture.all)
    func aPrayerRunsOutAtTheMiddleOfTheNightOrWhereTheNextTimeBegins(place: DayFixture) async throws {
        let day = try #require(try await place.days(1, using: fixture.prayerManager).first)

        for prayer in day.times where prayer.type.isObligation {
            let deadline = try #require(day.deadline(at: prayer.dateInterval.start + 1), "\(prayer.type) is under way")
            #expect(deadline.type == prayer.type)

            if prayer.type == .isha, let middle = day.times[.midnight], middle.dateInterval.start > prayer.dateInterval.start {
                #expect(deadline.dateInterval.end == middle.dateInterval.start)
                #expect(day.deadline(at: middle.dateInterval.start) == nil)
            } else {
                #expect(deadline.dateInterval.end == prayer.dateInterval.end)
            }
        }
    }

    /// From moments every three hours across two days: names are unique, prayers come in time order, and the next
    /// prayer is always among them.
    @Test(arguments: DayFixture.all)
    func everyPrayerStillToComeIsNotifiedOnceInOrder(place: DayFixture) async throws {
        let request = try place.request()
        let calendar = try place.calendar()
        let noon = try place.firstNoon()
        var problems = [String]()

        for hours in stride(from: 0, to: 48, by: 3) {
            let now = noon + TimeInterval(hours * 3600)
            let week = DateInterval(start: now, duration: 7 * 24 * 3600)
            let days = try await fixture.prayerManager.fetch(spanning: week, with: request)
            let scheduled = NotificationServiceUN.prayersToNotify(in: days, from: now, calendar: calendar)
            let identifiers = scheduled.map { "\($0.prefix)-\($0.prayerTime.type)" }
            let starts = scheduled.map(\.prayerTime.dateInterval.start)
            let next = try await fixture.prayerManager.fetch(at: now, with: request).next(at: now)

            if Set(identifiers).count != identifiers.count { problems.append("\(now): an identifier repeats") }
            if starts != starts.sorted() { problems.append("\(now): out of order") }
            if !scheduled.contains(where: { $0.prayerTime == next }) { problems.append("\(now): the next prayer is missing") }
            if days.first?.contains(week.start) != true || days.last?.contains(week.end) != true {
                problems.append("\(now): the days don't reach both ends of the week")
            }
        }

        let problemCount = problems.count
        #expect(problemCount == 0, "first problems: \(problems.prefix(5))")
    }
}

// MARK: - Hijri date

extension PrayerDayRuleTests {
    @Test
    func theHijriDayTurnsOnceAtMaghribWhenIshaBeginsAfterMidnight() async throws {
        let place = try #require(DayFixture.all.first { $0.method == .france18 })

        // Maghrib 21:58 on June 21; Isha 00:19 and Fajr 03:26 on June 22. Past midnight the calendar date has already
        // moved on, so the offset falls back to none rather than counting the day twice.
        #expect(try await hijriOffset(at: try place.date(2026, 6, 21, 21, 0), in: place) == 0)
        #expect(try await hijriOffset(at: try place.date(2026, 6, 21, 23, 0), in: place) == 1)
        #expect(try await hijriOffset(at: try place.date(2026, 6, 22, 0, 10), in: place) == 0)
        #expect(try await hijriOffset(at: try place.date(2026, 6, 22, 0, 30), in: place) == 0)
        #expect(try await hijriOffset(at: try place.date(2026, 6, 22, 4, 0), in: place) == 0)
    }

    @Test
    func theHijriDayWaitsForAMaghribAfterMidnight() async throws {
        let place = try #require(DayFixture.all.first { $0.timeZoneIdentifier == "Atlantic/Reykjavik" })

        // June 21's Maghrib begins at 00:07 on June 22: until then the Hijri date is still June 21's, a day behind
        // the calendar date
        #expect(try await hijriOffset(at: try place.date(2026, 6, 21, 23, 0), in: place) == 0)
        #expect(try await hijriOffset(at: try place.date(2026, 6, 22, 0, 3), in: place) == -1)
        #expect(try await hijriOffset(at: try place.date(2026, 6, 22, 0, 10), in: place) == 0)
        #expect(try await hijriOffset(at: try place.date(2026, 6, 22, 3, 0), in: place) == 0)
    }

    private func hijriOffset(at date: Date, in place: DayFixture) async throws -> Int {
        let request = try place.request()
        let day = try await fixture.prayerManager.fetch(at: date, with: request)
        return date.hijriDayOffset(for: day, hijriDayOffset: 0, autoIncrementHijri: true, timeZone: request.timeZone)
    }
}

// MARK: - What screens show

extension PrayerDayRuleTests {
    @Test
    func theUpcomingPrayerIsUnderWayOrStillToComeAndSunriseOnlyToCome() async throws {
        let place = try #require(DayFixture.all.first)
        let days = try await place.days(2, using: fixture.prayerManager)
        let today = days[0]
        let tomorrow = days[1]
        let morning = try place.date(2021, 1, 2, 10, 0)
        let afternoon = try place.date(2021, 1, 2, 13, 0)
        let night = try place.date(2021, 1, 2, 23, 0)

        #expect(today.upcoming(.fajr, at: night) == tomorrow.times[.fajr])
        #expect(today.upcoming(.dhuhr, at: afternoon) == today.times[.dhuhr])
        #expect(today.upcoming(.asr, at: afternoon) == today.times[.asr])
        #expect(today.upcoming(.sunrise, at: morning) == tomorrow.times[.sunrise])
    }

    /// Widget placeholders and previews build from the sample day, so it must hold any moment, as at 01:00.
    @Test(arguments: [(1, 0), (4, 21), (4, 22), (12, 0), (23, 59)])
    func aSampleDayHoldsTheMomentItIsMadeFor(hour: Int, minute: Int) throws {
        let timeZone = try #require(TimeZone(identifier: "America/Toronto"))
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let moment = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: hour, minute: minute)))

        let day = PrayerDay.mock(at: moment, calendar: calendar)

        #expect(day.contains(moment))
        #expect(PrayerTimer.mock(at: moment, prayerDay: day) != nil)
    }

    /// A widget placeholder needs a timer even from a day with nothing under way, which gives none of its own.
    @Test
    func aPlaceholderFromADayWithoutATimerCountsAnHourToASampleAsr() {
        let timer = PrayerTimer.placeholder(from: PrayerDay(date: .now, times: [], tomorrow: []))

        #expect(timer.isPlaceholder)
        #expect(timer.type == .asr)
        #expect(timer.timerType == .countdown)
        #expect(abs(timer.countdownDate.timeIntervalSince(timer.date) - 3600) <= 0.001)
        #expect(abs(timer.timeRemaining - 3600) <= 0.001)
        #expect(abs(timer.progressRemaining - 0.5) <= 0.0001)
        #expect(abs(timer.dangerZone - 0.25) <= 0.0001)
        #expect(!timer.isDangerZone)
        #expect(!timer.isJumuah)
        #expect(!timer.isNamedJumuah)
        #expect(timer.stopwatchEnd == nil)
        #expect(!timer.listsTomorrow)
    }
}

// MARK: - What screens list

extension PrayerDayRuleTests {
    @Test
    func aListTurnsToTomorrowsAtMidnight() async throws {
        let place = try #require(DayFixture.all.first)
        let day = try #require(try await place.days(1, using: fixture.prayerManager).first)
        let calendar = try place.calendar()
        let midnight = try place.date(2021, 1, 3, 0, 0)
        let settings = Settings()

        let listed = day.listedDay(at: midnight + 60, settings: settings, using: calendar)

        #expect(day.turnover(settings: settings, using: calendar) == midnight)
        #expect(day.listedDay(at: midnight - 60, settings: settings, using: calendar) == day)
        #expect(listed.date == midnight)
        #expect(listed.times == day.tomorrow)
        #expect(listed.current(at: midnight + 60) == nil, "Nothing is under way before the listed day's Fajr")
    }

    @Test
    func aCountdownListsTonightsTimesUntilMidnight() async throws {
        let place = try #require(DayFixture.all.first)
        let day = try #require(try await place.days(1, using: fixture.prayerManager).first)
        let isha = try #require(day.times[.isha]).dateInterval.start
        let midnight = try place.date(2021, 1, 3, 0, 0)
        let timeZone = try place.request().timeZone

        func timer(at date: Date, sunriseAfterIsha: Bool = false) throws -> PrayerTimer {
            try #require(
                PrayerTimer(
                    at: date,
                    using: day,
                    iqamaTimes: IqamaTimes(),
                    isIqamaTimerEnabled: false,
                    stopwatchMinutes: 10,
                    preAdhanMinutes: PreAdhanMinutes(rawValue: [:]),
                    sunriseAfterIsha: sunriseAfterIsha,
                    timeZone: timeZone
                )
            )
        }

        #expect(try timer(at: isha + 60).listedTimes == day.times, "Isha's count-up")
        #expect(try timer(at: isha + 20 * 60).listedTimes == day.times, "Counting down to tomorrow's Fajr before midnight")
        #expect(try timer(at: isha + 20 * 60, sunriseAfterIsha: true).listedTimes == day.times, "Counting down to sunrise")
        #expect(try timer(at: midnight + 60).listedTimes == day.tomorrow)
        #expect(try timer(at: midnight + 60).listedDay.date == midnight)
    }

    /// Paris on France 18 begins Isha at 00:19, so its list holds tonight's times through Isha's window.
    @Test
    func anIshaAfterMidnightKeepsTonightsListThroughItsWindow() async throws {
        let place = try #require(DayFixture.all.first { $0.method == .france18 })
        let calendar = try place.calendar()
        let day = try await fixture.prayerManager.fetch(at: try place.date(2026, 6, 22, 0, 25), with: try place.request())
        let isha = try #require(day.times[.isha]).dateInterval.start
        var settings = Settings()
        settings.stopwatchMinutes = 15

        #expect(day.turnover(settings: settings, using: calendar) == isha + 15 * 60, "After the count-up")
        #expect(day.listedDay(at: isha + 10 * 60, settings: settings, using: calendar) == day)
        #expect(day.listedDay(at: isha + 16 * 60, settings: settings, using: calendar).date == (try place.date(2026, 6, 22, 0, 0)))

        settings.iqamaTimes = IqamaTimes(fajr: nil, dhuhr: nil, asr: nil, maghrib: nil, isha: .time(hour: 0, minutes: 30), jumuah: nil)
        #expect(day.turnover(settings: settings, using: calendar) == (try place.date(2026, 6, 22, 0, 30)), "After the iqama")
    }

    @Test
    func aFajrBeforeMidnightIsTheTurnover() async throws {
        let place = try #require(DayFixture.all.first { $0.name.hasPrefix("Edinburgh") })
        let day = try #require(try await place.days(1, using: fixture.prayerManager).first)
        let isha = try #require(day.times[.isha])

        #expect(day.turnover(settings: Settings(), using: try place.calendar()) == isha.dateInterval.end)
    }

    @Test
    func aTimelineTurnsAtALateTurnover() async throws {
        let place = try #require(DayFixture.all.first { $0.method == .france18 })
        let request = try place.request()
        let midnight = try place.date(2026, 6, 22, 0, 0)
        let day = try await fixture.prayerManager.fetch(at: midnight, with: request)
        let turnover = try #require(day.times[.isha]).dateInterval.start + 15 * 60
        var settings = Settings()
        settings.stopwatchMinutes = 15

        let timeline = try await fixture.prayerManager.fetch(
            from: try place.date(2026, 6, 21, 23, 0),
            limit: 20,
            with: request,
            settings: settings,
            timeZone: request.timeZone
        )

        #expect(try #require(timeline.first { $0.date == midnight }).listsTomorrow == false)
        #expect(try #require(timeline.first { $0.date == turnover }).listsTomorrow)
    }

    @Test
    func aDayScreenListsTomorrowsDayAfterTheTurnover() async throws {
        let place = try #require(DayFixture.all.first)
        let request = try place.request()
        let today = try #require(try await place.days(1, using: fixture.prayerManager).first)

        let evening = try await fixture.prayerManager.fetch(listedAt: try place.date(2021, 1, 2, 23, 0), with: request, settings: Settings())
        let night = try await fixture.prayerManager.fetch(listedAt: try place.date(2021, 1, 3, 1, 0), with: request, settings: Settings())

        #expect(evening == today)
        #expect(night.date == (try place.date(2021, 1, 3, 0, 0)))
        #expect(night.times == today.tomorrow)
    }
}
