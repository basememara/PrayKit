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
        let samples = stride(from: spanStart, to: spanEnd, by: 300).map { $0 }
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
        let place = DayFixture("London timetable after its last day", 51.5074, -0.1278, "Europe/London", .london, 2027, 6, 1)

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
            if timeline.first(where: { $0.date == start }) == nil { problems.append("\(start): no entry for the moment itself") }
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

        let timeline = try await fixture.prayerManager.fetch(
            from: start,
            limit: 10,
            with: request,
            settings: Settings(),
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
        #expect(isha.prefix == june21.date.shortString(timeZone: calendar.timeZone, calendar: calendar, locale: .posix))

        // The calendar days from now leave that Isha out
        let calendarDays = try await fixture.prayerManager.fetch(between: week, with: request)
        let fromCalendarDays = NotificationServiceUN.prayersToNotify(in: calendarDays, from: now, calendar: calendar)
        #expect(!fromCalendarDays.contains { $0.prayerTime.dateInterval.start == ishaBegins })
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
            let days = try await fixture.prayerManager.fetch(spanning: DateInterval(start: now, duration: 7 * 24 * 3600), with: request)
            let scheduled = NotificationServiceUN.prayersToNotify(in: days, from: now, calendar: calendar)
            let identifiers = scheduled.map { "\($0.prefix)-\($0.prayerTime.type)" }
            let starts = scheduled.map(\.prayerTime.dateInterval.start)
            let next = try await fixture.prayerManager.fetch(at: now, with: request).next(at: now)

            if Set(identifiers).count != identifiers.count { problems.append("\(now): an identifier repeats") }
            if starts != starts.sorted() { problems.append("\(now): out of order") }
            if !scheduled.contains(where: { $0.prayerTime == next }) { problems.append("\(now): the next prayer is missing") }
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

    @Test
    func aListShowsFridaysKhutbaForDhuhrByThePrayersOwnDate() throws {
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let calendar = Calendar(identifier: .gregorian, timeZone: timeZone)
        let thursdayDhuhr = try #require(calendar.date(from: DateComponents(year: 2022, month: 11, day: 24, hour: 12, minute: 10)))
        let fridayDhuhr = try #require(calendar.date(from: DateComponents(year: 2022, month: 11, day: 25, hour: 12, minute: 10)))
        let khutba = try #require(calendar.date(from: DateComponents(year: 2022, month: 11, day: 25, hour: 13, minute: 30)))
        let withKhutba = IqamaTimes(fajr: nil, dhuhr: .minutes(15), asr: nil, maghrib: nil, isha: nil, jumuah: .time(hour: 13, minutes: 30))
        let withoutKhutba = IqamaTimes(fajr: nil, dhuhr: .minutes(15), asr: nil, maghrib: nil, isha: nil, jumuah: nil)

        let thursday = PrayerTime(type: .dhuhr, dateInterval: DateInterval(start: thursdayDhuhr, duration: 3 * 3600))
        let friday = PrayerTime(type: .dhuhr, dateInterval: DateInterval(start: fridayDhuhr, duration: 3 * 3600))

        #expect(thursday.listedStart(iqamaTimes: withKhutba, using: calendar) == thursdayDhuhr)
        #expect(friday.listedStart(iqamaTimes: withKhutba, using: calendar) == khutba)
        #expect(friday.listedStart(iqamaTimes: withoutKhutba, using: calendar) == fridayDhuhr)
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

    @Test
    func aCountdownListsTomorrowOnceItCountsPastIsha() async throws {
        let place = try #require(DayFixture.all.first)
        let day = try #require(try await place.days(1, using: fixture.prayerManager).first)
        let isha = try #require(day.times[.isha]).dateInterval.start
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

        #expect(try timer(at: isha - 60).listedTimes == day.times, "Counting down to Isha")
        #expect(try timer(at: isha + 60).listedTimes == day.times, "Isha's stopwatch")
        #expect(try timer(at: isha + 20 * 60).listedTimes == day.tomorrow, "Counting down to tomorrow's Fajr")
        #expect(try timer(at: isha + 20 * 60, sunriseAfterIsha: true).listedTimes == day.tomorrow, "Counting down to tomorrow's sunrise")
    }
}

// MARK: - Fixtures

/// A place, a method and a first calendar day, chosen for the edge it exercises.
struct DayFixture: Sendable, CustomTestStringConvertible {
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String
    let method: CalculationMethod
    let adjustments: PrayerAdjustments?
    let year: Int
    let month: Int
    let day: Int

    var testDescription: String { name }

    init(
        _ name: String,
        _ latitude: Double,
        _ longitude: Double,
        _ timeZoneIdentifier: String,
        _ method: CalculationMethod,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        adjustments: PrayerAdjustments? = nil
    ) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.method = method
        self.adjustments = adjustments
        self.year = year
        self.month = month
        self.day = day
    }

    func request() throws -> PrayerAPI.Request {
        PrayerAPI.Request(
            coordinates: Coordinates(latitude: latitude, longitude: longitude),
            timeZone: try #require(TimeZone(identifier: timeZoneIdentifier)),
            method: method,
            adjustments: adjustments
        )
    }

    func calendar() throws -> Calendar {
        Calendar(identifier: .gregorian, timeZone: try request().timeZone)
    }

    /// Noon on the fixture's first day, in the place's zone.
    func firstNoon() throws -> Date {
        try date(year, month, day, 12)
    }

    /// A wall-clock time in the place's zone.
    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) throws -> Date {
        try #require(try calendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)))
    }

    /// The calendar days from the fixture's first, each fetched on its own.
    func days(_ count: Int, using prayerManager: PrayerManager) async throws -> [PrayerDay] {
        let request = try request()
        let calendar = try calendar()
        let noon = try firstNoon()
        var days = [PrayerDay]()

        for offset in 0..<count {
            let date = try #require(calendar.date(byAdding: .day, value: offset, to: noon))
            days.append(try await prayerManager.fetch(for: date, with: request))
        }

        return days
    }
}

extension DayFixture {
    static let all: [DayFixture] = [
        DayFixture("Toronto in winter", 43.6510, -79.3470, "America/Toronto", .northAmerica, 2021, 1, 2),
        DayFixture("San Francisco in June", 37.773972, -122.431297, "America/Los_Angeles", .northAmerica, 2019, 6, 14),
        DayFixture("Paris on France 18, Isha after midnight", 48.8566, 2.3522, "Europe/Paris", .france18, 2026, 6, 20),
        DayFixture("Reykjavik, Maghrib after midnight", 64.1466, -21.9426, "Atlantic/Reykjavik", .moonsightingCommittee, 2026, 6, 20),
        DayFixture("A Coruña, Isha after midnight", 43.3623, -8.4115, "Europe/Madrid", .muslimWorldLeague, 2026, 7, 4),
        DayFixture("Makkah in Ramadan, Isha 30 minutes later", 21.4225, 39.8262, "Asia/Riyadh", .ummAlQuraRamadan, 2026, 3, 1),
        DayFixture(
            "Kuala Lumpur, Isha 60 minutes after Maghrib", 3.1390, 101.6869, "Asia/Kuala_Lumpur", .jakim, 2026, 10, 12,
            adjustments: .relative(isha: 60)
        ),
        DayFixture(
            "Kuala Lumpur, Isha 120 minutes after Maghrib", 3.1390, 101.6869, "Asia/Kuala_Lumpur", .jakim, 2026, 10, 12,
            adjustments: .relative(isha: 120)
        ),
        DayFixture(
            "Toronto, Fajr 90 minutes before sunrise", 43.6510, -79.3470, "America/Toronto", .moonsightingCommittee, 2026, 10, 12,
            adjustments: .relative(fajr: -90)
        ),
        DayFixture(
            "Edinburgh, Fajr 300 minutes before sunrise, before midnight", 55.9533, -3.1883, "Europe/London", .moonsightingCommittee, 2026, 6, 20,
            adjustments: .relative(fajr: -300)
        ),
        DayFixture("London timetable", 51.5074, -0.1278, "Europe/London", .london, 2022, 2, 25),
        DayFixture(
            "London timetable, Fajr 90 minutes before a later sunrise", 51.5074, -0.1278, "Europe/London", .london, 2022, 2, 25,
            adjustments: .relative(fajr: -90, sunrise: 3)
        ),
        DayFixture("Sydney in winter", -33.8688, 151.2093, "Australia/Sydney", .muslimWorldLeague, 2026, 6, 20),
        DayFixture("Tokyo", 35.6762, 139.6503, "Asia/Tokyo", .muslimWorldLeague, 2026, 10, 12),
        DayFixture("New York, clocks forward", 40.7128, -74.0060, "America/New_York", .northAmerica, 2026, 3, 7),
        DayFixture("New York, clocks back", 40.7128, -74.0060, "America/New_York", .northAmerica, 2026, 10, 31),
        DayFixture("Kuala Lumpur", 3.1390, 101.6869, "Asia/Kuala_Lumpur", .jakim, 2026, 10, 12)
    ]
}

private extension PrayerAdjustments {
    static func relative(fajr: Int = 0, sunrise: Int = 0, isha: Int = 0) -> PrayerAdjustments {
        PrayerAdjustments(
            fajr: fajr,
            sunrise: sunrise,
            dhuhr: 0,
            asr: 0,
            maghrib: 0,
            isha: isha,
            isFajrSunriseRelative: fajr != 0,
            isIshaMaghribRelative: isha != 0,
            elevation: nil
        )
    }
}
