//
//  TimeOrMinutesTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

/// The moment is 2027-01-15 08:00:25 UTC: 16:00 in Kuala Lumpur and 03:00 in Toronto, so whichever zone the test
/// process runs in, one of the two is a place's zone that isn't it.
struct TimeOrMinutesTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_025)

    private static func calendar(_ identifier: String) throws -> Calendar {
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw CalendarError.unknownZone(identifier)
        }
        return Calendar(identifier: .gregorian, timeZone: timeZone)
    }

    private enum CalendarError: Error {
        case unknownZone(String)
    }
}

extension TimeOrMinutesTests {
    @Test(arguments: TimeOrMinutesChoice.allCases)
    func eachChoiceComesBackFromTheSettingItStartsAt(choice: TimeOrMinutesChoice) throws {
        let calendar = try Self.calendar("Asia/Kuala_Lumpur")
        let iqama: IqamaTimes.IqamaType? = choice.setting(startingAt: start, using: calendar)
        let duha: DuhaType? = choice.setting(startingAt: start, using: calendar)

        #expect(iqama.choice == choice)
        #expect(duha.choice == choice)
    }

    @Test(arguments: [("Asia/Kuala_Lumpur", 16), ("America/Toronto", 3)])
    func aTimeStartsAtTheMomentOnThePlacesClock(zone: String, hour: Int) throws {
        let calendar = try Self.calendar(zone)
        let iqama: IqamaTimes.IqamaType? = TimeOrMinutesChoice.time.setting(startingAt: start, using: calendar)
        let duha: DuhaType? = TimeOrMinutesChoice.time.setting(startingAt: start, using: calendar)

        #expect(iqama == .time(hour: hour, minutes: 0))
        #expect(duha == .time(hour: hour, minutes: 0))
    }

    @Test
    func minutesStartAtZeroAndOffIsNone() throws {
        let calendar = try Self.calendar("Asia/Kuala_Lumpur")
        let minutes: IqamaTimes.IqamaType? = TimeOrMinutesChoice.minutes.setting(startingAt: start, using: calendar)
        let off: DuhaType? = TimeOrMinutesChoice.off.setting(startingAt: start, using: calendar)

        #expect(minutes == .minutes(0))
        #expect(off == nil)
    }

    @Test
    func theStepperReadsMinutesOnlyAndWritingHoldsMinutes() {
        var none: IqamaTimes.IqamaType?
        var time: DuhaType? = .time(hour: 7, minutes: 30)
        let minutes: IqamaTimes.IqamaType? = .minutes(12)

        #expect(none.minutes == 0)
        #expect(time.minutes == 0)
        #expect(minutes.minutes == 12)

        none.minutes = 5
        time.minutes = 15

        #expect(none == .minutes(5))
        #expect(time == .minutes(15))
    }

    @Test(arguments: [("Asia/Kuala_Lumpur", 1_799_991_000.0), ("America/Toronto", 1_800_037_800.0)])
    func thePickersDateIsTheTimeOfDayOnThatDayInTheZone(zone: String, expected: TimeInterval) throws {
        let calendar = try Self.calendar(zone)

        #expect(IqamaTimes.IqamaType.time(hour: 13, minutes: 30).date(on: start, using: calendar) == Date(timeIntervalSince1970: expected))
        #expect(DuhaType.time(hour: 13, minutes: 30).date(on: start, using: calendar) == Date(timeIntervalSince1970: expected))
        #expect(IqamaTimes.IqamaType.minutes(10).date(on: start, using: calendar) == nil)
    }

    @Test
    func aDateReadsBackAsItsTimeOfDay() throws {
        let calendar = try Self.calendar("America/Toronto")
        let date = Date(timeIntervalSince1970: 1_800_037_800)

        #expect(IqamaTimes.IqamaType(date: date, using: calendar) == .time(hour: 13, minutes: 30))
        #expect(DuhaType(date: date, using: calendar) == .time(hour: 13, minutes: 30))
    }
}
