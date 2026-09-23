# PrayKit — Agent Guide

Open-source Swift package (github.com/ZamzamInc/PrayKit) powering the closed-source PrayWatch app. Prayer time calculation, Hijri calendar, Qibla, notification scheduling. Default branch: `main`.

## Layout

Pure SPM, `swift-tools-version: 6.0`, platforms macOS 12 / iOS 15 / watchOS 8. Every library target builds in the **Swift 6 language mode** under strict concurrency; Models and service protocols are `Sendable`; the service structs that hold `UserDefaults`, `NetworkManager` or `UNUserNotificationCenter` are `@unchecked Sendable` with a comment naming the invariant. Four library products:

- `PrayCore` — enums, errors, extensions, service protocols, settings
- `PrayServices` — service implementations (Hijri, Notification, Prayer, Qibla, Resources)
- `PrayMocks` — test doubles
- `PrayKit` — umbrella

Dependencies (both branch-tracked): ZamzamKit (`main`), adhan-swift (`develop`). Honor the committed `Package.resolved`; re-resolve deliberately, in its own commit. When this checkout is open inside the PrayWatch workspace, Xcode rewrites that file with the app's workspace-wide resolution (the ZamzamKit pin disappears, app-only packages appear); never commit that drift — `git checkout -- Package.resolved` first. ZamzamKit is Basem's own foundation package (`/Users/basem/Developer/Zamzam/ZamzamKit`, with its own `AGENTS.md`); utilities that are not prayer-specific belong there.

## Build & test

```sh
swift build
swift test
```

Sandboxed Bash cannot run these (SwiftPM needs `/var/folders` caches the seatbelt blocks) — use Apple's Xcode MCP (`xcode` server): `XcodeOpenWorkspace` on this package directory, then `RunAllTests` (scheme `PrayKit-Package`). Verified on Xcode 27.0.

Tests live flat in `Tests/` (the `PrayKitTests` target has `path: "Tests"`; **Swift Testing**; `PrayTestFixture` in `TestFixture.swift` supplies the log, preferences and prayer manager against a defaults suite private to each test). `Package.xctestplan` at the root is the plan the shared `PrayKit-Package` scheme runs (`.swiftpm/xcode/xcshareddata/xcschemes/`). Suites are structs and tests are `@Test` functions: Swift Testing builds a fresh instance per test and runs them in parallel, so a suite must not share mutable state. Use `try #require` before comparing an optional, never `#expect(optional?.x == y)`, which traps the runner. A known bug is wrapped in `withKnownIssue("pw-NNN: …")`, which does not rethrow, so no `try` on the call itself. `#expect` has no tolerance form: write `#expect(abs(a - (b)) <= tolerance)` and mind the parentheses. Bug fixes land with a failing test first.

Combine publishers are asserted through `firstValue(of:timeout:while:)` in `PreferencesTests`: it subscribes, applies the mutation, and returns the first value or `nil` once the timeout wins, so a publisher that never fires fails instead of hanging.

## Consumers

PrayWatch consumes this package as a **remote branch dep** (`branch: main`) — pushing to `main` here is effectively publishing to the app. Keep `main` green: `swift test` must pass before any push. Breaking API changes need a matching PrayWatch change in the same sitting.

The prayer-calculation domain knowledge (methods, angles, high-latitude handling) is researched in the Kevin home at `projects/pray-watch/research/prayer-calculations.md`.

## Skills

When working PrayKit alongside the PrayWatch checkout, load the relevant vetted skill from `../PrayWatch/.claude/skills/` before starting: `swift-testing-pro` (tests), `swift-concurrency-pro` (async/actors/Sendable), `swiftdata-pro` (the planned Preferences→SwiftData migration).
