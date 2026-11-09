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
/// time zone changed, and arriving in a new time zone switches to its recommended method unless one was picked by hand.
public enum LocationRule {
    private static let significantDistance: CLLocationDistance = 1_000

    /// The state after a fix taken in `timeZone` at `date`, or `nil` when the fix changes nothing worth saving.
    public static func apply(_ coordinates: Coordinates, timeZone: TimeZone, at date: Date, to state: DeviceState) -> DeviceState? {
        guard state.document.settings.isGPSEnabled else { return nil }

        let place = state.place
        let hasMoved = place.map { CLLocation(coordinates).distance(from: CLLocation($0.coordinates)) >= significantDistance } ?? true
        let hasChangedTimeZone = place.map { $0.timeZone.identifier != timeZone.identifier } ?? false

        guard hasMoved || hasChangedTimeZone || place?.regionName == nil || place?.fixedAt == nil else {
            return nil
        }

        let document = hasChangedTimeZone && state.document.settings.manualMethod == nil
            ? state.document.editing(at: date) { $0.recommendMethod(for: timeZone) }
            : state.document

        return DeviceState(
            document: document,
            // A move leaves the old name behind, so the next fix names the new place even if this lookup fails
            place: Place(coordinates: coordinates, timeZone: timeZone, regionName: hasMoved ? nil : place?.regionName, fixedAt: date)
        )
    }
}

public extension Settings {
    /// Switches to the calculation method recommended for a time zone, the Moonsighting Committee's where
    /// none is, and lets the method follow the place from then on.
    mutating func recommendMethod(for timeZone: TimeZone) {
        calculationMethod = Self.placeMethod(for: timeZone)
        manualMethod = nil
    }

    /// Sets a method picked by hand, kept where it was picked, so only another place asks about it.
    mutating func pickMethod(_ method: CalculationMethod, in timeZone: TimeZone) {
        calculationMethod = method
        manualMethod = ManualMethod(keptTimeZones: [timeZone.identifier])
    }

    /// Keeps the method picked by hand in a time zone that recommends another, so it isn't suggested there again.
    mutating func keepMethod(in timeZone: TimeZone) {
        manualMethod?.keptTimeZones.insert(timeZone.identifier)
    }

    /// The method a time zone recommends over one picked by hand, unless the user kept theirs there.
    func methodSuggestion(in timeZone: TimeZone) -> CalculationMethod? {
        guard let manualMethod, !manualMethod.keptTimeZones.contains(timeZone.identifier),
              let recommended = CalculationMethod.recommended(for: timeZone), recommended != calculationMethod
        else { return nil }

        return recommended
    }

    /// Takes a method that differs from what the place recommends for one picked by hand, for settings saved before
    /// picks were recorded.
    mutating func inferManualMethod(in timeZone: TimeZone) {
        guard manualMethod == nil, calculationMethod != Self.placeMethod(for: timeZone) else { return }
        manualMethod = ManualMethod(keptTimeZones: [timeZone.identifier])
    }
}

extension Settings {
    static func placeMethod(for timeZone: TimeZone) -> CalculationMethod {
        .recommended(for: timeZone) ?? .moonsightingCommittee
    }
}

public extension SettingsStorage {
    /// Saves a place picked by hand. GPS turns off so no fix replaces it, and, as on arriving somewhere new,
    /// the method recommended for its time zone applies, unless the method was picked by hand too.
    @discardableResult
    func setManualPlace(_ coordinates: Coordinates, timeZone: TimeZone, regionName: String?, at date: Date = .now) -> DeviceState {
        update { state in
            DeviceState(
                document: state.document.editing(at: date) {
                    $0.isGPSEnabled = false

                    guard $0.manualMethod == nil else { return }
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
        var isKept = false

        update { state in
            guard let kept = LocationRule.apply(Coordinates(from: location.coordinate), timeZone: timeZone, at: location.timestamp, to: state) else {
                return state
            }

            isKept = true
            return kept
        }

        return isKept
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
