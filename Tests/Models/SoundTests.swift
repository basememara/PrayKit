//
//  SoundTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-25.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct SoundTests {
    @Test(arguments: AdhanSound.Length.allCases)
    func aShuffleOnlyPlaysARealAdhanInTheLengthAsked(length: AdhanSound.Length) {
        let files = Set(AdhanSound.shuffleChoices.map { $0.file(for: length) })

        // One draw in 48 picked the shuffle itself before it was left out, so many draws catch a regression
        (0..<500).forEach { _ in
            let file = AdhanSound.shuffle.file(for: length)
            #expect(files.contains(file), "\(file)")
        }
    }

    @Test
    func anAdhanWithAFajrVersionPlaysItAtFajr() {
        #expect(AdhanSound.makkah.file(for: .fajr) == "makkah-fajr.mp3")
        #expect(AdhanSound.egypt.file(for: .fajr) == "egypt.mp3")
    }

    @Test
    func aDownloadedSoundLivesInTheSoundsFolder() throws {
        let url = try #require(NotificationSound.alert.fileURL)
        #expect(url == URL.soundsDirectory.appending(path: "alert.m4a"))
    }

    @Test
    func everyAnnouncementNamesItsPrayerAndTiming() {
        NotificationSound.allCases.forEach { sound in
            let parts = sound.rawValue.split(separator: ".").map(String.init)

            guard parts.first == "announce" else {
                #expect(sound.announcement == nil, "\(sound)")
                return
            }

            let expected = NotificationSound.Announcement(prayer: Prayer(rawValue: parts[1]) ?? .sunrise, timing: parts[2] == "soon" ? .soon : .time)
            #expect(sound.announcement == expected, "\(sound)")
        }
    }

    @Test
    func aPrayersNotificationFileMatchesTheRuleTheSchedulerShippedWith() {
        // The scheduler's private rule before it moved to Settings, kept here so the move can't change a sound
        func shippedFile(for prayer: Prayer, in settings: Settings) -> String? {
            let sound = settings.notificationSounds[prayer] ?? .off
            guard case .adhan = sound else { return sound.file }
            return (settings.notificationAdhan[prayer] ?? .alAqsa).file(for: .short)
        }

        Prayer.allCases.forEach { prayer in
            NotificationSound.allCases.forEach { sound in
                AdhanSound.shuffleChoices.forEach { adhan in
                    var settings = Settings()
                    settings.setSound(sound, for: prayer)
                    settings.notificationAdhan[prayer] = adhan

                    #expect(settings.notificationSoundFile(for: prayer) == shippedFile(for: prayer, in: settings), "\(prayer) \(sound) \(adhan)")
                }
            }
        }
    }

    @Test
    func aDownloadedSoundIsWhereTheShippedPathPutIt() throws {
        let library = try #require(FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first)
        let shipped = { (file: String) in library.appendingPathComponent("Sounds").appendingPathComponent(file) }

        try AdhanSound.shuffleChoices.filter { $0 != .default }.forEach { adhan in
            try AdhanSound.Length.allCases.forEach { length in
                let url = try #require(adhan.fileURL(for: length))
                #expect(url.path == shipped(adhan.file(for: length)).path, "\(adhan) \(length)")
            }
        }

        try NotificationSound.allCases.filter { $0.file != nil && ![.default, .vibrate].contains($0) }.forEach { sound in
            let url = try #require(sound.fileURL)
            #expect(url.path == shipped(try #require(sound.file)).path, "\(sound)")
        }
    }
}
