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
}
