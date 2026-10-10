//
//  SettingField.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

extension Settings {
    /// The only list of settings: storage, diffing and merging all walk it.
    static let fields: [any AnySettingField] = [
        SettingField(.calculationMethod, \.calculationMethod, .string),
        SettingField(.juristicMethod, \.juristicMethod, .string),
        SettingField(.fajrDegrees, \.fajrDegrees, .plain),
        SettingField(.maghribDegrees, \.maghribDegrees, .plain),
        SettingField(.ishaDegrees, \.ishaDegrees, .plain),
        SettingField(.elevationRule, optional: \.elevationRule, .string),
        SettingField(.adjustmentMinutes, optional: \.adjustmentMinutes, .map(.plain)),
        SettingField(.adjustmentElevation, optional: \.adjustmentElevation, .string),
        SettingField(.isGPSEnabled, \.isGPSEnabled, .plain),
        SettingField(.geofenceRadius, \.geofenceRadius, .plain),
        SettingField(.iqamaTimes, \.iqamaTimes, .json),
        SettingField(.iqamaReminders, \.iqamaReminders, .json),
        SettingField(.isIqamaTimerEnabled, \.isIqamaTimerEnabled, .plain),
        SettingField(.isIqamaHidden, \.isIqamaHidden, .plain),
        SettingField(.enable24hTimeFormat, \.enable24hTimeFormat, .plain),
        SettingField(.hijriDayOffset, \.hijriDayOffset, .plain),
        SettingField(.autoIncrementHijri, \.autoIncrementHijri, .plain),
        SettingField(.stopwatchMinutes, \.stopwatchMinutes, .plain),
        SettingField(.snoozeMinutes, \.snoozeMinutes, .plain),
        SettingField(.preAdhanMinutes, \.preAdhanMinutes, .map(.plain)),
        SettingField(.duhaReminder, optional: \.duhaReminder, .json),
        SettingField(.adhanDuaa, \.adhanDuaa, .string),
        SettingField(.notificationAdhan, \.notificationAdhan, .map(.string)),
        SettingField(.notificationSounds, \.notificationSounds, .map(.string)),
        SettingField(.reminderSounds, \.reminderSounds, .map(.string)),
        SettingField(.isPlayOnTapEnabled, \.isPlayOnTapEnabled, .plain),
        SettingField(.isPrayerAbbrEnabled, \.isPrayerAbbrEnabled, .plain),
        SettingField(.sunriseAfterIsha, \.sunriseAfterIsha, .plain),
        SettingField(.appearanceMode, \.appearanceMode, .string),
        SettingField(.theme, \.theme, .string)
    ]
}

// MARK: - Field

/// What reading one stored value found.
enum FieldRead {
    case absent
    case stored

    /// Undecodable, so the setting keeps its default rather than a guess.
    case unreadable
}

/// One setting's knowledge, erased so the table can hold every value type.
protocol AnySettingField: Sendable {
    var key: SettingKey { get }
    func read(_ raw: Any?, into settings: inout Settings) -> FieldRead

    /// The value to store, or `nil` to remove the key.
    func raw(of settings: Settings) -> Any?

    func isEqual(_ lhs: Settings, _ rhs: Settings) -> Bool
    func copy(from source: Settings, into target: inout Settings)

    /// A deterministic order between two different values, so two devices that see the same tie pick the same winner.
    func sortsAfter(_ lhs: Settings, _ rhs: Settings) -> Bool
}

struct SettingField<Value: Codable & Equatable & Sendable>: AnySettingField {
    let key: SettingKey
    private let keyPath: WritableKeyPath<Settings, Value> & Sendable
    private let decode: @Sendable (Any) -> Decoded<Value>
    private let encode: @Sendable (Value) -> Any?

    init(_ key: SettingKey, _ keyPath: WritableKeyPath<Settings, Value> & Sendable, _ codec: DefaultsCodec<Value>) {
        self.key = key
        self.keyPath = keyPath
        decode = codec.decode
        encode = codec.encode
    }

    /// An optional setting, where `nil` removes the key.
    init<Wrapped>(
        _ key: SettingKey,
        optional keyPath: WritableKeyPath<Settings, Wrapped?> & Sendable,
        _ codec: DefaultsCodec<Wrapped>
    ) where Value == Wrapped? {
        self.key = key
        self.keyPath = keyPath
        decode = { codec.decode($0).map { Optional($0) } }
        encode = { $0.flatMap(codec.encode) }
    }

    func read(_ raw: Any?, into settings: inout Settings) -> FieldRead {
        guard let raw else { return .absent }

        switch decode(raw) {
        case let .value(value):
            settings[keyPath: keyPath] = value
            return .stored
        case let .lossy(value):
            settings[keyPath: keyPath] = value
            return .unreadable
        case .unreadable:
            return .unreadable
        }
    }

    func raw(of settings: Settings) -> Any? {
        encode(settings[keyPath: keyPath])
    }

    func isEqual(_ lhs: Settings, _ rhs: Settings) -> Bool {
        lhs[keyPath: keyPath] == rhs[keyPath: keyPath]
    }

    func copy(from source: Settings, into target: inout Settings) {
        target[keyPath: keyPath] = source[keyPath: keyPath]
    }

    func sortsAfter(_ lhs: Settings, _ rhs: Settings) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let left = (try? encoder.encode([lhs[keyPath: keyPath]])) ?? Data()
        let right = (try? encoder.encode([rhs[keyPath: keyPath]])) ?? Data()
        return right.lexicographicallyPrecedes(left)
    }
}

// MARK: - Codec

enum Decoded<Value> {
    case value(Value)

    /// Decoded with some entries dropped, the way `Preferences` reads a map holding a value it doesn't know.
    case lossy(Value)

    case unreadable

    func map<T>(_ transform: (Value) -> T) -> Decoded<T> {
        switch self {
        case let .value(value):
            return .value(transform(value))
        case let .lossy(value):
            return .lossy(transform(value))
        case .unreadable:
            return .unreadable
        }
    }
}

/// How a value is stored in a defaults suite, matching the encodings `Preferences` has always written.
struct DefaultsCodec<Value: Sendable>: Sendable {
    let decode: @Sendable (Any) -> Decoded<Value>
    let encode: @Sendable (Value) -> Any?
}

extension DefaultsCodec {
    /// A value the defaults suite stores natively: `Bool`, `Int`, `Double` or `String`.
    static var plain: Self {
        Self(
            decode: { ($0 as? Value).map { .value($0) } ?? .unreadable },
            encode: { $0 }
        )
    }
}

extension DefaultsCodec where Value: RawRepresentable, Value.RawValue == String {
    static var string: Self {
        Self(
            decode: { ($0 as? String).flatMap(Value.init(rawValue:)).map { .value($0) } ?? .unreadable },
            encode: { $0.rawValue }
        )
    }
}

extension DefaultsCodec where Value: Codable {
    /// A value stored as JSON `Data`.
    static var json: Self {
        Self(
            decode: { raw in
                guard let data = raw as? Data, let value = try? JSONDecoder().decode(Value.self, from: data) else {
                    return .unreadable
                }

                return .value(value)
            },
            encode: { try? JSONEncoder().encode($0) }
        )
    }
}

extension DefaultsCodec {
    /// A per-prayer map stored as a dictionary, whose entries decode one by one.
    static func map<Element: Sendable>(_ element: DefaultsCodec<Element>) -> Self
    where Value: RawRepresentable, Value.RawValue == [String: Element] {
        Self(
            decode: { raw in
                guard let dictionary = raw as? [String: Any] else { return .unreadable }

                let entries = dictionary.compactMapValues { entry -> Element? in
                    guard case let .value(value) = element.decode(entry) else { return nil }
                    return value
                }

                guard let value = Value(rawValue: entries) else { return .unreadable }
                return entries.count == dictionary.count ? .value(value) : .lossy(value)
            },
            encode: { $0.rawValue.compactMapValues(element.encode) }
        )
    }
}
