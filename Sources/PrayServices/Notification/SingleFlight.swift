//
//  SingleFlight.swift
//  PrayServices
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

/// Runs an operation one pass at a time. Calls during a pass ask for exactly one more pass after it, and
/// every caller waits until the passes settle, so no request is lost and two passes never overlap.
///
/// Meant for callers repeating the same operation: the extra pass reruns the operation that started them.
actor SingleFlight {
    private var passes: Task<Void, Never>?
    private var isRequested = false

    func run(_ operation: @escaping @Sendable () async -> Void) async {
        if let passes {
            isRequested = true
            await passes.value
            return
        }

        let task = Task { await drain(operation) }
        passes = task
        await task.value
    }

    private func drain(_ operation: @escaping @Sendable () async -> Void) async {
        repeat {
            isRequested = false
            await operation()
        } while isRequested

        // Cleared without suspending after the last check, so a later call always starts a new pass
        passes = nil
    }
}
