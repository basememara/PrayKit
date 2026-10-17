//
//  Revision.swift
//  PrayCore
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation

/// When a setting last changed, in whole milliseconds so it survives CloudKit, defaults and property lists unchanged.
public struct Revision: Comparable, Hashable, Sendable {
    public let milliseconds: Int64

    public init(milliseconds: Int64) {
        self.milliseconds = milliseconds
    }

    public init(_ date: Date) {
        self.init(milliseconds: Int64((date.timeIntervalSince1970 * 1000).rounded(.down)))
    }

    public static func < (lhs: Revision, rhs: Revision) -> Bool {
        lhs.milliseconds < rhs.milliseconds
    }
}

public extension Revision {
    /// A value saved before settings carried revisions, which any revised value replaces.
    static let legacy = Revision(milliseconds: 0)

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }

    /// The revision for an edit made at `date`, never earlier than one already seen.
    ///
    /// A device whose clock runs behind still orders its edit after every revision it has merged.
    static func stamp(at date: Date, after newest: Revision) -> Revision {
        // A corrupt revision from a record can't overflow it
        max(Revision(date), Revision(milliseconds: min(newest.milliseconds, .max - 1) + 1))
    }
}
