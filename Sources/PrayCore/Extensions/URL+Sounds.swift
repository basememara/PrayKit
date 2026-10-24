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
}
