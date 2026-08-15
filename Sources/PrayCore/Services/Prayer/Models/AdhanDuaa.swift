//
//  AdhanDuaa.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-04-30.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation.NSURL

public enum AdhanDuaa: String, CaseIterable, Codable {
    case wasilahFadilah = "wasilah.fadilah"
    case announcement = "announcement"
    case off
}

// MARK: - Conformances

extension AdhanDuaa: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Helpers

public extension AdhanDuaa {
    static var `default`: Self { .wasilahFadilah }

    var file: String? {
        switch self {
        case .off, .announcement:
            return nil
        default:
            return "\(rawValue).mp3"
        }
    }

    var fileURL: URL? {
        guard let file else { return nil }
        return self == .default
            ? Bundle.main.url(forResource: file, withExtension: nil)
            : FileManager.default
                .urls(for: .libraryDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Sounds")
                .appendingPathComponent(file)
    }
}
