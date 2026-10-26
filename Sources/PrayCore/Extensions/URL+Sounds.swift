//
//  URL+Sounds.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-25.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

public extension URL {
    /// Where the sounds that don't ship in the app are downloaded; on the iPhone the notification system finds a sound
    /// there by name, while a Mac notification plays only a sound in the app bundle.
    static var soundsDirectory: URL {
        soundsLibrary.appending(path: "Sounds", directoryHint: .isDirectory)
    }

    /// A sound file: the app's own copy when it ships in the bundle, otherwise where its download lands.
    static func sound(named file: String) -> URL {
        Bundle.main.url(forResource: file, withExtension: nil) ?? soundsDirectory.appending(path: file)
    }
}

private extension URL {
    /// A sandboxed Mac app's `Library/Sounds` is the system's link to `~/Library/Sounds`, which the sandbox can't write,
    /// so the Mac keeps its sounds in the `Library` of the App Group its Background Assets use.
    static let soundsLibrary: URL = {
        #if os(macOS)
        if let group = Bundle.main.object(forInfoDictionaryKey: "BAAppGroupID") as? String,
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            return container.appending(path: "Library", directoryHint: .isDirectory)
        }
        #endif

        return libraryDirectory
    }()
}
