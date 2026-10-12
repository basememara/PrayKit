//
//  SettingsDocument.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

/// The settings with the revision of each one, so copies from different devices merge setting by setting.
public struct SettingsDocument: Equatable, Sendable {
    public internal(set) var settings: Settings

    /// A setting without an entry is `.legacy`.
    public internal(set) var revisions: [SettingKey: Revision]

    public init(settings: Settings = Settings(), revisions: [SettingKey: Revision] = [:]) {
        self.settings = settings
        self.revisions = revisions.filter { $0.value != .legacy }
    }
}

public extension SettingsDocument {
    func revision(of key: SettingKey) -> Revision {
        revisions[key] ?? .legacy
    }

    /// Takes the newer revision of every setting.
    ///
    /// Equal revisions holding different values resolve by the values themselves, so merging is
    /// associative, commutative and idempotent: copies converge whatever order they arrive in.
    func merging(_ other: SettingsDocument) -> SettingsDocument {
        Settings.fields.reduce(into: self) { result, field in
            let mine = revision(of: field.key)
            let theirs = other.revision(of: field.key)

            guard theirs > mine
                || (theirs == mine && !field.isEqual(settings, other.settings) && field.sortsAfter(other.settings, settings))
            else { return }

            field.copy(from: other.settings, into: &result.settings)
            result.revisions[field.key] = theirs == .legacy ? nil : theirs
        }
    }

    /// Applies a local edit, stamping only the settings whose values changed.
    func editing(at date: Date, _ edit: (inout Settings) -> Void) -> SettingsDocument {
        var edited = settings
        edit(&edited)

        let changed = changedKeys(to: edited)
        guard !changed.isEmpty else { return self }

        let stamp = Revision.stamp(at: date, after: revisions.values.max() ?? .legacy)

        return SettingsDocument(
            settings: edited,
            revisions: changed.reduce(into: revisions) { $0[$1] = stamp }
        )
    }

    /// The settings whose values differ from `other`.
    func changedKeys(to other: Settings) -> [SettingKey] {
        Settings.fields
            .filter { !$0.isEqual(settings, other) }
            .map(\.key)
    }
}

public extension Settings {
    /// Takes only the settings `edited` changed from `original`, so writing back a whole copy can't undo an
    /// edit that reached these settings after the copy was taken.
    mutating func apply(changesFrom original: Settings, to edited: Settings) {
        Settings.fields
            .filter { !$0.isEqual(original, edited) }
            .forEach { $0.copy(from: edited, into: &self) }
    }
}

/// Where prayer times are calculated for: one device's location, which never syncs through iCloud.
public struct Place: Codable, Equatable, Sendable {
    public var coordinates: Coordinates
    public var timeZone: TimeZone
    public var regionName: String?

    /// When the location was fixed; `nil` asks for a fresh fix.
    public var fixedAt: Date?

    public init(coordinates: Coordinates, timeZone: TimeZone, regionName: String?, fixedAt: Date?) {
        self.coordinates = coordinates
        self.timeZone = timeZone
        self.regionName = regionName
        self.fixedAt = fixedAt
    }
}

/// Everything one device knows about the user's settings and location.
public struct DeviceState: Equatable, Sendable {
    public var document: SettingsDocument
    public var place: Place?

    public init(document: SettingsDocument = SettingsDocument(), place: Place? = nil) {
        self.document = document
        self.place = place
    }
}
