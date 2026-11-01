//
//  SingleFlight.swift
//  PrayServices
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

/// Runs an operation one pass at a time. Calls during a pass ask for exactly one more pass after it, which runs the
/// latest call's operation, and every caller waits until the passes settle, so no request is lost and two passes
/// never overlap.
actor SingleFlight {
    private var passes: Task<Void, Never>?
    private var requested: (@Sendable () async -> Void)?

    func run(_ operation: @escaping @Sendable () async -> Void) async {
        if let passes {
            requested = operation
            await passes.value
            return
        }

        let task = Task { await drain(operation) }
        passes = task
        await task.value
    }

    private func drain(_ operation: @escaping @Sendable () async -> Void) async {
        var next: (@Sendable () async -> Void)? = operation

        while let pass = next {
            requested = nil
            await pass()
            next = requested
        }

        // Cleared without suspending after the last check, so a later call always starts a new pass
        passes = nil
    }
}
