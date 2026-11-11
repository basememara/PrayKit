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
/// time zone changed, and arriving in a new time zone, or anywhere that recommends another method, switches to its
/// recommended method unless one was picked by hand.
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

        // A move leaves the old name behind, so the next fix names the new place even if this lookup fails
        let newPlace = Place(coordinates: coordinates, timeZone: timeZone, regionName: hasMoved ? nil : place?.regionName, fixedAt: date)
        let followsThePlace = state.document.settings.followsThePlace(in: timeZone)
        let recommendsAnother = place.map { Settings.placeMethod(at: $0) != Settings.placeMethod(at: newPlace) } ?? false

        let document = followsThePlace && (hasChangedTimeZone || recommendsAnother)
            ? state.document.editing(at: date) { $0.recommendMethod(at: newPlace) }
            : state.document

        return DeviceState(document: document, place: newPlace)
    }
}

/// A `nil` place is one not yet known, where the device's time zone decides.
public extension Settings {
    /// Switches to the calculation method recommended for a place, the Moonsighting Committee's where
    /// none is, and lets the method follow the place from then on.
    mutating func recommendMethod(at place: Place?) {
        calculationMethod = Self.placeMethod(at: place)
        manualMethod = nil
    }

    /// Sets a method picked by hand, kept where it was picked, so only another place asks about it.
    mutating func pickMethod(_ method: CalculationMethod, at place: Place?) {
        calculationMethod = method
        manualMethod = ManualMethod(keptTimeZones: [CalculationMethod.area(at: place)])
    }

    /// Keeps the method picked by hand in a place that recommends another, so it isn't suggested there again.
    mutating func keepMethod(at place: Place?) {
        manualMethod?.keptTimeZones.insert(CalculationMethod.area(at: place))
    }

    /// Whether the method changes with the place: it does unless picked by hand, and a city's timetable picked by hand
    /// still does outside its time zone, where its times would be read on another clock.
    func followsThePlace(in timeZone: TimeZone) -> Bool {
        manualMethod == nil || !calculationMethod.isReadable(in: timeZone)
    }

    /// The method a place recommends over one picked by hand, unless the user kept theirs there.
    func methodSuggestion(at place: Place?) -> CalculationMethod? {
        guard let manualMethod, !manualMethod.keptTimeZones.contains(CalculationMethod.area(at: place)),
              let recommended = CalculationMethod.recommended(at: place), recommended != calculationMethod
        else { return nil }

        return recommended
    }

    /// Upgrades settings saved before picks were recorded, when the time zone alone set the method: one that differs
    /// from the zone's was picked by hand and is kept where the user is, and any other follows the place from now on.
    mutating func upgradeMethod(at place: Place) {
        guard manualMethod == nil else { return }

        guard calculationMethod == Self.placeMethod(for: place.timeZone, at: nil) else {
            manualMethod = ManualMethod(keptTimeZones: [CalculationMethod.area(at: place)])
            return
        }

        // Minutes tuned to this method's times would move another's, so a user who adjusted any is asked instead
        guard Self.placeMethod(at: place) == calculationMethod || adjustmentMinutes?.isEmpty ?? true else {
            manualMethod = ManualMethod(keptTimeZones: [])
            return
        }

        recommendMethod(at: place)
    }
}

extension Settings {
    static func placeMethod(for timeZone: TimeZone, at coordinates: Coordinates?) -> CalculationMethod {
        .recommended(for: timeZone, at: coordinates) ?? .moonsightingCommittee
    }

    static func placeMethod(at place: Place?) -> CalculationMethod {
        .recommended(at: place) ?? .moonsightingCommittee
    }
}

public extension SettingsStorage {
    /// Saves a place picked by hand. GPS turns off so no fix replaces it, and, as on arriving somewhere new,
    /// the method recommended for its time zone applies, unless the method was picked by hand too.
    @discardableResult
    func setManualPlace(_ coordinates: Coordinates, timeZone: TimeZone, regionName: String?, at date: Date = .now) -> DeviceState {
        let place = Place(coordinates: coordinates, timeZone: timeZone, regionName: regionName, fixedAt: date)

        return update { state in
            DeviceState(
                document: state.document.editing(at: date) {
                    $0.isGPSEnabled = false

                    guard $0.followsThePlace(in: timeZone) else { return }
                    $0.recommendMethod(at: place)
                },
                place: place
            )
        }
    }

    /// Saves the place a first-run screen picks, as `setManualPlace` does, but only proposes its recommended
    /// method, so a method chosen on another device still wins when iCloud brings it.
    @discardableResult
    func setUpPlace(_ coordinates: Coordinates, timeZone: TimeZone, regionName: String?, at date: Date = .now) -> DeviceState {
        let place = Place(coordinates: coordinates, timeZone: timeZone, regionName: regionName, fixedAt: date)

        return update { state in
            DeviceState(
                document: state.document
                    .editing(at: date) { $0.isGPSEnabled = false }
                    .proposing { $0.recommendMethod(at: place) },
                place: place
            )
        }
    }

    /// Proposes defaults; see `SettingsDocument.proposing(_:)`.
    @discardableResult
    func propose(_ edit: (inout Settings) -> Void) -> DeviceState {
        update { DeviceState(document: $0.document.proposing(edit), place: $0.place) }
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
