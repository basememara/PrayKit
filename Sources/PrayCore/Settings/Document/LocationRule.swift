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
            ? state.document.editing(at: date) { $0.calculationMethod = .recommended(for: timeZone) ?? .moonsightingCommittee }
            : state.document

        return DeviceState(
            document: document,
            place: Place(coordinates: coordinates, timeZone: timeZone, regionName: place?.regionName, fixedAt: date)
        )
    }
}

public extension SettingsStorage {
    /// Saves a GPS fix through the location rule, returning the state as stored.
    @discardableResult
    func saveLocation(_ coordinates: Coordinates, timeZone: TimeZone = .current, at date: Date = .now) -> DeviceState {
        update { LocationRule.apply(coordinates, timeZone: timeZone, at: date, to: $0) ?? $0 }
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
