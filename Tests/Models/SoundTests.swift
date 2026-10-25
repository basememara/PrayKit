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
    @Test
    func aShuffleNeverDrawsItselfOrTheShiaAdhan() {
        #expect(!AdhanSound.shuffleChoices.contains(.shuffle))
        #expect(!AdhanSound.shuffleChoices.contains(.kareemMansouryShia))
    }

    @Test(arguments: AdhanSound.Length.allCases)
    func aShuffleThatCantSeeTheAppsSoundsPlaysTheDefaultAdhan(length: AdhanSound.Length) {
        // The test runner, like an extension, has no sounds in its bundle or its sounds folder
        #expect(AdhanSound.shuffle.file(for: length) == AdhanSound.default.file(for: length))
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
    func everyAnnouncementNamesItsPrayerAndTiming() throws {
        try NotificationSound.allCases.forEach { sound in
            let parts = sound.rawValue.split(separator: ".").map(String.init)

            guard parts.first == "announce" else {
                #expect(sound.announcement == nil, "\(sound)")
                return
            }

            let expected = NotificationSound.Announcement(prayer: try #require(Prayer(rawValue: parts[1])), timing: parts[2] == "soon" ? .soon : .time)
            #expect(sound.announcement == expected, "\(sound)")
        }
    }
}
