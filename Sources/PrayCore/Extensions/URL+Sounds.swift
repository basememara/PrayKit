//
//  URL+Sounds.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-25.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

public extension URL {
    /// Where the sounds that don't ship in the app are downloaded, in the App Group the app names as `BAAppGroupID`, so
    /// its extensions read them too. An iPhone notification finds a sound there by name; a Mac notification plays only a
    /// sound in the app bundle.
    static var soundsDirectory: URL {
        soundsLibrary.appending(path: "Sounds", directoryHint: .isDirectory)
    }

    /// A sound file: the app's own copy when it ships in the bundle, otherwise where its download lands.
    static func sound(named file: String) -> URL {
        Bundle.main.url(forResource: file, withExtension: nil) ?? soundsDirectory.appending(path: file)
    }
}

private extension URL {
    /// A process that names no group, such as the watch or the test runner, keeps its own `Library`.
    static let soundsLibrary: URL = {
        if let group = Bundle.main.object(forInfoDictionaryKey: "BAAppGroupID") as? String,
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            return container.appending(path: "Library", directoryHint: .isDirectory)
        }

        return libraryDirectory
    }()
}
