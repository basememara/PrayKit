//
//  URL+Sounds.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-25.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

public extension URL {
    /// Where the sounds that don't ship in the app are downloaded; the notification system finds a sound there by name.
    static var soundsDirectory: URL {
        libraryDirectory.appending(path: "Sounds", directoryHint: .isDirectory)
    }

    /// A sound file: the app's own copy when it ships in the bundle, otherwise where its download lands.
    static func sound(named file: String) -> URL {
        Bundle.main.url(forResource: file, withExtension: nil) ?? soundsDirectory.appending(path: file)
    }
}
