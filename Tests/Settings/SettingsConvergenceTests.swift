//
//  SettingsConvergenceTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

/// An iPhone, its watch and an iPad editing settings while copies travel in any order, duplicated or late:
/// iCloud merges by revision, the watch adopts from its iPhone, the iPhone merges the watch's edits.
struct SettingsConvergenceTests {
    @Test
    func everyDeviceEndsWithTheLatestEditOfEverySetting() {
        var generator = SplitMix64(seed: 0xFEED)

        (0..<200).forEach { _ in
            var network = Network(using: &generator)
            var latest = [SettingKey: Int]()

            (0..<40).forEach { step in
                if Bool.random(using: &generator) {
                    let device = Device.allCases.randomElement(using: &generator) ?? .phone
                    let (key, value) = network.edit(on: device, at: step, using: &generator)
                    latest[key] = value
                } else {
                    network.deliver(Delivery.allCases.randomElement(using: &generator) ?? .phoneToCloud)
                }
            }

            network.settle()

            let phone = network.copies[.phone]?.settings
            #expect(Device.allCases.allSatisfy { network.copies[$0]?.settings == phone })
            #expect(network.cloud.settings == phone)
            #expect(latest.allSatisfy { key, value in phone.map { Network.value(of: key, in: $0) } == value })
        }
    }
}

// MARK: - Helpers

private enum Device: CaseIterable {
    case phone
    case watch
    case pad
}

private enum Delivery: CaseIterable {
    case phoneToCloud
    case cloudToPhone
    case watchToCloud
    case cloudToWatch
    case padToCloud
    case cloudToPad
    case phoneToWatch
    case watchToPhone
}

private struct Network {
    var copies: [Device: SettingsDocument]
    var cloud = SettingsDocument()

    /// Each device starts with its own unrevised values, as after an upgrade.
    init(using generator: inout SplitMix64) {
        copies = Device.allCases.reduce(into: [:]) { copies, device in
            var settings = Settings()
            settings.snoozeMinutes = Int.random(in: 1...60, using: &generator)
            settings.hijriDayOffset = Int.random(in: -2...2, using: &generator)
            copies[device] = SettingsDocument(settings: settings)
        }
    }

    /// Edits one setting a little later each step, with a per-device clock skew of up to a second.
    mutating func edit(on device: Device, at step: Int, using generator: inout SplitMix64) -> (SettingKey, Int) {
        let key: SettingKey = [.snoozeMinutes, .hijriDayOffset, .stopwatchMinutes].randomElement(using: &generator) ?? .snoozeMinutes
        let value = Int.random(in: 0...1_000, using: &generator)
        let skew = Double.random(in: -1...1, using: &generator)
        let date = Date(timeIntervalSince1970: 1_000_000 + Double(step) * 10 + skew)

        copies[device] = copies[device]?.editing(at: date) { Self.set(key, to: value, in: &$0) }
        return (key, value)
    }

    mutating func deliver(_ delivery: Delivery) {
        switch delivery {
        case .phoneToCloud:
            cloud = cloud.merging(copy(.phone))
        case .cloudToPhone:
            copies[.phone] = copy(.phone).merging(cloud)
        case .watchToCloud:
            cloud = cloud.merging(copy(.watch))
        case .cloudToWatch:
            copies[.watch] = copy(.watch).merging(cloud)
        case .padToCloud:
            cloud = cloud.merging(copy(.pad))
        case .cloudToPad:
            copies[.pad] = copy(.pad).merging(cloud)
        case .phoneToWatch:
            copies[.watch] = copy(.watch).adopting(copy(.phone))
        case .watchToPhone:
            copies[.phone] = copy(.phone).merging(copy(.watch))
        }
    }

    /// Every transport delivers until nothing changes, as it does once devices come back online.
    mutating func settle() {
        (0..<4).forEach { _ in Delivery.allCases.forEach { deliver($0) } }
    }

    private func copy(_ device: Device) -> SettingsDocument {
        copies[device] ?? SettingsDocument()
    }

    static func set(_ key: SettingKey, to value: Int, in settings: inout Settings) {
        switch key {
        case .snoozeMinutes:
            settings.snoozeMinutes = value
        case .hijriDayOffset:
            settings.hijriDayOffset = value
        default:
            settings.stopwatchMinutes = value
        }
    }

    static func value(of key: SettingKey, in settings: Settings) -> Int {
        switch key {
        case .snoozeMinutes:
            settings.snoozeMinutes
        case .hijriDayOffset:
            settings.hijriDayOffset
        default:
            settings.stopwatchMinutes
        }
    }
}
