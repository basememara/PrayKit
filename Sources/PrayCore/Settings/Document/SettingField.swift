//
//  SettingField.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

extension Settings {
    /// The only list of settings: storage, diffing, merging and the wire all walk it.
    static let fields: [any AnySettingField] = [
        SettingField(.calculationMethod, \.calculationMethod, .string),
        SettingField(.juristicMethod, \.juristicMethod, .string),
        SettingField(.fajrDegrees, \.fajrDegrees, .double),
        SettingField(.maghribDegrees, \.maghribDegrees, .double),
        SettingField(.ishaDegrees, \.ishaDegrees, .double),
        SettingField(.elevationRule, optional: \.elevationRule, .string),
        SettingField(.adjustmentMinutes, optional: \.adjustmentMinutes, .map(.int)),
        SettingField(.adjustmentElevation, optional: \.adjustmentElevation, .string),
        SettingField(.isGPSEnabled, \.isGPSEnabled, .bool),
        SettingField(.geofenceRadius, \.geofenceRadius, .double),
        SettingField(.iqamaTimes, \.iqamaTimes, .json),
        SettingField(.iqamaReminders, \.iqamaReminders, .json),
        SettingField(.isIqamaTimerEnabled, \.isIqamaTimerEnabled, .bool),
        SettingField(.isIqamaHidden, \.isIqamaHidden, .bool),
        SettingField(.enable24hTimeFormat, \.enable24hTimeFormat, .bool),
        SettingField(.hijriDayOffset, \.hijriDayOffset, .int),
        SettingField(.autoIncrementHijri, \.autoIncrementHijri, .bool),
        SettingField(.stopwatchMinutes, \.stopwatchMinutes, .int),
        SettingField(.snoozeMinutes, \.snoozeMinutes, .int),
        SettingField(.preAdhanMinutes, \.preAdhanMinutes, .map(.int)),
        SettingField(.duhaReminder, optional: \.duhaReminder, .json),
        SettingField(.adhanDuaa, \.adhanDuaa, .string),
        SettingField(.notificationAdhan, \.notificationAdhan, .map(.string)),
        SettingField(.notificationSounds, \.notificationSounds, .map(.string)),
        SettingField(.reminderSounds, \.reminderSounds, .map(.string)),
        SettingField(.isPlayOnTapEnabled, \.isPlayOnTapEnabled, .bool),
        SettingField(.isPrayerAbbrEnabled, \.isPrayerAbbrEnabled, .bool),
        SettingField(.sunriseAfterIsha, \.sunriseAfterIsha, .bool),
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

    /// The value on the wire, or `nil` for no field.
    func wire(of settings: Settings) -> WireValue?

    /// Applies a field from the wire, returning `false` when it can't be used and the setting keeps its value.
    func readWire(_ value: WireValue?, into settings: inout Settings) -> Bool

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
    private let decodeWire: @Sendable (WireValue?) -> Value?
    private let encodeWire: @Sendable (Value) -> WireValue?

    init(_ key: SettingKey, _ keyPath: WritableKeyPath<Settings, Value> & Sendable, _ codec: FieldCodec<Value>) {
        self.key = key
        self.keyPath = keyPath
        decode = codec.decode
        encode = codec.encode
        decodeWire = { $0.flatMap(codec.decodeWire) }
        encodeWire = codec.encodeWire
    }

    /// An optional setting, where `nil` removes the key and has no field on the wire.
    init<Wrapped>(
        _ key: SettingKey,
        optional keyPath: WritableKeyPath<Settings, Wrapped?> & Sendable,
        _ codec: FieldCodec<Wrapped>
    ) where Value == Wrapped? {
        self.key = key
        self.keyPath = keyPath
        decode = { codec.decode($0).map { Optional($0) } }
        encode = { $0.flatMap(codec.encode) }
        decodeWire = { field in
            guard let field else { return .some(nil) }
            return codec.decodeWire(field).map { .some($0) }
        }
        encodeWire = { $0.flatMap(codec.encodeWire) }
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

    func wire(of settings: Settings) -> WireValue? {
        encodeWire(settings[keyPath: keyPath])
    }

    func readWire(_ value: WireValue?, into settings: inout Settings) -> Bool {
        guard let decoded = decodeWire(value) else { return false }
        settings[keyPath: keyPath] = decoded
        return true
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

/// How a value is stored in a defaults suite and sent over the wire, matching the encodings `Preferences`
/// and the iCloud record have always used.
struct FieldCodec<Value: Sendable>: Sendable {
    let decode: @Sendable (Any) -> Decoded<Value>
    let encode: @Sendable (Value) -> Any?
    let decodeWire: @Sendable (WireValue) -> Value?
    let encodeWire: @Sendable (Value) -> WireValue?
}

extension FieldCodec where Value == Double {
    static var double: Self {
        Self(
            decode: { ($0 as? Double).map { .value($0) } ?? .unreadable },
            encode: { $0 },
            decodeWire: { wire in
                switch wire {
                case let .double(value):
                    return value
                case let .int(value):
                    return Double(value)
                default:
                    return nil
                }
            },
            encodeWire: { .double($0) }
        )
    }
}

extension FieldCodec where Value == Int {
    static var int: Self {
        Self(
            decode: { ($0 as? Int).map { .value($0) } ?? .unreadable },
            encode: { $0 },
            decodeWire: { wire in
                guard case let .int(value) = wire else { return nil }
                return Int(exactly: value)
            },
            encodeWire: { .int(Int64($0)) }
        )
    }
}

extension FieldCodec where Value == Bool {
    /// A flag, which the iCloud record stores as a number and reads back as "greater than zero".
    static var bool: Self {
        Self(
            decode: { ($0 as? Bool).map { .value($0) } ?? .unreadable },
            encode: { $0 },
            decodeWire: { wire in
                guard case let .int(value) = wire else { return nil }
                return value > 0
            },
            encodeWire: { .int($0 ? 1 : 0) }
        )
    }
}

extension FieldCodec where Value: RawRepresentable, Value.RawValue == String {
    static var string: Self {
        Self(
            decode: { ($0 as? String).flatMap(Value.init(rawValue:)).map { .value($0) } ?? .unreadable },
            encode: { $0.rawValue },
            decodeWire: { wire in
                guard case let .string(value) = wire else { return nil }
                return Value(rawValue: value)
            },
            encodeWire: { .string($0.rawValue) }
        )
    }
}

extension FieldCodec where Value: Codable {
    /// A value stored, and sent, as JSON `Data`.
    static var json: Self {
        Self(
            decode: { raw in
                guard let data = raw as? Data, let value = try? JSONDecoder().decode(Value.self, from: data) else {
                    return .unreadable
                }

                return .value(value)
            },
            encode: { try? JSONEncoder().encode($0) },
            decodeWire: Self.decodeJSON,
            encodeWire: Self.encodeJSON
        )
    }

    /// A per-prayer map, stored as a dictionary whose entries decode one by one, and sent as JSON `Data`.
    static func map<Element: Sendable>(_ element: FieldCodec<Element>) -> Self
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
            encode: { $0.rawValue.compactMapValues(element.encode) },
            decodeWire: Self.decodeJSON,
            encodeWire: Self.encodeJSON
        )
    }

    private static func decodeJSON(_ wire: WireValue) -> Value? {
        guard case let .data(data) = wire else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    /// Sorted keys keep a re-save of an unchanged map byte for byte the same.
    private static func encodeJSON(_ value: Value) -> WireValue? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(value)).map { .data($0) }
    }
}
