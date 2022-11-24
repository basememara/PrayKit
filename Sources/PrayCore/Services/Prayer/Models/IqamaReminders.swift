//
//  IqamaReminders.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-11-20.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public struct IqamaReminders: Equatable, Codable {
    public let sound: NotificationSound
    public let minutes: Int
    public let jumuahMinutes: Int
    public let updateInterval: UpdateInterval

    public init(sound: NotificationSound, minutes: Int, jumuahMinutes: Int, updateInterval: UpdateInterval) {
        self.sound = sound
        self.minutes = minutes
        self.jumuahMinutes = jumuahMinutes
        self.updateInterval = updateInterval
    }
}

// MARK: - Types

public extension IqamaReminders {
    enum UpdateInterval: String, Identifiable, Equatable, Codable, CaseIterable {
        public var id: Self { self }
        case weekly
        case biweekly
        case monthly
        case bimonthly
        case off
    }
}
