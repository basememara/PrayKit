//
//  TimeOrMinutes.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation.NSCalendar
import Foundation.NSDate

/// A setting held as a time of day or as minutes after its prayer begins, as each iqama and the Duha reminder are.
public protocol TimeOrMinutes {
    static func time(hour: Int, minutes: Int) -> Self
    static func minutes(_ minutes: Int) -> Self

    /// The hour and minute of a time of day, nil for minutes.
    var timeOfDay: (hour: Int, minutes: Int)? { get }
    /// The minutes after the prayer begins, nil for a time of day.
    var minutesAfterStart: Int? { get }
}

/// Which form a time-or-minutes setting takes, or none, as a picker offers them.
public enum TimeOrMinutesChoice: Identifiable, CaseIterable, Sendable {
    case off
    case time
    case minutes

    public var id: Self { self }
}

public extension TimeOrMinutes {
    /// The time of day `date` reads in `calendar`.
    init(date: Date, using calendar: Calendar) {
        self = .time(hour: calendar.component(.hour, from: date), minutes: calendar.component(.minute, from: date))
    }

    /// The time of day on `day` in `calendar`, as a time picker shows it: nil for minutes.
    func date(on day: Date, using calendar: Calendar) -> Date? {
        guard let timeOfDay else { return nil }
        return calendar.date(bySettingHour: timeOfDay.hour, minute: timeOfDay.minutes, second: 0, of: day)
    }
}

public extension TimeOrMinutesChoice {
    /// The setting a choice starts at: a time of day at `start` on `calendar`'s clock, no minutes yet, or none.
    func setting<Setting: TimeOrMinutes>(startingAt start: Date, using calendar: Calendar) -> Setting? {
        switch self {
        case .off:
            nil
        case .time:
            Setting(date: start, using: calendar)
        case .minutes:
            Setting.minutes(0)
        }
    }
}

public extension Optional where Wrapped: TimeOrMinutes {
    /// The choice this setting shows as.
    var choice: TimeOrMinutesChoice {
        switch self {
        case nil:
            .off
        case let .some(setting):
            setting.timeOfDay == nil ? .minutes : .time
        }
    }

    /// The minutes a stepper edits: 0 for a time of day or none, and setting it holds minutes.
    var minutes: Int {
        get { self?.minutesAfterStart ?? 0 }
        set { self = Wrapped.minutes(newValue) }
    }
}
