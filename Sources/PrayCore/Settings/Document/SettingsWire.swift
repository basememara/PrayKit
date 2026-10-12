//
//  SettingsWire.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

/// A field value both a CloudKit record and a property list can carry.
public enum WireValue: Hashable, Codable, Sendable {
    case int(Int64)
    case double(Double)
    case string(String)
    case data(Data)
}

public extension WireValue {
    /// The value as the Foundation object a CloudKit record field or a property list holds.
    var object: NSObject {
        switch self {
        case let .int(value):
            return NSNumber(value: value)
        case let .double(value):
            return NSNumber(value: value)
        case let .string(value):
            return value as NSString
        case let .data(value):
            return value as NSData
        }
    }

    /// Reads a CloudKit record field or a property-list value; flags arrive as integers.
    init?(object: Any) {
        switch object {
        case let value as String:
            self = .string(value)
        case let value as Data:
            self = .data(value)
        case let value as NSNumber:
            self = CFNumberIsFloatType(value) ? .double(value.doubleValue) : .int(value.int64Value)
        default:
            return nil
        }
    }
}

extension WireValue {
    var integer: Int64? {
        guard case let .int(value) = self else { return nil }
        return value
    }
}

public extension SettingsDocument {
    /// The synced settings and their revisions, as the fields of the iCloud record and of the watch payload.
    ///
    /// Each setting is a field under its key, encoded the way older app versions read it, and a revised
    /// setting adds `"<key>_at"`. A `nil` setting has no field.
    var wireFields: [String: WireValue] {
        Settings.fields
            .filter(\.isSynced)
            .reduce(into: [:]) { fields, field in
                fields[field.key.rawValue] = field.wire(of: settings)

                let revision = revision(of: field.key)
                guard revision != .legacy else { return }
                fields[field.key.revisionKey] = .int(revision.milliseconds)
            }
    }

    /// Reads a copy that arrived over the wire.
    ///
    /// - Parameters:
    ///   - fields: The copy's fields.
    ///   - base: This device's settings, kept for any setting the copy doesn't carry or can't decode.
    ///   - modifiedAt: When the copy was saved. A setting with no revision of its own, or one an older app
    ///     version changed without updating its revision, takes this time.
    ///   - previous: The fields of the last copy from the same place, so a setting that hasn't changed since
    ///     isn't mistaken for a new change. `nil` on first sight.
    init(wireFields fields: [String: WireValue], base: Settings, modifiedAt: Date, previous: [String: WireValue]?) {
        var settings = base
        var revisions = [SettingKey: Revision]()

        Settings.fields
            .filter(\.isSynced)
            .forEach { field in
                let value = fields[field.key.rawValue]
                let revisionField = fields[field.key.revisionKey]
                let stamped = revisionField?.integer.map(Revision.init(milliseconds:))

                guard field.readWire(value, into: &settings) else {
                    // A value from a newer app version keeps this device's value under the copy's revision, so
                    // neither device counts as behind and they don't take turns overwriting each other
                    if value != nil, let stamped {
                        revisions[field.key] = stamped
                    }

                    return
                }

                let isUnrevisedChange = previous.map { previous in
                    // A setting the last copy never carried is new to the copy, not changed by an older version
                    guard previous[field.key.rawValue] != nil || field.isOptional else { return false }

                    var seen = settings
                    let isChanged = !field.readWire(previous[field.key.rawValue], into: &seen) || !field.isEqual(seen, settings)
                    return isChanged && previous[field.key.revisionKey] == revisionField
                } ?? (stamped == nil)

                // Never below a revision it replaces, which a device with a fast clock may have set ahead of the save
                revisions[field.key] = isUnrevisedChange
                    ? stamped.map { Revision.stamp(at: modifiedAt, after: $0) } ?? Revision(modifiedAt)
                    : stamped
            }

        self.init(settings: settings, revisions: revisions)
    }

    /// Merges a copy from a device this one follows, such as the watch's iPhone: where neither side has
    /// revised a setting, the copy's value wins instead of the tie-break.
    func adopting(_ other: SettingsDocument) -> SettingsDocument {
        Settings.fields
            .filter { revision(of: $0.key) == .legacy && other.revision(of: $0.key) == .legacy }
            .reduce(into: merging(other)) { result, field in
                field.copy(from: other.settings, into: &result.settings)
            }
    }

    /// Takes only the settings `other` revised after this copy did, leaving every tie alone: for a copy
    /// that carries values it may never have edited, such as the watch's whole document.
    func adoptingNewer(_ other: SettingsDocument) -> SettingsDocument {
        Settings.fields.reduce(into: self) { result, field in
            let theirs = other.revision(of: field.key)
            guard theirs > revision(of: field.key) else { return }

            field.copy(from: other.settings, into: &result.settings)
            result.revisions[field.key] = theirs
        }
    }

    /// The synced settings revised here that a merge into `other` would take, which an upload over `other`
    /// needs to carry: later revisions, and equal ones this copy's value wins, so every copy converges on the
    /// winner. A setting never revised here is never sent over another device's value.
    func keysNewer(than other: SettingsDocument) -> [SettingKey] {
        Settings.fields
            .filter { $0.isSynced && revision(of: $0.key) != .legacy && wins($0, over: other) }
            .map(\.key)
    }

    /// Whether any synced setting here would win a merge into `other`, so `other` is behind.
    func hasNewerRevisions(than other: SettingsDocument) -> Bool {
        !keysNewer(than: other).isEmpty
    }

    /// Stamps `keys` as edited at `date` without changing their values, so they win over older copies.
    func restamping(_ keys: [SettingKey], at date: Date) -> SettingsDocument {
        guard !keys.isEmpty else { return self }
        let stamp = Revision.stamp(at: date, after: revisions.values.max() ?? .legacy)
        return SettingsDocument(settings: settings, revisions: keys.reduce(into: revisions) { $0[$1] = stamp })
    }
}
