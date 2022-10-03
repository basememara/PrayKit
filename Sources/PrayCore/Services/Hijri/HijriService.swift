//
//  HijriService.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-03-17.
//  Copyright © 2022 Zamzam Inc. All rights reserved.
//

import Foundation.NSDateInterval

public protocol HijriService {
    func fetchOffset(for time: Date) async throws -> Int
    func fetch(with request: HijriAPI.FetchHolidaysRequest) -> [Holiday]
    func fetch(with request: HijriAPI.FetchTimelineRequest) async throws -> [HijriAPI.TimelineEntry]
}

// MARK: - Namespace

public enum HijriAPI {}

public extension HijriAPI {
    struct FetchHolidaysRequest {
        public init() {}
    }
}

public extension HijriAPI {
    struct FetchTimelineRequest {
        public let startDate: Date
        public let timeZone: TimeZone
        public let limit: Int

        public init(startDate: Date, timeZone: TimeZone, limit: Int) {
            self.startDate = startDate
            self.timeZone = timeZone
            self.limit = limit
        }
    }

    struct TimelineEntry: Equatable, Codable {
        public let date: Date
        public let timeZone: TimeZone
        public let hijriOffset: Int

        public init(date: Date, timeZone: TimeZone, hijriOffset: Int) {
            self.date = date
            self.timeZone = timeZone
            self.hijriOffset = hijriOffset
        }
    }
}
