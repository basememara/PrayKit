//
//  LocationRule.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-11.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import CoreLocation.CLLocation
import Foundation

/// How a GPS fix updates the device's place: only while the device follows its location, jitter under a kilometre is
/// ignored unless the time zone changed, a first place proposes its recommended method, and arriving in a new time
/// zone, or anywhere that recommends another method, switches to it unless one was picked by hand or minutes were
/// adjusted, which ask instead.
public enum LocationRule {
    private static let significantDistance: CLLocationDistance = 1_000

    /// The state after a fix taken in `timeZone` at `date`, or `nil` when the fix changes nothing worth saving.
    public static func apply(_ coordinates: Coordinates, timeZone: TimeZone, at date: Date, to state: DeviceState) -> DeviceState? {
        guard state.document.settings.followsLocation else { return nil }

        let place = state.ownPlace
        let hasMoved = place.map { CLLocation(coordinates).distance(from: CLLocation($0.coordinates)) >= significantDistance } ?? true
        let hasChangedTimeZone = place.map { $0.timeZone.identifier != timeZone.identifier } ?? false

        guard hasMoved || hasChangedTimeZone || place?.regionName == nil || place?.fixedAt == nil else {
            return nil
        }

        // A move leaves the old name behind, so the next fix names the new place even if this lookup fails
        let newPlace = Place(coordinates: coordinates, timeZone: timeZone, regionName: hasMoved ? nil : place?.regionName, fixedAt: date)
        let followsThePlace = state.document.settings.manualMethod == nil
        let recommendsAnother = place.map { Settings.placeMethod(at: $0) != Settings.placeMethod(at: newPlace) } ?? false

        let document = if place == nil {
            state.document.proposing { $0.recommendMethod(at: newPlace) }
        } else if followsThePlace, hasChangedTimeZone || recommendsAnother {
            state.document.editing(at: date) { $0.followPlace(newPlace, from: $0.method(at: place)) }
        } else {
            state.document
        }

        return DeviceState(document: document, ownPlace: newPlace)
    }
}

public extension Settings {
    /// Whether this device takes its place from its location: GPS is on for the account and no place is pinned here.
    var followsLocation: Bool {
        isGPSEnabled && !isPlacePinned
    }

    /// Has this device follow its location, which turns GPS on for the account, lets go of the place picked for it
    /// and of one pinned here, so every device follows its own.
    mutating func followLocation() {
        isGPSEnabled = true
        isPlacePinned = false
        pickedPlace = nil
    }

    /// Picks a place for the account, which turns location off and moves every device there.
    mutating func pickPlace(_ place: Place?) {
        isGPSEnabled = false
        isPlacePinned = false
        pickedPlace = place
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

    /// The method the times are calculated with. One that follows the place is the place's own, whatever is stored:
    /// the stored method syncs and may have followed another device elsewhere. One picked by hand is kept, unless it's
    /// a city's timetable away from its time zone, whose times would be read on another clock: then the place's applies.
    func method(at place: Place?) -> CalculationMethod {
        guard let place else { return calculationMethod }
        guard manualMethod != nil, calculationMethod.isReadable(in: place.timeZone) else { return Self.placeMethod(at: place) }
        return calculationMethod
    }

    /// The method to show as chosen: the one picked by hand or, while it follows the place, the place's.
    func chosenMethod(at place: Place?) -> CalculationMethod {
        manualMethod == nil ? method(at: place) : calculationMethod
    }

    /// The method a place recommends over one picked by hand, unless the user kept theirs there.
    func methodSuggestion(at place: Place?) -> CalculationMethod? {
        guard let manualMethod, !manualMethod.keptTimeZones.contains(CalculationMethod.area(at: place)),
              let recommended = CalculationMethod.recommended(at: place), recommended != method(at: place)
        else { return nil }

        return recommended
    }

    /// Upgrades settings saved before picks were recorded, when the time zone alone set the method: one that differs
    /// from the zone's is kept as picked by hand, but not yet kept where the user is, so the place asks about its own
    /// once (old defaults and fallbacks left many there without choosing it). Any other follows the place from now on.
    /// A method already the place's own follows too: another of the account's devices may have upgraded and synced first.
    mutating func upgradeMethod(at place: Place) {
        guard manualMethod == nil else { return }

        guard [Self.placeMethod(for: place.timeZone, at: nil), Self.placeMethod(at: place)].contains(calculationMethod) else {
            manualMethod = ManualMethod(keptTimeZones: [])
            return
        }

        followPlace(place, from: calculationMethod)
    }
}

extension Settings {
    /// Follows the place's recommended method, unless minutes adjusted for the times of `current`, the method in
    /// use until now, would move another's: then that method stays, counted as picked by hand, so the place asks
    /// instead.
    mutating func followPlace(_ place: Place, from current: CalculationMethod) {
        guard Self.placeMethod(at: place) == current || adjustments.isEmpty else {
            calculationMethod = current
            manualMethod = ManualMethod(keptTimeZones: [])
            return
        }

        recommendMethod(at: place)
    }

    static func placeMethod(for timeZone: TimeZone, at coordinates: Coordinates?) -> CalculationMethod {
        .recommended(for: timeZone, at: coordinates) ?? .moonsightingCommittee
    }

    static func placeMethod(at place: Place?) -> CalculationMethod {
        .recommended(at: place) ?? .moonsightingCommittee
    }
}

public extension SettingsStorage {
    /// Saves a place picked by hand as the account's, which turns location off and moves every device there. As on
    /// arriving somewhere new, the method recommended for it applies, unless the method was picked by hand too or
    /// minutes were adjusted.
    @discardableResult
    func setManualPlace(_ coordinates: Coordinates, timeZone: TimeZone, regionName: String?, at date: Date = .now) -> DeviceState {
        let place = Place(coordinates: coordinates, timeZone: timeZone, regionName: regionName, fixedAt: date)

        return update { state in
            state.replacing(
                document: state.document.editing(at: date) {
                    $0.pickPlace(place)

                    guard $0.manualMethod == nil else { return }
                    $0.followPlace(place, from: $0.method(at: state.place))
                }
            )
        }
    }

    /// Saves the place a first-run screen picks and pins it to this device, so the account's other devices go on as
    /// they were. Its recommended method is only proposed, so one chosen on another device still wins when iCloud
    /// brings it.
    @discardableResult
    func setUpPlace(_ coordinates: Coordinates, timeZone: TimeZone, regionName: String?, at date: Date = .now) -> DeviceState {
        let place = Place(coordinates: coordinates, timeZone: timeZone, regionName: regionName, fixedAt: date)

        return update { state in
            DeviceState(
                document: state.document
                    .editing(at: date) { $0.isPlacePinned = true }
                    .proposing { $0.recommendMethod(at: place) },
                ownPlace: place
            )
        }
    }

    /// Has a first-run screen follow this device's location: lets go of a place pinned here, and only proposes location
    /// on for the account, so a city picked on another device still wins, whether iCloud brought it already or later.
    @discardableResult
    func setUpLocation(at date: Date = .now) -> DeviceState {
        update { state in
            state.replacing(
                document: state.document
                    .editing(at: date) { $0.isPlacePinned = false }
                    .proposing { $0.followLocation() }
            )
        }
    }

    /// Turns location on for the account, so every device follows its own. This device starts from the place it's on,
    /// marked for a fresh fix, rather than going back to an old fix of its own until the next one.
    @discardableResult
    func followLocation(at date: Date = .now) -> DeviceState {
        update { state in
            var current = state.place
            current?.fixedAt = nil
            return DeviceState(document: state.document.editing(at: date) { $0.followLocation() }, ownPlace: current)
        }
    }

    /// Turns location off for the account and shares the place this device is on, so every device stays on one place
    /// rather than wherever each last was.
    @discardableResult
    func stopFollowingLocation(at date: Date = .now) -> DeviceState {
        update { state in
            state.replacing(document: state.document.editing(at: date) { $0.pickPlace(state.place) })
        }
    }

    /// Proposes defaults; see `SettingsDocument.proposing(_:)`.
    @discardableResult
    func propose(_ edit: (inout Settings) -> Void) -> DeviceState {
        update { $0.replacing(document: $0.document.proposing(edit)) }
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
            guard var place = state.ownPlace, place.coordinates == coordinates else { return state }
            place.regionName = regionName
            return DeviceState(document: state.document, ownPlace: place)
        }
    }
}

private extension CLLocation {
    convenience init(_ coordinates: Coordinates) {
        self.init(latitude: coordinates.latitude, longitude: coordinates.longitude)
    }
}
