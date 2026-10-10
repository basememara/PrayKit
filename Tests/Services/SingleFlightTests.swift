//
//  SingleFlightTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-10-10.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

@testable import PrayServices
import Testing

struct SingleFlightTests {
    @Test
    func callsDuringAPassBecomeOneMorePass() async {
        let flight = SingleFlight()
        let passes = Counter()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await flight.run {
                    await passes.increment()
                    try? await Task.sleep(for: .milliseconds(300))
                }
            }

            try? await Task.sleep(for: .milliseconds(100))

            (0..<5).forEach { _ in
                group.addTask {
                    await flight.run { await passes.increment() }
                }
            }
        }

        #expect(await passes.value == 2)
    }

    @Test
    func everyCallerWaitsForTheLastPass() async {
        let flight = SingleFlight()
        let passes = Counter()

        async let first: Void = flight.run {
            try? await Task.sleep(for: .milliseconds(200))
            await passes.increment()
        }

        try? await Task.sleep(for: .milliseconds(50))
        await flight.run { await passes.increment() }

        #expect(await passes.value == 2)
        await first
    }

    @Test
    func callsAfterAPassEachRun() async {
        let flight = SingleFlight()
        let passes = Counter()

        await flight.run { await passes.increment() }
        await flight.run { await passes.increment() }

        #expect(await passes.value == 2)
    }
}

private actor Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
