//
//  DeliveredNotification.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-11-13.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

/// A notification already delivered, as the rule for clearing them reads it.
public struct DeliveredNotification: Equatable, Sendable {
    public let identifier: String
    public let category: NotificationCategory?
    public let date: Date
    /// When the prayer it's about begins, for a notification about a prayer.
    public let prayerStart: Date?

    public init(identifier: String, category: NotificationCategory?, date: Date, prayerStart: Date?) {
        self.identifier = identifier
        self.category = category
        self.date = date
        self.prayerStart = prayerStart
    }
}

public extension Settings {
    /// The delivered notifications to clear when one is opened, swiped away or snoozed: every prayer notification, or
    /// on a device that clears one at a time, the one touched and any reminder whose prayer has since begun. A method
    /// suggestion stays until it's answered.
    func deliveredToClear(touching touched: String, among delivered: [DeliveredNotification], at now: Date) -> [String] {
        delivered
            .filter { notification in
                guard let category = notification.category, category != .methodSuggestion else { return false }
                return !clearsOneNotification || notification.identifier == touched || notification.isStaleReminder(at: now)
            }
            .map(\.identifier)
    }
}

private extension DeliveredNotification {
    /// A reminder delivered before its prayer, once the prayer has begun. An iqama reminder comes after its prayer
    /// begins, so it isn't one.
    func isStaleReminder(at now: Date) -> Bool {
        guard category == .reminder, let prayerStart else { return false }
        return date < prayerStart && prayerStart <= now
    }
}
