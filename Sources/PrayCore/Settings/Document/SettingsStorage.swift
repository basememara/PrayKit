//
//  SettingsStorage.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

/// Reads and writes a device's settings in the shared defaults suite, under the keys every app version has
/// used, plus one revision next to each value.
///
/// `@unchecked Sendable`: its only state is a `UserDefaults`, which is documented as thread-safe, so any
/// process or thread can use it, including widgets and extensions.
public struct SettingsStorage: @unchecked Sendable {
    /// The suite the settings live in, for reading keys earlier versions left behind.
    public let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private static let lock = NSLock()
}

public extension SettingsStorage {
    /// The stored state; a value that doesn't decode reads as its default and keeps its stored revision.
    func load() -> DeviceState {
        var settings = Settings()
        var revisions = [SettingKey: Revision]()

        Settings.fields.forEach { field in
            field.read(defaults.object(forKey: field.key.rawValue), into: &settings)

            if let milliseconds = (defaults.object(forKey: field.key.revisionKey) as? NSNumber)?.int64Value {
                revisions[field.key] = Revision(milliseconds: milliseconds)
            }
        }

        return DeviceState(
            document: SettingsDocument(settings: settings, revisions: revisions),
            place: readPlace()
        )
    }

    /// Writes whatever `transform` changes, and nothing else, so another process's other settings survive.
    /// Within a process, updates run one at a time, so none is lost to a writer on another thread.
    @discardableResult
    func update(_ transform: (DeviceState) -> DeviceState) -> DeviceState {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        let current = load()
        let updated = transform(current)
        write(updated, over: current)
        return updated
    }

    /// Applies a local edit and stamps the settings it changed.
    @discardableResult
    func edit(at date: Date = .now, _ edit: (inout Settings) -> Void) -> DeviceState {
        update { state in
            DeviceState(document: state.document.editing(at: date, edit), place: state.place)
        }
    }
}

// MARK: - Reading

private extension SettingsStorage {
    func readPlace() -> Place? {
        guard let pair = defaults.object(forKey: PlaceKey.coordinates) as? [Double], pair.count == 2 else {
            return nil
        }

        return Place(
            coordinates: Coordinates(latitude: pair[0], longitude: pair[1]),
            timeZone: defaults.string(forKey: PlaceKey.timeZone).flatMap(TimeZone.init(identifier:)) ?? .current,
            regionName: defaults.string(forKey: PlaceKey.regionName),
            fixedAt: defaults.object(forKey: PlaceKey.fixedAt) as? Date
        )
    }
}

// MARK: - Writing

private extension SettingsStorage {
    func write(_ state: DeviceState, over current: DeviceState) {
        Settings.fields.forEach { field in
            let revision = state.document.revision(of: field.key)

            if !field.isEqual(state.document.settings, current.document.settings) {
                set(field.raw(of: state.document.settings), forKey: field.key.rawValue)
            }

            if revision != current.document.revision(of: field.key) {
                set(revision == .legacy ? nil : NSNumber(value: revision.milliseconds), forKey: field.key.revisionKey)
            }
        }

        guard state.place != current.place else { return }
        writePlace(state.place)
    }

    func writePlace(_ place: Place?) {
        guard let place else {
            defaults.removeObject(forKey: PlaceKey.coordinates)
            return
        }

        defaults.set([place.coordinates.latitude, place.coordinates.longitude], forKey: PlaceKey.coordinates)
        defaults.set(place.timeZone.identifier, forKey: PlaceKey.timeZone)
        set(place.regionName, forKey: PlaceKey.regionName)
        set(place.fixedAt, forKey: PlaceKey.fixedAt)
    }

    func set(_ value: Any?, forKey key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }

        defaults.set(value, forKey: key)
    }
}

/// The keys every app version stores the location under.
private enum PlaceKey {
    static let coordinates = "prayersCoordinates"
    static let timeZone = "lastTimeZoneIdentifier"
    static let regionName = "lastRegionName"
    static let fixedAt = "lastCacheDate"
}
