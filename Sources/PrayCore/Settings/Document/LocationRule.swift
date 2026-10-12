//
//  LocationRule.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import CoreLocation.CLLocation
import Foundation

/// How a GPS fix updates the device's place: only while GPS is on, jitter under a kilometre is ignored unless the
/// time zone changed, and arriving in a new time zone switches to its recommended method.
public enum LocationRule {
    public static let significantDistance: CLLocationDistance = 1_000

    /// The state after a fix taken in `timeZone` at `date`, or `nil` when the fix changes nothing worth saving.
    public static func apply(_ coordinates: Coordinates, timeZone: TimeZone, at date: Date, to state: DeviceState) -> DeviceState? {
        guard state.document.settings.isGPSEnabled else { return nil }

        let place = state.place
        let hasMoved = place.map { CLLocation(coordinates).distance(from: CLLocation($0.coordinates)) >= significantDistance } ?? true
        let hasChangedTimeZone = place.map { $0.timeZone.identifier != timeZone.identifier } ?? false

        guard hasMoved || hasChangedTimeZone || place?.regionName == nil || place?.fixedAt == nil else {
            return nil
        }

        let method = state.document.settings.calculationMethod
        let document = hasChangedTimeZone && ![.moonsightingCommittee, .muslimWorldLeague].contains(method)
            ? state.document.editing(at: date) { $0.recommendMethod(for: timeZone) }
            : state.document

        return DeviceState(
            document: document,
            place: Place(coordinates: coordinates, timeZone: timeZone, regionName: place?.regionName, fixedAt: date)
        )
    }
}

public extension Settings {
    /// Switches to the calculation method recommended for a time zone, the Moonsighting Committee's where
    /// none is.
    mutating func recommendMethod(for timeZone: TimeZone) {
        calculationMethod = .recommended(for: timeZone) ?? .moonsightingCommittee
    }
}

public extension SettingsStorage {
    /// Saves a place picked by hand. GPS turns off so no fix replaces it, and, as on arriving somewhere new,
    /// the method recommended for its time zone applies.
    @discardableResult
    func setManualPlace(_ coordinates: Coordinates, timeZone: TimeZone, regionName: String?, at date: Date = .now) -> DeviceState {
        update { state in
            DeviceState(
                document: state.document.editing(at: date) {
                    $0.isGPSEnabled = false
                    $0.recommendMethod(for: timeZone)
                },
                place: Place(coordinates: coordinates, timeZone: timeZone, regionName: regionName, fixedAt: date)
            )
        }
    }

    /// Saves a GPS fix through the location rule, returning the state as stored.
    @discardableResult
    func saveLocation(_ coordinates: Coordinates, timeZone: TimeZone = .current, at date: Date = .now) -> DeviceState {
        update { LocationRule.apply(coordinates, timeZone: timeZone, at: date, to: $0) ?? $0 }
    }

    /// Saves a GPS fix through the location rule, dated when it was taken, returning whether the rule kept it.
    @discardableResult
    func saveLocation(_ location: CLLocation, timeZone: TimeZone = .current) -> Bool {
        let before = load()
        return saveLocation(Coordinates(from: location.coordinate), timeZone: timeZone, at: location.timestamp) != before
    }

    /// Names the saved place by reverse geocoding the fix, unless a newer fix moved it in the meantime.
    func nameLocation(_ location: CLLocation) async {
        guard let regionName = await location.geocoder().0 else { return }
        saveRegionName(regionName, for: Coordinates(from: location.coordinate))
    }

    /// Names the saved place once reverse geocoding returns, unless a newer fix moved it in the meantime.
    @discardableResult
    func saveRegionName(_ regionName: String, for coordinates: Coordinates) -> DeviceState {
        update { state in
            guard var place = state.place, place.coordinates == coordinates else { return state }
            place.regionName = regionName
            return DeviceState(document: state.document, place: place)
        }
    }
}

private extension CLLocation {
    convenience init(_ coordinates: Coordinates) {
        self.init(latitude: coordinates.latitude, longitude: coordinates.longitude)
    }
}
