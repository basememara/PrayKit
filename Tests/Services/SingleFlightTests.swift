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
    func callsDuringAPassBecomeOneMorePassThatNeverOverlaps() async {
        let flight = SingleFlight()
        let probe = Probe()
        let (started, didStart) = AsyncStream.makeStream(of: Void.self)
        let (release, didRelease) = AsyncStream.makeStream(of: Void.self)
        let (registered, didRegister) = AsyncStream.makeStream(of: Void.self)
        let callers = 5

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await flight.run {
                    let pass = await probe.begin()
                    if pass == 1 {
                        didStart.yield()
                        for await _ in release { break }
                    }
                    await probe.end()
                }
            }

            for await _ in started { break }

            (0..<callers).forEach { _ in
                group.addTask {
                    await call(flight, announcing: didRegister) { await probe.begin(); await probe.end() }
                    #expect(await probe.finished == 2)
                }
            }

            var count = 0
            for await _ in registered {
                count += 1
                if count == callers { break }
            }
            didRelease.yield()
        }

        #expect(await probe.finished == 2)
        #expect(await probe.maxInFlight == 1)
    }

    @Test
    func callsAfterAPassEachRun() async {
        let flight = SingleFlight()
        let probe = Probe()

        await flight.run { await probe.begin(); await probe.end() }
        await flight.run { await probe.begin(); await probe.end() }

        #expect(await probe.finished == 2)
    }
}

/// Calls `run` on the flight's own executor, so the call is registered before the pass under way can end.
private func call(
    _ flight: isolated SingleFlight,
    announcing didRegister: AsyncStream<Void>.Continuation,
    _ operation: @escaping @Sendable () async -> Void
) async {
    didRegister.yield()
    await flight.run(operation)
}

private actor Probe {
    private(set) var finished = 0
    private(set) var maxInFlight = 0
    private var started = 0
    private var inFlight = 0

    @discardableResult
    func begin() -> Int {
        started += 1
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        return started
    }

    func end() {
        inFlight -= 1
        finished += 1
    }
}
