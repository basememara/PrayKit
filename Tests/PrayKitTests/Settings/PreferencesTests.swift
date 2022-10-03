//
//  PreferencesTests.swift
//  PrayCoreTests
//
//  Created by Basem Emara on 2021-01-30.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import XCTest
import Combine
import CoreLocation
import PrayCore
import ZamzamCore

final class PreferencesTests: TestCase {
    private var preferences = Preferences(defaults: .test)
    private var cancellable = Set<AnyCancellable>()

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        cancellable.removeAll()
    }
}

// MARK: - Calculation

extension PreferencesTests {
    func testCalculationMethod() throws {
        let expectedValue = CalculationMethod.turkey
        try testPublisher(for: \.calculationMethod, with: expectedValue)
        XCTAssertEqual(preferences.calculationMethod, expectedValue)
    }

    func testJuristicMethod() throws {
        let expectedValue = Madhab.hanafi
        try testPublisher(for: \.juristicMethod, with: expectedValue)
        XCTAssertEqual(preferences.juristicMethod, expectedValue)
    }

    func testFajrDegrees() throws {
        let expectedValue = Double.random(in: -60...60)
        try testPublisher(for: \.fajrDegrees, with: expectedValue)
        XCTAssertEqual(preferences.fajrDegrees, expectedValue)
    }

    func testMaghribDegrees() throws {
        let expectedValue = Double.random(in: -60...60)
        try testPublisher(for: \.maghribDegrees, with: expectedValue)
        XCTAssertEqual(preferences.maghribDegrees, expectedValue)
    }

    func testIshaDegrees() throws {
        let expectedValue = Double.random(in: -60...60)
        try testPublisher(for: \.ishaDegrees, with: expectedValue)
        XCTAssertEqual(preferences.ishaDegrees, expectedValue)
    }

    func testElevationRule() throws {
        let expectedValue = ElevationRule.twilightAngle
        try testPublisher(for: \.elevationRule, with: expectedValue)
        XCTAssertEqual(preferences.elevationRule, expectedValue)
    }
}

// MARK: - Adjustments

extension PreferencesTests {
    func testAdjustmentMinutes() throws {
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

        try testPublisher(for: \.adjustmentMinutes, with: expectedValue)
        XCTAssertEqual(preferences.adjustmentMinutes, expectedValue)
    }

    func testAdjustmentMinutes2() throws {
        preferences.adjustmentMinutes = .init(rawValue: [:])
        preferences.adjustmentMinutes?[.asr] = 1
        XCTAssertEqual(preferences.adjustmentMinutes?[.asr], 1)

        preferences.adjustmentMinutes?[.asr] = 2
        XCTAssertEqual(preferences.adjustmentMinutes?[.asr], 2)
    }

    func testAdjustmentElevation() throws {
        let expectedValue = ElevationRule.twilightAngle
        try testPublisher(for: \.adjustmentElevation, with: expectedValue)
        XCTAssertEqual(preferences.adjustmentElevation, expectedValue)
    }
}

// MARK: - Location

extension PreferencesTests {
    func testIsGPSEnabled() throws {
        let expectedValue = false
        try testPublisher(for: \.isGPSEnabled, with: expectedValue)
        XCTAssertEqual(preferences.isGPSEnabled, expectedValue)
    }

    func testPrayersCoordinates() throws {
        let promise = expectation(description: #function)
        var publishedValue: Coordinates?

        let expectedValue = Coordinates(
            latitude: Double.random(in: -100...100),
            longitude: Double.random(in: -100...100)
        )

        // When
        preferences
            .publisher(for: \.prayersCoordinates)
            .sink {
                publishedValue = $0
                promise.fulfill()
            }
            .store(in: &cancellable)

        let location = CLLocation(
            latitude: expectedValue.latitude,
            longitude: expectedValue.longitude
        )

        preferences.set(gpsLocation: location)
        wait(for: [promise], timeout: 5)

        // Then
        XCTAssertEqual(publishedValue, expectedValue)
        XCTAssertEqual(preferences.prayersCoordinates, expectedValue)
    }
}

// MARK: - Time

extension PreferencesTests {
    func testEnable24hTimeFormat() throws {
        let expectedValue = true
        try testPublisher(for: \.enable24hTimeFormat, with: expectedValue)
        XCTAssertEqual(preferences.enable24hTimeFormat, expectedValue)
    }

    func testHijriDayOffset() throws {
        let expectedValue = Int.random(in: -3...3)
        try testPublisher(for: \.hijriDayOffset, with: expectedValue)
        XCTAssertEqual(preferences.hijriDayOffset, expectedValue)
    }

    func testAutoIncrementHijri() throws {
        let expectedValue = false
        try testPublisher(for: \.autoIncrementHijri, with: expectedValue)
        XCTAssertFalse(preferences.autoIncrementHijri)
    }
}

// MARK: - Notification

extension PreferencesTests {
    func testSnoozeMinutes() throws {
        let expectedValue = Int.random(in: -60...60)
        try testPublisher(for: \.snoozeMinutes, with: expectedValue)
        XCTAssertEqual(preferences.snoozeMinutes, expectedValue)
    }
}

// MARK: - Pre-adhan

extension PreferencesTests {
    func testPreAdhanMinutes() throws {
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

        try testPublisher(for: \.preAdhanMinutes, with: expectedValue)
        XCTAssertEqual(preferences.preAdhanMinutes, expectedValue)
    }

    func testPreAdhanMinutes2() throws {
        preferences.preAdhanMinutes = .init(rawValue: [:])
        preferences.preAdhanMinutes[.asr] = 1
        XCTAssertEqual(preferences.preAdhanMinutes[.asr], 1)

        preferences.preAdhanMinutes[.asr] = 2
        XCTAssertEqual(preferences.preAdhanMinutes[.asr], 2)
    }
}

// MARK: - Sound

extension PreferencesTests {
    func testNotificationReminder() throws {
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

        try testPublisher(for: \.reminderSounds, with: expectedValue)
        XCTAssertEqual(preferences.reminderSounds, expectedValue)
    }

    func testNotificationSounds() throws {
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

        try testPublisher(for: \.notificationSounds, with: expectedValue)
        XCTAssertEqual(preferences.notificationSounds, expectedValue)
    }

    func testNotificationSounds2() throws {
        preferences.notificationSounds[.fajr] = .circles
        XCTAssertEqual(preferences.notificationSounds[.fajr], .circles)

        preferences.notificationSounds[.asr] = .off
        XCTAssertEqual(preferences.notificationSounds[.asr], .off)
    }

    func testNotificationAdhan() throws {
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

        try testPublisher(for: \.notificationAdhan, with: expectedValue)
        XCTAssertEqual(preferences.notificationAdhan, expectedValue)
    }
}

// MARK: - Display

extension PreferencesTests {
    func testIsPrayerAbbrEnabled() throws {
        let expectedValue = true
        try testPublisher(for: \.isPrayerAbbrEnabled, with: expectedValue)
        XCTAssert(preferences.isPrayerAbbrEnabled)
    }

    func testSunriseAfterIsha() throws {
        let expectedValue = true
        try testPublisher(for: \.sunriseAfterIsha, with: expectedValue)
        XCTAssert(preferences.sunriseAfterIsha)
    }

    func testAppearanceMode() throws {
        XCTAssertEqual(preferences.appearanceMode, .dark)
        try testPublisher(for: \.appearanceMode, with: .light)
        XCTAssertEqual(preferences.appearanceMode, .light)
    }
}

// MARK: - Cache

extension PreferencesTests {
    func testLastCacheDate() throws {
        let expectedValue = Date(timeIntervalSinceReferenceDate: .random(in: -45585758...45585758))
        try testPublisher(for: \.lastCacheDate, with: expectedValue)
        XCTAssertEqual(preferences.lastCacheDate, expectedValue)
    }

    func testLastTimeZone() throws {
        let expectedValue = TimeZone(identifier: "America/Los_Angeles") ?? .current
        try testPublisher(for: \.lastTimeZone, with: expectedValue)
        XCTAssertEqual(preferences.lastTimeZone, expectedValue)
        XCTAssertEqual(preferences.lastTimeZone.identifier, "America/Los_Angeles")
    }

    func testLastRegionName() throws {
        let expectedValue = "Some Region 123"
        try testPublisher(for: \.lastRegionName, with: expectedValue)
        XCTAssertEqual(preferences.lastRegionName, expectedValue)
    }
}

// MARK: - Diagnostics

extension PreferencesTests {
    func testIsDiagnosticsEnabled() throws {
        let expectedValue = true
        try testPublisher(for: \.isDiagnosticsEnabled, with: expectedValue)
        XCTAssert(preferences.isDiagnosticsEnabled)
    }
}

// MARK: - Prayer Recalculation Observable

extension PreferencesTests {
    func testRecalculationPublisher() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

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

        wait(for: [promise], timeout: 5)
    }

    func testRecalculationPublisher1() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.set(gpsLocation: CLLocation(
            latitude: 0,
            longitude: 0
        ))

        wait(for: [promise], timeout: 5)
    }

    func testRecalculationPublisher2() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.calculationMethod = .ummAlQura
        wait(for: [promise], timeout: 5)
    }

    func testRecalculationPublisher3() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.juristicMethod = .hanafi
        wait(for: [promise], timeout: 5)
    }

    func testRecalculationPublisher4() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.adjustmentMinutes = .init(rawValue: [:])
        preferences.adjustmentMinutes?[.fajr] = 1
        wait(for: [promise], timeout: 5)
    }

    func testRecalculationPublisher5() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.fajrDegrees = 2
        wait(for: [promise], timeout: 5)
    }

    func testRecalculationPublisher6() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.maghribDegrees = 3
        wait(for: [promise], timeout: 5)
    }

    func testRecalculationPublisher7() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.ishaDegrees = 4
        wait(for: [promise], timeout: 5)
    }

    func testRecalculationPublisher8() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.elevationRule = .twilightAngle
        wait(for: [promise], timeout: 5)
    }

    func testRecalculationPublisherFailed() throws {
        // Given
        let promise = expectation(description: #function)
        promise.isInverted = true

        // When
        preferences
            .publisher(for: .prayerRecalculation)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.isGPSEnabled = false
        preferences.snoozeMinutes = 5

        wait(for: [promise], timeout: 3)
    }
}

// MARK: - Notification Reschedule Observable

extension PreferencesTests {
    func testNotificationReschedulePublisher() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .notificationReschedule)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

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

        wait(for: [promise], timeout: 5)
    }

    func testNotificationReschedulePublisher1() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .notificationReschedule)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.snoozeMinutes = 5
        wait(for: [promise], timeout: 5)
    }

    func testNotificationReschedulePublisher2() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .notificationReschedule)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.preAdhanMinutes[.fajr] = 4
        preferences.preAdhanMinutes[.sunrise] = 5
        preferences.preAdhanMinutes[.dhuhr] = 6

        wait(for: [promise], timeout: 5)
    }

    func testNotificationReschedulePublisher5() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .notificationReschedule)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.sunriseAfterIsha = true
        wait(for: [promise], timeout: 5)
    }

    func testNotificationReschedulePublisher6() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .notificationReschedule)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.notificationSounds[.fajr] = .presto
        preferences.notificationSounds[.sunrise] = .circles
        preferences.notificationSounds[.dhuhr] = .tweet

        wait(for: [promise], timeout: 5)
    }

    func testNotificationReschedulePublisher7() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .notificationReschedule)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.notificationAdhan[.fajr] = .abdulBasit
        wait(for: [promise], timeout: 5)
    }

    func testNotificationReschedulePublisher8() throws {
        // Given
        let promise = expectation(description: #function)

        // When
        preferences
            .publisher(for: .notificationReschedule)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.reminderSounds[.maghrib] = .circles
        wait(for: [promise], timeout: 5)
    }

    func testNotificationReschedulePublisherFailed() throws {
        // Given
        let promise = expectation(description: #function)
        promise.isInverted = true

        // When
        preferences
            .publisher(for: .notificationReschedule)
            .sink { promise.fulfill() }
            .store(in: &cancellable)

        preferences.calculationMethod = .qatar
        preferences.autoIncrementHijri = false
        wait(for: [promise], timeout: 3)
    }
}

// MARK: - Helpers

private extension PreferencesTests {
    func testPublisher<Value: Equatable>(
        for keyPath: WritableKeyPath<Preferences, Value>,
        with expectedValue: Value
    ) throws {
        // Given
        let promise = expectation(description: #function)
        var publishedValue: Value?

        // When
        preferences
            .publisher(for: keyPath)
            .sink {
                publishedValue = $0
                promise.fulfill()
            }
            .store(in: &cancellable)

        preferences[keyPath: keyPath] = expectedValue
        wait(for: [promise], timeout: 5)

        // Then
        XCTAssertEqual(publishedValue, expectedValue)
    }
}
