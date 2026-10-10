//
//  SettingsStorage.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

/// Reads and writes a device's settings in the shared defaults suite, under the keys `Preferences` uses,
/// plus one revision next to each value.
///
/// `@unchecked Sendable`: its only state is a `UserDefaults`, which is documented as thread-safe, so any
/// process or thread can use it, including widgets and extensions.
public struct SettingsStorage: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }
}

public extension SettingsStorage {
    func load() -> DeviceState {
        read().state
    }

    /// Settings whose stored value does not decode. They read as their defaults and carry the stored revision.
    func unreadableKeys() -> [SettingKey] {
        read().unreadable
    }

    /// Writes whatever `transform` changes, and nothing else, so a concurrent writer's other settings survive.
    @discardableResult
    func update(_ transform: (DeviceState) -> DeviceState) -> DeviceState {
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
    func read() -> (state: DeviceState, unreadable: [SettingKey]) {
        var settings = Settings()
        var revisions = [SettingKey: Revision]()
        var unreadable = [SettingKey]()

        Settings.fields.forEach { field in
            if field.read(defaults.object(forKey: field.key.rawValue), into: &settings) == .unreadable {
                unreadable.append(field.key)
            }

            if let milliseconds = (defaults.object(forKey: field.key.revisionKey) as? NSNumber)?.int64Value {
                revisions[field.key] = Revision(milliseconds: milliseconds)
            }
        }

        let state = DeviceState(
            document: SettingsDocument(settings: settings, revisions: revisions),
            place: readPlace()
        )

        return (state, unreadable)
    }

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

/// The keys `Preferences` stores the location under.
private enum PlaceKey {
    static let coordinates = "prayersCoordinates"
    static let timeZone = "lastTimeZoneIdentifier"
    static let regionName = "lastRegionName"
    static let fixedAt = "lastCacheDate"
}
