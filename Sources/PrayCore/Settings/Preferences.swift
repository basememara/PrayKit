//
//  Preferences.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-05-21.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Combine
import CoreLocation.CLLocation
import Foundation
import ZamzamCore

// swiftlint:disable:next type_body_length
public final class Preferences: @unchecked Sendable {
    public let defaults: UserDefaults

    /// Emits the key path of every changed preference.
    ///
    /// Scoped to the instance: a static subject made two `Preferences` over different
    /// suites notify each other's subscribers.
    private let subject = PassthroughSubject<PartialKeyPath<Preferences>, Never>()

    // MARK: - Calculation

    @Defaults
    public var calculationMethod: CalculationMethod {
        didSet {
            guard calculationMethod != oldValue else { return }
            subject.send(\Preferences.calculationMethod)
        }
    }

    @Defaults
    public var juristicMethod: Madhab {
        didSet {
            guard juristicMethod != oldValue else { return }
            subject.send(\Preferences.juristicMethod)
        }
    }

    @Defaults
    public var fajrDegrees: Double {
        didSet {
            guard fajrDegrees != oldValue else { return }
            subject.send(\Preferences.fajrDegrees)
        }
    }

    @Defaults
    public var maghribDegrees: Double {
        didSet {
            guard maghribDegrees != oldValue else { return }
            subject.send(\Preferences.maghribDegrees)
        }
    }

    @Defaults
    public var ishaDegrees: Double {
        didSet {
            guard ishaDegrees != oldValue else { return }
            subject.send(\Preferences.ishaDegrees)
        }
    }

    @DefaultsOptional
    public var elevationRule: ElevationRule? {
        didSet {
            guard elevationRule != oldValue else { return }
            subject.send(\Preferences.elevationRule)
        }
    }

    // MARK: - Adjustments

    @DefaultsOptional
    public var adjustmentMinutes: AdjustmentMinutes? {
        didSet {
            guard adjustmentMinutes != oldValue else { return }
            subject.send(\Preferences.adjustmentMinutes)
        }
    }

    @DefaultsOptional
    public var adjustmentElevation: ElevationRule? {
        didSet {
            guard adjustmentElevation != oldValue else { return }
            subject.send(\Preferences.adjustmentElevation)
        }
    }

    // MARK: - Location

    @Defaults
    public var isGPSEnabled: Bool {
        didSet {
            guard isGPSEnabled != oldValue else { return }
            subject.send(\Preferences.isGPSEnabled)
        }
    }

    @DefaultsOptional
    public private(set) var prayersCoordinates: Coordinates?

    @Defaults
    public var geofenceRadius: Double {
        didSet {
            guard geofenceRadius != oldValue else { return }
            subject.send(\Preferences.geofenceRadius)
        }
    }

    // MARK: - Iqama

    @Defaults
    public var iqamaTimes: IqamaTimes {
        didSet {
            guard iqamaTimes != oldValue else { return }
            subject.send(\Preferences.iqamaTimes)
        }
    }

    @Defaults
    public var iqamaReminders: IqamaReminders {
        didSet {
            guard iqamaReminders != oldValue else { return }
            subject.send(\Preferences.iqamaReminders)
        }
    }

    @Defaults
    public var isIqamaTimerEnabled: Bool {
        didSet {
            guard isIqamaTimerEnabled != oldValue else { return }
            subject.send(\Preferences.isIqamaTimerEnabled)
        }
    }

    @Defaults
    public var isIqamaHidden: Bool {
        didSet {
            guard isIqamaHidden != oldValue else { return }
            subject.send(\Preferences.isIqamaHidden)
        }
    }

    // MARK: - Time

    @Defaults
    public var enable24hTimeFormat: Bool {
        didSet {
            guard enable24hTimeFormat != oldValue else { return }
            subject.send(\Preferences.enable24hTimeFormat)
        }
    }

    @Defaults
    public var hijriDayOffset: Int {
        didSet {
            guard hijriDayOffset != oldValue else { return }
            subject.send(\Preferences.hijriDayOffset)
        }
    }

    @Defaults
    public var autoIncrementHijri: Bool {
        didSet {
            guard autoIncrementHijri != oldValue else { return }
            subject.send(\Preferences.autoIncrementHijri)
        }
    }

    @Defaults
    public var stopwatchMinutes: Int {
        didSet {
            guard stopwatchMinutes != oldValue else { return }
            subject.send(\Preferences.stopwatchMinutes)
        }
    }

    // MARK: - Notification

    @Defaults
    public var snoozeMinutes: Int {
        didSet {
            guard snoozeMinutes != oldValue else { return }
            subject.send(\Preferences.snoozeMinutes)
        }
    }

    @Defaults
    public var preAdhanMinutes: PreAdhanMinutes {
        didSet {
            guard preAdhanMinutes != oldValue else { return }
            subject.send(\Preferences.preAdhanMinutes)
        }
    }

    @DefaultsOptional
    public var duhaReminder: DuhaType? {
        didSet {
            guard duhaReminder != oldValue else { return }
            subject.send(\Preferences.duhaReminder)
        }
    }

    @Defaults
    public var adhanDuaa: AdhanDuaa {
        didSet {
            guard adhanDuaa != oldValue else { return }
            subject.send(\Preferences.adhanDuaa)
        }
    }

    // MARK: - Sound

    @Defaults
    public var notificationAdhan: NotificationAdhan {
        didSet {
            guard notificationAdhan != oldValue else { return }
            subject.send(\Preferences.notificationAdhan)
        }
    }

    @Defaults
    public var notificationSounds: NotificationSounds {
        didSet {
            guard notificationSounds != oldValue else { return }
            subject.send(\Preferences.notificationSounds)
        }
    }

    @Defaults
    public var reminderSounds: ReminderSounds {
        didSet {
            guard reminderSounds != oldValue else { return }
            subject.send(\Preferences.reminderSounds)
        }
    }

    @Defaults
    public var isPlayOnTapEnabled: Bool {
        didSet {
            guard isPlayOnTapEnabled != oldValue else { return }
            subject.send(\Preferences.isPlayOnTapEnabled)
        }
    }

    // MARK: - Display

    @Defaults
    public var isPrayerAbbrEnabled: Bool {
        didSet {
            guard isPrayerAbbrEnabled != oldValue else { return }
            subject.send(\Preferences.isPrayerAbbrEnabled)
        }
    }

    @Defaults
    public var sunriseAfterIsha: Bool {
        didSet {
            guard sunriseAfterIsha != oldValue else { return }
            subject.send(\Preferences.sunriseAfterIsha)
        }
    }

    @Defaults
    public var appearanceMode: AppearanceMode {
        didSet {
            guard appearanceMode != oldValue else { return }
            subject.send(\Preferences.appearanceMode)
        }
    }

    @Defaults
    public var theme: AppTheme {
        didSet {
            guard theme != oldValue else { return }
            subject.send(\Preferences.theme)
        }
    }

    // MARK: - Cache

    @DefaultsOptional
    public var lastCacheDate: Date? {
        didSet {
            guard lastCacheDate != oldValue else { return }
            subject.send(\Preferences.lastCacheDate)
        }
    }

    @Defaults
    public var lastTimeZone: TimeZone {
        didSet {
            guard lastTimeZone != oldValue else { return }
            subject.send(\Preferences.lastTimeZone)
        }
    }

    @DefaultsOptional
    public var lastRegionName: String? {
        didSet {
            guard lastRegionName != oldValue else { return }
            subject.send(\Preferences.lastRegionName)
        }
    }

    // MARK: - Diagnostics

    @DefaultsOptional
    public var lastDiagnosticsDate: Date? {
        didSet {
            guard lastDiagnosticsDate != oldValue else { return }
            subject.send(\Preferences.lastDiagnosticsDate)
        }
    }

    // MARK: - Configure

    // swiftlint:disable:next function_body_length
    public init(defaults: UserDefaults) {
        self.defaults = defaults

        // Calculation
        _calculationMethod = Defaults("calculationMethod", defaultValue: .moonsightingCommittee, from: defaults)
        _juristicMethod = Defaults("juristicMethod", defaultValue: .standard, from: defaults)
        _fajrDegrees = Defaults("fajrDegrees", defaultValue: 0, from: defaults)
        _maghribDegrees = Defaults("maghribDegrees", defaultValue: 0, from: defaults)
        _ishaDegrees = Defaults("ishaDegrees", defaultValue: 0, from: defaults)
        _elevationRule = DefaultsOptional("elavationMethod", from: defaults)

        // Adjustments
        _adjustmentMinutes = DefaultsOptional("adjustmentMinutes", from: defaults)
        _adjustmentElevation = DefaultsOptional("adjustmentElevation", from: defaults)

        // Location
        _isGPSEnabled = Defaults("isGPSEnabled", defaultValue: true, from: defaults)
        _prayersCoordinates = DefaultsOptional("prayersCoordinates", from: defaults)
        _geofenceRadius = Defaults("geofenceRadius", defaultValue: 75_000, from: defaults)

        // Iqama
        _iqamaTimes = Defaults("iqamaTimes", defaultValue: IqamaTimes(), from: defaults)
        _isIqamaTimerEnabled = Defaults("isIqamaTimerEnabled", defaultValue: true, from: defaults)
        _isIqamaHidden = Defaults("isIqamaHidden", defaultValue: false, from: defaults)

        _iqamaReminders = Defaults(
            "iqamaReminders",
            defaultValue: IqamaReminders(sound: .iqama, minutes: 20, jumuahMinutes: 60, updateInterval: .off),
            from: defaults
        )

        // Time
        _enable24hTimeFormat = Defaults("enable24hTimeFormat", defaultValue: false, from: defaults)
        _hijriDayOffset = Defaults("hijriDayOffset", defaultValue: 0, from: defaults)
        _autoIncrementHijri = Defaults("autoIncrementHijri", defaultValue: true, from: defaults)
        _stopwatchMinutes = Defaults("stopwatchMinutes", defaultValue: 0, from: defaults)

        // Notification
        _snoozeMinutes = Defaults("snoozeMinutes", defaultValue: 30, from: defaults)

        _preAdhanMinutes = Defaults(
            "preAdhanMinutes",
            defaultValue: PreAdhanMinutes(
                rawValue: [
                    Prayer.fajr.rawValue: 0,
                    Prayer.sunrise.rawValue: 20,
                    Prayer.dhuhr.rawValue: 20,
                    Prayer.asr.rawValue: 20,
                    Prayer.maghrib.rawValue: 20,
                    Prayer.isha.rawValue: 20
                ]
            ),
            from: defaults
        )

        _duhaReminder = DefaultsOptional("duhaReminder", from: defaults)
        _adhanDuaa = Defaults("adhanDuaa", defaultValue: .off, from: defaults)

        // Sound
        _notificationAdhan = Defaults(
            "notificationAdhan",
            defaultValue: NotificationAdhan(
                rawValue: [
                    Prayer.fajr.rawValue: .alAqsa,
                    Prayer.sunrise.rawValue: .alAqsa,
                    Prayer.dhuhr.rawValue: .alAqsa,
                    Prayer.asr.rawValue: .alAqsa,
                    Prayer.maghrib.rawValue: .alAqsa,
                    Prayer.isha.rawValue: .alAqsa
                ]
            ),
            from: defaults
        )
        _notificationSounds = Defaults(
            "notificationSounds",
            defaultValue: NotificationSounds(
                rawValue: [
                    Prayer.fajr.rawValue: .adhan,
                    Prayer.sunrise.rawValue: .silent,
                    Prayer.dhuhr.rawValue: .adhan,
                    Prayer.asr.rawValue: .adhan,
                    Prayer.maghrib.rawValue: .adhan,
                    Prayer.isha.rawValue: .adhan,
                    Prayer.midnight.rawValue: .off,
                    Prayer.lastThird.rawValue: .off
                ]
            ),
            from: defaults
        )
        _reminderSounds = Defaults(
            "reminderSounds",
            defaultValue: ReminderSounds(
                rawValue: [
                    Prayer.fajr.rawValue: .default,
                    Prayer.sunrise.rawValue: .default,
                    Prayer.dhuhr.rawValue: .default,
                    Prayer.asr.rawValue: .default,
                    Prayer.maghrib.rawValue: .default,
                    Prayer.isha.rawValue: .default,
                    Prayer.midnight.rawValue: .off,
                    Prayer.lastThird.rawValue: .off
                ]
            ),
            from: defaults
        )

        _isPlayOnTapEnabled = Defaults("isPlayOnTapEnabled", defaultValue: true, from: defaults)

        // Display
        _isPrayerAbbrEnabled = Defaults("isPrayerAbbrEnabled", defaultValue: false, from: defaults)
        _sunriseAfterIsha = Defaults("sunriseAfterIsha", defaultValue: false, from: defaults)
        _appearanceMode = Defaults("appearanceMode", defaultValue: .dark, from: defaults)
        _theme = Defaults("theme", defaultValue: .default, from: defaults)

        // Cache
        _lastRegionName = DefaultsOptional("lastRegionName", from: defaults)
        _lastCacheDate = DefaultsOptional("lastCacheDate", from: defaults)
        _lastTimeZone = Defaults("lastTimeZoneIdentifier", defaultValue: .current, from: defaults)

        // Diagnostics
        _lastDiagnosticsDate = DefaultsOptional("lastDiagnosticsDate", from: defaults)
    }
}

public extension Preferences {
    func key(_ keyPath: PartialKeyPath<Preferences>) -> String {
        switch keyPath {
        case \.calculationMethod:
            return _calculationMethod.key
        case \.juristicMethod:
            return _juristicMethod.key
        case \.fajrDegrees:
            return _fajrDegrees.key
        case \.maghribDegrees:
            return _maghribDegrees.key
        case \.ishaDegrees:
            return _ishaDegrees.key
        case \.elevationRule:
            return _elevationRule.key
        case \.adjustmentMinutes:
            return _adjustmentMinutes.key
        case \.adjustmentElevation:
            return _adjustmentElevation.key
        case \.isGPSEnabled:
            return _isGPSEnabled.key
        case \.prayersCoordinates:
            return _prayersCoordinates.key
        case \.geofenceRadius:
            return _geofenceRadius.key
        case \.iqamaTimes:
            return _iqamaTimes.key
        case \.iqamaReminders:
            return _iqamaReminders.key
        case \.isIqamaTimerEnabled:
            return _isIqamaTimerEnabled.key
        case \.isIqamaHidden:
            return _isIqamaHidden.key
        case \.enable24hTimeFormat:
            return _enable24hTimeFormat.key
        case \.hijriDayOffset:
            return _hijriDayOffset.key
        case \.autoIncrementHijri:
            return _autoIncrementHijri.key
        case \.stopwatchMinutes:
            return _stopwatchMinutes.key
        case \.snoozeMinutes:
            return _snoozeMinutes.key
        case \.preAdhanMinutes:
            return _preAdhanMinutes.key
        case \.duhaReminder:
            return _duhaReminder.key
        case \.adhanDuaa:
            return _adhanDuaa.key
        case \.notificationAdhan:
            return _notificationAdhan.key
        case \.notificationSounds:
            return _notificationSounds.key
        case \.reminderSounds:
            return _reminderSounds.key
        case \.isPlayOnTapEnabled:
            return _isPlayOnTapEnabled.key
        case \.isPrayerAbbrEnabled:
            return _isPrayerAbbrEnabled.key
        case \.sunriseAfterIsha:
            return _sunriseAfterIsha.key
        case \.appearanceMode:
            return _appearanceMode.key
        case \.theme:
            return _theme.key
        case \.lastRegionName:
            return _lastRegionName.key
        case \.lastCacheDate:
            return _lastCacheDate.key
        case \.lastTimeZone:
            return _lastTimeZone.key
        case \.lastDiagnosticsDate:
            return _lastDiagnosticsDate.key
        default:
            assertionFailure("No key defined for property")
            return ""
        }
    }
}

// MARK: - Observers

public extension Preferences {
    func publisher() -> AnyPublisher<PartialKeyPath<Preferences>, Never> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func publisher<Value>(for keyPath: KeyPath<Preferences, Value>, initial: Bool = false) -> AnyPublisher<Value, Never> {
        let basePublisher = publisher()
            .filter { $0 == keyPath }
            .compactMap { self[keyPath: $0] as? Value }

        return initial
            ? basePublisher
                .merge(with: Just(self[keyPath: keyPath]))
                .eraseToAnyPublisher()
            : basePublisher
                .eraseToAnyPublisher()
    }

    func publisher(for keyPaths: [PartialKeyPath<Preferences>]) -> AnyPublisher<Void, Never> {
        publisher()
            .filter { keyPaths.contains($0) }
            .debounce(for: 0.2, scheduler: DispatchQueue.main)
            .map { _ in }
            .eraseToAnyPublisher()
    }
}

public extension Preferences {
    enum KeyPathGroup: Sendable {
        case prayerRecalculation
        case notificationReschedule
        case locationUpdate
        case iCloud
        case extensionReload

        fileprivate var keyPaths: [PartialKeyPath<Preferences>] {
            switch self {
            case .prayerRecalculation:
                return [
                    \.prayersCoordinates,
                     \.calculationMethod,
                     \.juristicMethod,
                     \.fajrDegrees,
                     \.maghribDegrees,
                     \.ishaDegrees,
                     \.elevationRule,
                     \.iqamaTimes,
                     \.adjustmentMinutes,
                     \.adjustmentElevation
                ]
            case .notificationReschedule:
                return [
                    \.snoozeMinutes,
                     \.preAdhanMinutes,
                     \.duhaReminder,
                     \.iqamaTimes,
                     \.iqamaReminders,
                     \.notificationAdhan,
                     \.notificationSounds,
                     \.reminderSounds,
                     \.sunriseAfterIsha,
                     \.geofenceRadius
                ]
            case .locationUpdate:
                return [
                    \.prayersCoordinates,
                     \.lastRegionName,
                     \.lastTimeZone,
                     \.lastCacheDate
                ]
            case .iCloud:
                return (
                    KeyPathGroup.prayerRecalculation.keyPaths
                    + KeyPathGroup.notificationReschedule.keyPaths
                    + [
                        \.isGPSEnabled,
                         \.isIqamaTimerEnabled,
                         \.isIqamaHidden,
                         \.enable24hTimeFormat,
                         \.hijriDayOffset,
                         \.autoIncrementHijri,
                         \.stopwatchMinutes,
                         \.isPlayOnTapEnabled,
                         \.isPrayerAbbrEnabled,
                         \.sunriseAfterIsha,
                         \.appearanceMode,
                         \.theme
                    ]
                )
                .filter { $0 != \.prayersCoordinates }
            case .extensionReload:
                return KeyPathGroup.iCloud.keyPaths + KeyPathGroup.locationUpdate.keyPaths
            }
        }
    }

    func publisher(for keyPathGroups: [KeyPathGroup]) -> AnyPublisher<Void, Never> {
        publisher(
            for: keyPathGroups
                .map(\.keyPaths)
                .reduce([PartialKeyPath<Preferences>](), +) // swiftlint:disable:this reduce_into
        )
    }

    func publisher(for keyPathGroup: KeyPathGroup) -> AnyPublisher<Void, Never> {
        publisher(for: [keyPathGroup])
    }
}

// MARK: - Helpers

public extension Preferences {
    /// A GPS fix closer than this to the saved coordinates is jitter, not a move. Every accepted
    /// update re-runs notification scheduling, iCloud sync and one of the watch's 50 daily
    /// complication transfers, and prayer times do not shift meaningfully under a kilometre.
    static let significantDistance: CLLocationDistance = 1_000

    func set(gpsLocation location: CLLocation) {
        let hasMoved = prayersCoordinates.map {
            location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) >= Self.significantDistance
        } ?? true

        guard hasMoved || lastRegionName == nil || lastCacheDate == nil else { return }
        prayersCoordinates = Coordinates(from: location.coordinate)

        // Update calculation method if significant change if applicable
        if lastTimeZone.identifier != TimeZone.current.identifier && ![.moonsightingCommittee, .muslimWorldLeague].contains(calculationMethod) {
            calculationMethod = .recommended() ?? .moonsightingCommittee
        }

        lastTimeZone = .current
        lastCacheDate = .now
        subject.send(\Preferences.prayersCoordinates)

        // Reverse geocoding is network-bound, so the region name lands after the
        // coordinates rather than holding up prayer recalculation.
        Task { [weak self] in
            let (region, _) = await location.geocoder()
            guard let self, let region else { return }
            lastRegionName = region
        }
    }

    func set(manualAddress coordinates: Coordinates, timeZone: TimeZone, regionName: String?) {
        prayersCoordinates = coordinates
        lastTimeZone = timeZone
        lastRegionName = regionName
        lastCacheDate = .now
        calculationMethod = .recommended(for: timeZone) ?? .moonsightingCommittee
        subject.send(\Preferences.prayersCoordinates)
    }

    func set(gpsOrManualCoordinates coordinates: Coordinates, timeZone: TimeZone, regionName: String?) {
        guard coordinates != prayersCoordinates || lastRegionName == nil || lastCacheDate == nil else { return }
        prayersCoordinates = coordinates
        lastTimeZone = timeZone
        lastRegionName = regionName
        subject.send(\Preferences.prayersCoordinates)
    }
}

public extension Preferences {
    var isPrayerSoundsDisabled: Bool {
        notificationSounds.rawValue.allSatisfy { $0.value == .off }
            && reminderSounds.rawValue.allSatisfy { $0.value == .off }
            && iqamaTimes.isEmpty
    }

    func disablePrayerSounds() {
        Prayer.allCases.forEach {
            notificationSounds[$0] = .off
            reminderSounds[$0] = .off
        }

        iqamaTimes = IqamaTimes()
    }
}

public extension Preferences {
    func expandedTimeline(for prayerTime: PrayerTime, using calendar: Calendar? = nil) -> [Date] {
        let calendar = calendar ?? {
            var current = Calendar.current
            current.timeZone = lastTimeZone
            return current
        }()

        var dates = [prayerTime.dateInterval.start]

        let reminderMinutes = preAdhanMinutes[prayerTime.type]
        if reminderMinutes > 0 && prayerTime.dateInterval.duration > Double(reminderMinutes) * 60 {
            dates.append(prayerTime.dateInterval.start - .minutes(reminderMinutes))
        }

        // Add iqama countdown
        if isIqamaTimerEnabled, let iqamaTime = iqamaTimes[prayerTime, using: calendar] {
            dates.append(iqamaTime)
        }

        // Add since prayer adhan
        if stopwatchMinutes > 0 && prayerTime.dateInterval.duration > Double(stopwatchMinutes) * 60 {
            dates.append(prayerTime.dateInterval.start + .minutes(stopwatchMinutes))
        }

        return dates
            .removeDuplicates()
            .sorted()
    }
}

// MARK: - Conformances

extension CalculationMethod: UserDefaultsRepresentable {}
extension Madhab: UserDefaultsRepresentable {}
extension ElevationRule: UserDefaultsRepresentable {}
extension AdjustmentMinutes: UserDefaultsRepresentable {}
extension Map: UserDefaultsRepresentable {}
extension AdhanSound: UserDefaultsRepresentable {}
extension NotificationAdhan: UserDefaultsRepresentable {}
extension NotificationSound: UserDefaultsRepresentable {}
extension NotificationSounds: UserDefaultsRepresentable {}
extension ReminderSounds: UserDefaultsRepresentable {}
extension PreAdhanMinutes: UserDefaultsRepresentable {}
extension AdhanDuaa: UserDefaultsRepresentable {}
extension AppearanceMode: UserDefaultsRepresentable {}
extension AppTheme: UserDefaultsRepresentable {}

extension TimeZone: @retroactive UserDefaultsRepresentable {
    public var rawDefaultsValue: String { identifier }

    public init(rawDefaultsValue: String) {
        self = TimeZone(identifier: rawDefaultsValue) ?? .current
    }
}

extension Coordinates: UserDefaultsRepresentable {
    public var rawDefaultsValue: [Double] { [latitude, longitude] }

    public init(rawDefaultsValue: [Double]) {
        guard rawDefaultsValue.count == 2 else {
            self = Coordinates(latitude: 0, longitude: 0)
            return
        }

        self = Coordinates(latitude: rawDefaultsValue[0], longitude: rawDefaultsValue[1])
    }
}

extension DuhaType: UserDefaultsRepresentable {
    public var rawDefaultsValue: Data? { try? encode() }

    public init?(rawDefaultsValue: Data?) {
        guard let value: DuhaType = try? rawDefaultsValue?.decode() else { return nil }
        self = value
    }
}

extension IqamaTimes: UserDefaultsRepresentable {
    public var rawDefaultsValue: Data? { try? encode() }

    public init(rawDefaultsValue: Data?) {
        guard let value: IqamaTimes = try? rawDefaultsValue?.decode() else {
            self.init()
            return
        }

        self = value
    }
}

extension IqamaReminders: UserDefaultsRepresentable {
    public var rawDefaultsValue: Data? { try? encode() }

    public init?(rawDefaultsValue: Data?) {
        guard let value: IqamaReminders = try? rawDefaultsValue?.decode() else { return nil }
        self = value
    }
}
