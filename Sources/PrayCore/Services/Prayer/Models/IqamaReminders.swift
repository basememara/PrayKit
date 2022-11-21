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

    public init(sound: NotificationSound, minutes: Int, jumuahMinutes: Int) {
        self.sound = sound
        self.minutes = minutes
        self.jumuahMinutes = jumuahMinutes
    }
}
