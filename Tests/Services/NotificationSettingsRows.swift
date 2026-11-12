//
//  NotificationSettingsRows.swift
//  PrayKitTests
//
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
@testable import PrayServices

/// One row of the settings matrix, each a change to the defaults that takes the scheduler down other branches.
struct NotificationSettingsRow: Sendable {
    let id: String
    let settings: Settings
    /// The branches the row is there for, which the matrix must show it reaching.
    let reaches: Set<ScheduleBranch>

    init(_ id: String, reaches: Set<ScheduleBranch>, _ change: (inout Settings) -> Void = { _ in }) {
        var settings = Settings()
        change(&settings)

        self.id = id
        self.settings = settings
        self.reaches = reaches
    }

    /// The length of the iqama update reminder's interval, when the row turns it on.
    var iqamaUpdateInterval: TimeInterval? {
        settings.iqamaReminders.updateInterval.timeInterval
    }

    /// The settings a scheduling run reads, as the row has them.
    var summary: String {
        let prayers = Prayer.allCases.map { prayer in
            let sound = settings.notificationSounds[prayer]?.rawValue ?? "-"
            let reminder = settings.reminderSounds[prayer]?.rawValue ?? "-"
            return "\(prayer.rawValue) \(sound)/\(reminder)/\(settings.preAdhanMinutes[prayer])"
        }

        let iqamaTimes = settings.iqamaTimes
        let iqamas = [iqamaTimes.fajr, iqamaTimes.dhuhr, iqamaTimes.asr, iqamaTimes.maghrib, iqamaTimes.isha, iqamaTimes.jumuah]
            .map { $0?.description ?? "-" }

        let reminders = settings.iqamaReminders

        return [
            "sound/reminder/minutes \(prayers.joined(separator: ", "))",
            "imsak \(settings.preAdhanMinutes.imsak)",
            "duha \(settings.duhaReminder?.description ?? "-")",
            "alarms \(settings.alarms.map(\.rawValue).sorted().joined(separator: "+").nilIfEmpty ?? "-")",
            "iqamas \(iqamas.joined(separator: ", "))",
            "iqama reminder \(reminders.sound.rawValue) \(reminders.minutes)/\(reminders.jumuahMinutes) update \(reminders.updateInterval.rawValue)",
            "follows location \(settings.followsLocation) radius \(Int(settings.geofenceRadius))"
        ].joined(separator: "  ")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension NotificationSettingsRow {
    static let all: [NotificationSettingsRow] = sounds + iqamas + reminders + updates + places + [everythingOn, everythingOff]

    static func row(_ id: String) -> NotificationSettingsRow? {
        all.first { $0.id == id }
    }

    static let defaults = NotificationSettingsRow(
        "defaults",
        reaches: [
            .prayerAdded, .sideTimeAdded, .prayerAddedSilent, .prayerRemoved, .reminderAdded, .reminderRemoved,
            .iqamaUpdateRemoved, .calibrate, .beaconAdded
        ]
    )

    private static let sounds = [
        defaults,
        NotificationSettingsRow("notification-sounds-off", reaches: [.prayerRemoved, .reminderAdded]) { settings in
            Prayer.allCases.forEach { settings.notificationSounds[$0] = .off }
        },
        NotificationSettingsRow("reminder-sounds-off", reaches: [.reminderRemoved, .imsakRemoved, .duhaRemoved]) { settings in
            Prayer.allCases.forEach { settings.reminderSounds[$0] = .off }
            settings.preAdhanMinutes.imsak = 10
            settings.duhaReminder = .minutes(20)
        },
        NotificationSettingsRow("silencing-adhans", reaches: [.prayerAddedSilent]) {
            $0 = $0.silencingAdhans()
        },
        NotificationSettingsRow("sunrise-off", reaches: [.prayerRemoved]) {
            $0.notificationSounds[.sunrise] = .off
        },
        NotificationSettingsRow("sunrise-tone", reaches: [.sideTimeAdded]) {
            $0.notificationSounds[.sunrise] = .tone
        },
        NotificationSettingsRow("night-times", reaches: [.sideTimeAdded, .reminderAdded]) {
            $0.notificationSounds[.midnight] = .tone
            $0.notificationSounds[.lastThird] = .chime
            $0.reminderSounds[.midnight] = .beep
            $0.reminderSounds[.lastThird] = .default
            $0.preAdhanMinutes[.midnight] = 10
            $0.preAdhanMinutes[.lastThird] = 15
        },
        NotificationSettingsRow("mixed-sounds", reaches: [.prayerAdded, .prayerAddedSilent, .prayerRemoved, .reminderRemoved]) {
            $0.notificationAdhan[.fajr] = .makkah
            $0.notificationSounds[.dhuhr] = .tone
            $0.notificationSounds[.asr] = .silent
            $0.notificationSounds[.maghrib] = .vibrate
            $0.notificationSounds[.isha] = .off
            $0.reminderSounds[.fajr] = .off
            $0.reminderSounds[.dhuhr] = .silent
            $0.reminderSounds[.asr] = .beep
        }
    ]

    private static let iqamas = [
        NotificationSettingsRow("iqamas", reaches: [.iqamaAdded, .jumuahIqamaAdded, .jumuahReplacesDhuhr, .iqamaForBegunPrayer]) {
            $0.iqamaTimes = iqamaTimes
            $0.iqamaReminders = IqamaReminders(sound: .iqama, minutes: 10, jumuahMinutes: 45, updateInterval: .off)
        },
        NotificationSettingsRow("iqamas-reminder-off", reaches: [.iqamaRemoved, .prayerAdded]) {
            $0.iqamaTimes = iqamaTimes
            $0.iqamaReminders = IqamaReminders(sound: .off, minutes: 10, jumuahMinutes: 45, updateInterval: .off)
        },
        NotificationSettingsRow("iqamas-reminder-silent", reaches: [.iqamaAddedSilent, .jumuahReplacesDhuhr]) {
            $0.iqamaTimes = iqamaTimes
            $0.iqamaReminders = IqamaReminders(sound: .silent, minutes: 10, jumuahMinutes: 45, updateInterval: .off)
        },
        NotificationSettingsRow("iqamas-minutes-0", reaches: [.prayerAdded]) {
            $0.iqamaTimes = iqamaTimes
            $0.iqamaReminders = IqamaReminders(sound: .iqama, minutes: 0, jumuahMinutes: 0, updateInterval: .off)
        },
        NotificationSettingsRow("iqamas-silencing-adhans", reaches: [.iqamaAdded, .prayerAddedSilent]) {
            $0.iqamaTimes = iqamaTimes
            $0.iqamaReminders = IqamaReminders(sound: .iqama, minutes: 10, jumuahMinutes: 45, updateInterval: .off)
            $0 = $0.silencingAdhans()
        },
        NotificationSettingsRow("khutba-only", reaches: [.jumuahIqamaAdded, .jumuahReplacesDhuhr, .jumuahReminderBeforeKhutba]) {
            $0.iqamaTimes.jumuah = khutba
        },
        NotificationSettingsRow("khutba-minutes", reaches: [.jumuahIqamaAdded, .jumuahReminderBeforeKhutba]) {
            $0.iqamaTimes.jumuah = .minutes(30)
            $0.iqamaReminders = IqamaReminders(sound: .iqama2, minutes: 20, jumuahMinutes: 15, updateInterval: .off)
        }
    ]

    private static let reminders = [
        NotificationSettingsRow("alarms", reaches: [.reminderSilencedByAlarm]) {
            $0.alarms = [.fajr, .sunrise]
            $0.preAdhanMinutes[.fajr] = 30
        },
        NotificationSettingsRow("alarm-without-reminder", reaches: [.reminderAdded]) {
            $0.alarms = [.fajr]
        },
        NotificationSettingsRow("imsak", reaches: [.imsakAdded]) {
            $0.preAdhanMinutes[.fajr] = 15
            $0.preAdhanMinutes.imsak = 10
        },
        NotificationSettingsRow("duha-minutes", reaches: [.duhaAdded]) {
            $0.duhaReminder = .minutes(20)
        },
        NotificationSettingsRow("duha-time", reaches: [.duhaAdded]) {
            $0.duhaReminder = .time(hour: 9, minutes: 0)
        },
        NotificationSettingsRow("duha-zero", reaches: [.reminderAdded]) {
            $0.duhaReminder = .minutes(0)
        },
        NotificationSettingsRow("reminder-minutes", reaches: [.reminderAdded, .jumuahReminderBeforeKhutba]) {
            $0.iqamaTimes.jumuah = khutba
            $0.preAdhanMinutes = PreAdhanMinutes(rawValue: ["fajr": 10, "sunrise": 0, "dhuhr": 25, "asr": 0, "maghrib": 30, "isha": 35])
        }
    ]

    private static let updates = [IqamaReminders.UpdateInterval.weekly, .biweekly, .monthly, .bimonthly].map { interval in
        NotificationSettingsRow(
            "update-\(interval.rawValue)",
            reaches: [.iqamaUpdateKeepsOrigin, .iqamaUpdateStartsNow, .budgetExhausted, .budgetOverdrawn]
        ) {
            $0.iqamaTimes = iqamaTimes
            $0.iqamaReminders = IqamaReminders(sound: .iqama, minutes: 10, jumuahMinutes: 45, updateInterval: interval)
        }
    } + [
        NotificationSettingsRow("update-weekly-no-iqamas", reaches: [.iqamaUpdateRemoved]) {
            $0.iqamaReminders.updateInterval = .weekly
        }
    ]

    private static let places = [
        NotificationSettingsRow("gps-off", reaches: [.beaconRemoved]) {
            $0.isGPSEnabled = false
        },
        NotificationSettingsRow("geofence-0", reaches: [.beaconRemoved]) {
            $0.geofenceRadius = 0
        },
        NotificationSettingsRow("place-pinned", reaches: [.beaconRemoved]) {
            $0.isPlacePinned = true
        }
    ]

    /// Every kind of notification at once, which spends the budget within three days.
    static let everythingOn = NotificationSettingsRow(
        "everything-on",
        reaches: [
            .prayerAdded, .sideTimeAdded, .iqamaAdded, .jumuahIqamaAdded, .reminderAdded, .reminderSilencedByAlarm, .imsakAdded,
            .duhaAdded, .iqamaUpdateStartsNow, .budgetExhausted
        ]
    ) {
        $0.iqamaTimes = iqamaTimes
        $0.iqamaReminders = IqamaReminders(sound: .iqama2, minutes: 10, jumuahMinutes: 45, updateInterval: .weekly)
        $0.preAdhanMinutes = PreAdhanMinutes(
            rawValue: ["fajr": 30, "sunrise": 15, "dhuhr": 20, "asr": 25, "maghrib": 10, "isha": 35, "midnight": 10, "lastThird": 20, "imsak": 10]
        )
        $0.duhaReminder = .minutes(25)
        $0.alarms = [.fajr, .sunrise]
        $0.notificationSounds[.sunrise] = .tone
        $0.notificationSounds[.midnight] = .tone
        $0.notificationSounds[.lastThird] = .chime
        $0.reminderSounds[.midnight] = .beep
        $0.reminderSounds[.lastThird] = .default
    }

    /// Every sound off with iqama times still set, so every removal is taken.
    private static let everythingOff = NotificationSettingsRow(
        "everything-off",
        reaches: [.prayerRemoved, .iqamaRemoved, .reminderRemoved, .imsakRemoved, .duhaRemoved, .iqamaUpdateRemoved, .nothingScheduled]
    ) { settings in
        Prayer.allCases.forEach {
            settings.notificationSounds[$0] = .off
            settings.reminderSounds[$0] = .off
        }

        settings.iqamaTimes = iqamaTimes
        settings.iqamaReminders = IqamaReminders(sound: .off, minutes: 10, jumuahMinutes: 45, updateInterval: .off)
    }

    /// An iqama on every obligatory prayer, some counted from the adhan and some at a time of day, and a khutba.
    private static let iqamaTimes = IqamaTimes(
        fajr: .minutes(20),
        dhuhr: .time(hour: 13, minutes: 30),
        asr: .minutes(15),
        maghrib: .minutes(5),
        isha: .time(hour: 21, minutes: 0),
        jumuah: khutba
    )

    private static let khutba = IqamaTimes.IqamaType.time(hour: 13, minutes: 30)
}

/// A settings row run on a budget, with an origin stored for the iqama update reminder.
struct ScheduleVariant: Sendable {
    let row: NotificationSettingsRow
    let budget: Int
    let origin: ScheduleOrigin

    init(row: NotificationSettingsRow, budget: Int = NotificationPlan.defaultBudget, origin: ScheduleOrigin = .absent) {
        self.row = row
        self.budget = budget
        self.origin = origin
    }

    var id: String {
        row.id + (budget == NotificationPlan.defaultBudget ? "" : ".budget-\(budget)") + (origin == .absent ? "" : ".origin-\(origin.rawValue)")
    }

    /// Every row on each budget, and every stored origin where the row turns the update reminder on.
    static let all: [ScheduleVariant] = NotificationSettingsRow.all.flatMap { row in
        [NotificationPlan.defaultBudget, 20, 7].flatMap { budget in
            (row.iqamaUpdateInterval == nil ? [ScheduleOrigin.absent] : ScheduleOrigin.allCases).map { ScheduleVariant(row: row, budget: budget, origin: $0) }
        }
    }

    func input(from input: ScheduleInput) -> ScheduleInput {
        input.with(
            settings: row.settings,
            budget: budget,
            iqamaUpdateOrigin: row.iqamaUpdateInterval.flatMap { origin.date(from: input.now, interval: $0) }
        )
    }
}
