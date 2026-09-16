//
//  PreferencesTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2021-01-30.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Testing
import Combine
import Foundation
import CoreLocation
import PrayCore
import ZamzamCore

struct PreferencesTests {
    private let preferences = Preferences(defaults: .makeTest())
}

// MARK: - Calculation

extension PreferencesTests {
    @Test
    func calculationMethod() async {
        let expectedValue = CalculationMethod.turkey
        await expectPublished(\.calculationMethod, equals: expectedValue)
    }

    @Test
    func juristicMethod() async {
        let expectedValue = Madhab.hanafi
        await expectPublished(\.juristicMethod, equals: expectedValue)
    }

    @Test
    func fajrDegrees() async {
        let expectedValue = Double.random(in: -60...60)
        await expectPublished(\.fajrDegrees, equals: expectedValue)
    }

    @Test
    func maghribDegrees() async {
        let expectedValue = Double.random(in: -60...60)
        await expectPublished(\.maghribDegrees, equals: expectedValue)
    }

    @Test
    func ishaDegrees() async {
        let expectedValue = Double.random(in: -60...60)
        await expectPublished(\.ishaDegrees, equals: expectedValue)
    }

    @Test
    func elevationRule() async {
        let expectedValue = ElevationRule.twilightAngle
        await expectPublished(\.elevationRule, equals: expectedValue)
    }
}

// MARK: - Adjustments

extension PreferencesTests {
    @Test
    func adjustmentMinutes() async {
        let expectedValue = AdjustmentMinutes(
            rawValue: [
                Prayer.fajr.rawValue: 2,
                Prayer.sunrise.rawValue: 5,
                Prayer.dhuhr.rawValue: 8,
                Prayer.asr.rawValue: -4,
                Prayer.maghrib.rawValue: 7,
                Prayer.isha.rawValue: 0
            ]
        )

        await expectPublished(\.adjustmentMinutes, equals: expectedValue)
    }

    @Test
    func adjustmentMinutes2() {
        preferences.adjustmentMinutes = .init(rawValue: [:])
        preferences.adjustmentMinutes?[.asr] = 1
        #expect(preferences.adjustmentMinutes?[.asr] == 1)

        preferences.adjustmentMinutes?[.asr] = 2
        #expect(preferences.adjustmentMinutes?[.asr] == 2)
    }

    @Test
    func adjustmentElevation() async {
        let expectedValue = ElevationRule.twilightAngle
        await expectPublished(\.adjustmentElevation, equals: expectedValue)
    }
}

// MARK: - Location

extension PreferencesTests {
    @Test
    func isGPSEnabled() async {
        let expectedValue = false
        await expectPublished(\.isGPSEnabled, equals: expectedValue)
    }

    @Test
    func prayersCoordinates() async {
        // Given
        let expectedValue = Coordinates(
            latitude: Double.random(in: -100...100),
            longitude: Double.random(in: -100...100)
        )

        // When
        let published = await firstValue(of: preferences.publisher(for: \.prayersCoordinates)) {
            preferences.set(gpsLocation: CLLocation(
                latitude: expectedValue.latitude,
                longitude: expectedValue.longitude
            ))
        }

        // Then
        #expect(published == expectedValue)
        #expect(preferences.prayersCoordinates == expectedValue)
    }
}

// MARK: - Time

extension PreferencesTests {
    @Test
    func enable24hTimeFormat() async {
        let expectedValue = true
        await expectPublished(\.enable24hTimeFormat, equals: expectedValue)
    }

    @Test
    func hijriDayOffset() async {
        // Never the stored value: the setter only publishes on an actual change, so a
        // random draw over seven values failed roughly one run in seven.
        let expectedValue = preferences.hijriDayOffset + 1
        await expectPublished(\.hijriDayOffset, equals: expectedValue)
    }

    @Test
    func autoIncrementHijri() async {
        let expectedValue = false
        await expectPublished(\.autoIncrementHijri, equals: expectedValue)
        #expect(!(preferences.autoIncrementHijri))
    }
}

// MARK: - Notification

extension PreferencesTests {
    @Test
    func snoozeMinutes() async {
        let expectedValue = Int.random(in: -60...60)
        await expectPublished(\.snoozeMinutes, equals: expectedValue)
    }
}

// MARK: - Pre-adhan

extension PreferencesTests {
    @Test
    func preAdhanMinutes() async {
        let expectedValue = PreAdhanMinutes(
            rawValue: [
                Prayer.fajr.rawValue: 22,
                Prayer.sunrise.rawValue: 15,
                Prayer.dhuhr.rawValue: 18,
                Prayer.asr.rawValue: 14,
                Prayer.maghrib.rawValue: 17,
                Prayer.isha.rawValue: 0
            ]
        )

        await expectPublished(\.preAdhanMinutes, equals: expectedValue)
    }

    @Test
    func preAdhanMinutes2() {
        preferences.preAdhanMinutes = .init(rawValue: [:])
        preferences.preAdhanMinutes[.asr] = 1
        #expect(preferences.preAdhanMinutes[.asr] == 1)

        preferences.preAdhanMinutes[.asr] = 2
        #expect(preferences.preAdhanMinutes[.asr] == 2)
    }
}

// MARK: - Sound

extension PreferencesTests {
    @Test
    func notificationReminder() async {
        let expectedValue = ReminderSounds(
            rawValue: [
                Prayer.fajr.rawValue: .tweet,
                Prayer.sunrise.rawValue: .circles,
                Prayer.dhuhr.rawValue: .tone,
                Prayer.asr.rawValue: .presto,
                Prayer.maghrib.rawValue: .default,
                Prayer.isha.rawValue: .presto,
                Prayer.midnight.rawValue: .off,
                Prayer.lastThird.rawValue: .off
            ]
        )

        await expectPublished(\.reminderSounds, equals: expectedValue)
    }

    @Test
    func notificationSounds() async {
        let expectedValue = NotificationSounds(
            rawValue: [
                Prayer.fajr.rawValue: .tweet,
                Prayer.sunrise.rawValue: .circles,
                Prayer.dhuhr.rawValue: .tone,
                Prayer.asr.rawValue: .presto,
                Prayer.maghrib.rawValue: .default,
                Prayer.isha.rawValue: .presto,
                Prayer.midnight.rawValue: .off,
                Prayer.lastThird.rawValue: .off
            ]
        )

        await expectPublished(\.notificationSounds, equals: expectedValue)
    }

    @Test
    func notificationSounds2() {
        preferences.notificationSounds[.fajr] = .circles
        #expect(preferences.notificationSounds[.fajr] == .circles)

        preferences.notificationSounds[.asr] = .off
        #expect(preferences.notificationSounds[.asr] == .off)
    }

    @Test
    func notificationAdhan() async {
        let expectedValue = NotificationAdhan(
            rawValue: [
                Prayer.fajr.rawValue: .abdulBasit,
                Prayer.sunrise.rawValue: .abdulHakam,
                Prayer.dhuhr.rawValue: .egypt,
                Prayer.asr.rawValue: .hafez,
                Prayer.maghrib.rawValue: .mohammadRefaat,
                Prayer.isha.rawValue: .yusufIslam
            ]
        )

        await expectPublished(\.notificationAdhan, equals: expectedValue)
    }
}

// MARK: - Display

extension PreferencesTests {
    @Test
    func isPrayerAbbrEnabled() async {
        let expectedValue = true
        await expectPublished(\.isPrayerAbbrEnabled, equals: expectedValue)
        #expect(preferences.isPrayerAbbrEnabled)
    }

    @Test
    func sunriseAfterIsha() async {
        let expectedValue = true
        await expectPublished(\.sunriseAfterIsha, equals: expectedValue)
        #expect(preferences.sunriseAfterIsha)
    }

    @Test
    func appearanceMode() async {
        #expect(preferences.appearanceMode == .dark)
        await expectPublished(\.appearanceMode, equals: .light)
        #expect(preferences.appearanceMode == .light)
    }
}

// MARK: - Cache

extension PreferencesTests {
    @Test
    func lastCacheDate() async {
        let expectedValue = Date(timeIntervalSinceReferenceDate: .random(in: -45585758...45585758))
        await expectPublished(\.lastCacheDate, equals: expectedValue)
    }

    @Test
    func lastTimeZone() async {
        let expectedValue = TimeZone(identifier: "America/Los_Angeles") ?? .current
        await expectPublished(\.lastTimeZone, equals: expectedValue)
        #expect(preferences.lastTimeZone.identifier == "America/Los_Angeles")
    }

    @Test
    func lastRegionName() async {
        let expectedValue = "Some Region 123"
        await expectPublished(\.lastRegionName, equals: expectedValue)
    }
}

// MARK: - Prayer Recalculation Observable

extension PreferencesTests {
    @Test
    func recalculationPublisher() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.set(gpsLocation: CLLocation(
                latitude: 0,
                longitude: 0
            ))

            preferences.calculationMethod = .ummAlQura
            preferences.juristicMethod = .hanafi

            preferences.adjustmentMinutes = .init(rawValue: [:])
            preferences.adjustmentMinutes?[.fajr] = 1
            preferences.adjustmentMinutes?[.sunrise] = 2
            preferences.adjustmentMinutes?[.dhuhr] = 3
            preferences.adjustmentMinutes?[.asr] = 4
            preferences.adjustmentMinutes?[.maghrib] = 5
            preferences.adjustmentMinutes?[.isha] = 6
            preferences.adjustmentElevation = .seventhOfTheNight

            preferences.fajrDegrees = 2
            preferences.maghribDegrees = 3
            preferences.ishaDegrees = 4
            preferences.elevationRule = .twilightAngle
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func recalculationPublisher1() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.set(gpsLocation: CLLocation(
                latitude: 0,
                longitude: 0
            ))
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func recalculationPublisher2() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.calculationMethod = .ummAlQura
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func recalculationPublisher3() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.juristicMethod = .hanafi
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func recalculationPublisher4() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.adjustmentMinutes = .init(rawValue: [:])
            preferences.adjustmentMinutes?[.fajr] = 1
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func recalculationPublisher5() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.fajrDegrees = 2
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func recalculationPublisher6() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.maghribDegrees = 3
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func recalculationPublisher7() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.ishaDegrees = 4
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func recalculationPublisher8() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.elevationRule = .twilightAngle
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func recalculationPublisherFailed() async {
        // When
        let didFire = await didFire(.prayerRecalculation) {
            preferences.isGPSEnabled = false
            preferences.snoozeMinutes = 5
        }

        // Then
        #expect(didFire == false)
    }
}

// MARK: - Notification Reschedule Observable

extension PreferencesTests {
    @Test
    func notificationReschedulePublisher() async {
        // When
        let didFire = await didFire(.notificationReschedule) {
            preferences.snoozeMinutes = 5
            preferences.preAdhanMinutes[.fajr] = 9
            preferences.preAdhanMinutes[.sunrise] = 8
            preferences.preAdhanMinutes[.dhuhr] = 7
            preferences.sunriseAfterIsha = true

            preferences.notificationSounds[.fajr] = .presto
            preferences.notificationSounds[.sunrise] = .circles
            preferences.notificationSounds[.dhuhr] = .tweet

            preferences.notificationAdhan[.fajr] = .abdulBasit
            preferences.reminderSounds[.asr] = .circles
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func notificationReschedulePublisher1() async {
        // When
        let didFire = await didFire(.notificationReschedule) {
            preferences.snoozeMinutes = 5
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func notificationReschedulePublisher2() async {
        // When
        let didFire = await didFire(.notificationReschedule) {
            preferences.preAdhanMinutes[.fajr] = 4
            preferences.preAdhanMinutes[.sunrise] = 5
            preferences.preAdhanMinutes[.dhuhr] = 6
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func notificationReschedulePublisher5() async {
        // When
        let didFire = await didFire(.notificationReschedule) {
            preferences.sunriseAfterIsha = true
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func notificationReschedulePublisher6() async {
        // When
        let didFire = await didFire(.notificationReschedule) {
            preferences.notificationSounds[.fajr] = .presto
            preferences.notificationSounds[.sunrise] = .circles
            preferences.notificationSounds[.dhuhr] = .tweet
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func notificationReschedulePublisher7() async {
        // When
        let didFire = await didFire(.notificationReschedule) {
            preferences.notificationAdhan[.fajr] = .abdulBasit
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func notificationReschedulePublisher8() async {
        // When
        let didFire = await didFire(.notificationReschedule) {
            preferences.reminderSounds[.maghrib] = .circles
        }

        // Then
        #expect(didFire == true)
    }

    @Test
    func notificationReschedulePublisherFailed() async {
        // When
        let didFire = await didFire(.notificationReschedule) {
            preferences.calculationMethod = .qatar
            preferences.autoIncrementHijri = false
        }

        // Then
        #expect(didFire == false)
    }
}

// MARK: - Helpers

private extension PreferencesTests {
    /// Sets `keyPath` and asserts the preference publisher republishes the new value.
    func expectPublished<Value: Equatable & Sendable>(
        _ keyPath: WritableKeyPath<Preferences, Value>,
        equals expectedValue: Value,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        var preferences = preferences
        let published = await firstValue(of: preferences.publisher(for: keyPath)) {
            preferences[keyPath: keyPath] = expectedValue
        }

        #expect(published == expectedValue, sourceLocation: sourceLocation)
        #expect(preferences[keyPath: keyPath] == expectedValue, sourceLocation: sourceLocation)
    }

    /// Runs `mutate` and reports whether the group publisher fired within the timeout.
    func didFire(_ group: Preferences.KeyPathGroup, _ mutate: () -> Void) async -> Bool {
        await firstValue(of: preferences.publisher(for: group), while: mutate) != nil
    }

    /// Subscribes, runs `mutate`, then returns the first published value or `nil` on timeout.
    ///
    /// The subscription is attached before `mutate` runs, and the timeout replaces
    /// XCTest's `wait(for:)` so a publisher that never fires cannot hang the suite.
    func firstValue<Value: Sendable>(
        of publisher: AnyPublisher<Value, Never>,
        timeout: Duration = .seconds(3),
        while mutate: () -> Void
    ) async -> Value? {
        let (values, continuation) = AsyncStream<Value>.makeStream()
        let cancellable = publisher.sink { continuation.yield($0) }
        defer { cancellable.cancel() }

        mutate()

        return await withTaskGroup(of: Value?.self) { group in
            group.addTask { await values.first { _ in true } }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }

            defer { group.cancelAll() }
            return await group.next() ?? nil
        }
    }
}
