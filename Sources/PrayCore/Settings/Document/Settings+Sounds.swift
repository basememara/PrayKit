//
//  Settings+Sounds.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation.NSURL
import ZamzamCore

public extension Settings {
    /// Whether every prayer sound and reminder is off and no iqama time is set, so nothing is scheduled.
    var isPrayerSoundsDisabled: Bool {
        notificationSounds.rawValue.allSatisfy { $0.value == .off }
            && reminderSounds.rawValue.allSatisfy { $0.value == .off }
            && iqamaTimes.isEmpty
    }

    mutating func disablePrayerSounds() {
        Prayer.allCases.forEach {
            notificationSounds[$0] = .off
            reminderSounds[$0] = .off
        }

        iqamaTimes = IqamaTimes()
    }

    /// Whether a prayer's notification makes no sound: silent, off, or never set.
    func isMuted(_ prayer: Prayer) -> Bool {
        notificationSounds[prayer].map { [.silent, .off].contains($0) } ?? true
    }

    /// Mutes a prayer to silent, or unmutes it to the sound it had before; the adhan for an obligatory prayer
    /// and a tone for the rest when there is none.
    mutating func setMuted(_ isMuted: Bool, for prayer: Prayer) {
        guard self.isMuted(prayer) != isMuted else { return }

        if isMuted {
            soundsBeforeMute[prayer] = notificationSounds[prayer]
            notificationSounds[prayer] = .silent
        } else {
            notificationSounds[prayer] = soundsBeforeMute[prayer] ?? (prayer.isObligation ? .adhan : .tone)
            soundsBeforeMute[prayer] = nil
        }
    }

    /// Sets the sound a prayer's notification plays, as chosen in a picker, so a later unmute brings back what
    /// was picked last rather than what played before an earlier mute.
    mutating func setSound(_ sound: NotificationSound, for prayer: Prayer) {
        notificationSounds[prayer] = sound
        soundsBeforeMute[prayer] = nil
    }

    /// The sound file a prayer's notification plays, by name: the short adhan when it plays the adhan (a random one
    /// for a shuffle), `nil` when it makes no sound.
    func notificationSoundFile(for prayer: Prayer) -> String? {
        let sound = notificationSounds[prayer] ?? .off
        guard case .adhan = sound else { return sound.file }
        return (notificationAdhan[prayer] ?? .alAqsa).file(for: .short)
    }

    /// Every sound file the notifications can play without the app, by name, so a device can have them on hand;
    /// a shuffled adhan adds none, since it draws only from the adhans already on the device.
    var notificationSoundFiles: Set<String> {
        let prayers = Prayer.allCases
            .filter { notificationSounds[$0] != .adhan || notificationAdhan[$0] != .shuffle }
            .compactMap(notificationSoundFile(for:))

        let reminders = Prayer.allCases.compactMap { reminderSounds[$0]?.file }
        let iqama = iqamaTimes.isEmpty ? nil : iqamaReminders.sound.file

        return Set(prayers + reminders + [iqama].compactMap(\.self))
    }

    /// The adhan the user chose for a prayer, in the length that prayer uses; Al-Aqsa when none is chosen.
    func adhanURL(for prayer: Prayer) -> URL? {
        (notificationAdhan[prayer] ?? .alAqsa).fileURL(for: prayer == .fajr ? .fajr : .long)
    }

    /// Only an obligatory prayer whose sound is the adhan.
    func playsFullAdhan(for prayer: Prayer) -> Bool {
        prayer.isObligation && notificationSounds[prayer] == .adhan
    }

    func silencingAdhans() -> Settings {
        var settings = self
        Prayer.allCases.filter(playsFullAdhan).forEach { settings.notificationSounds[$0] = .silent }
        return settings
    }

    /// Looks through the next day's prayers too, so after Isha it finds tomorrow's Fajr.
    func nextAdhan(after date: Date, in day: PrayerDay) -> PrayerTime? {
        (day.times + day.tomorrow)
            .filter { playsFullAdhan(for: $0.type) && $0.dateInterval.start > date }
            .min { $0.dateInterval.start < $1.dateInterval.start }
    }

    /// An alarm rings at a prayer's reminder time, so it needs one.
    func ringsAlarm(for prayer: Prayer) -> Bool {
        alarms.contains(prayer) && preAdhanMinutes[prayer] > 0
    }

    func alarmTimes(in days: [PrayerDay], after date: Date) -> [PrayerAlarm] {
        days.flatMap(\.times)
            .filter { ringsAlarm(for: $0.type) }
            .map { PrayerAlarm(prayer: $0.type, date: $0.dateInterval.start - .minutes(preAdhanMinutes[$0.type])) }
            .filter { $0.date > date }
    }

    /// The adhan a prayer plays in full, then the duaa after it when chosen and, on Eid, the takbeerat; empty when
    /// the prayer has no adhan file.
    func adhanPlaylist(for prayer: Prayer, at date: Date, timeZone: TimeZone) -> [URL] {
        guard let adhan = adhanURL(for: prayer) else { return [] }
        let isEid = date.isEid(offSet: hijriDayOffset, timeZone: timeZone)
        return [adhan] + [adhanDuaa.fileURL, isEid ? NotificationSound.takbeerEid.fileURL : nil].compactMap(\.self)
    }

    /// The playlist of the prayer under way at `date`: Sunrise's once Fajr ends, and Maghrib's without a day to go by.
    func adhanPlaylist(at date: Date, in day: PrayerDay?, timeZone: TimeZone) -> [URL] {
        adhanPlaylist(for: day?.current(at: date)?.type ?? .maghrib, at: date, timeZone: timeZone)
    }
}
