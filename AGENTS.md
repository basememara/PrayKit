# PrayKit — Agent Guide

Open-source Swift package (github.com/ZamzamInc/PrayKit) powering the closed-source PrayWatch app. Prayer time calculation, Hijri calendar, Qibla, notification scheduling. Default branch: `main`.

## Layout

Pure SPM, `swift-tools-version: 6.0`, platforms macOS 14 / iOS 17 / watchOS 10 (matching ZamzamKit 7 and the app). Every library target builds in the **Swift 6 language mode** under strict concurrency; Models and service protocols are `Sendable`; the service structs that hold `UserDefaults`, `NetworkManager` or `UNUserNotificationCenter` are `@unchecked Sendable` with a comment naming the invariant. Four library products:

- `PrayCore` — enums, errors, extensions, service protocols, settings
- `PrayServices` — service implementations (Hijri, Notification, Prayer, Qibla, Resources)
- `PrayMocks` — test doubles
- `PrayKit` — umbrella

Dependencies (both branch-tracked): ZamzamKit (`main`), adhan-swift (`develop`). Honor the committed `Package.resolved`; re-resolve deliberately, in its own commit. When this checkout is open inside the PrayWatch workspace, Xcode rewrites that file with the app's workspace-wide resolution (the ZamzamKit pin disappears, app-only packages appear); never commit that drift — `git checkout -- Package.resolved` first. ZamzamKit is Basem's own foundation package (`/Users/basem/Developer/Zamzam/ZamzamKit`, with its own `AGENTS.md`); utilities that are not prayer-specific belong there.

## The prayer day

A prayer day runs from its Fajr to the next Fajr: its essential prayers (Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha) follow one another with no gap, Isha ends at the next day's Fajr, and every moment belongs to exactly one day. Midnight is not a boundary; Isha (Paris on France 18) and even Maghrib (Reykjavik) can begin after it.

- `PrayerManager.fetch(at:)` is the day holding a moment, `fetch(spanning:)` the days from it, `fetch(for:)` and `fetch(between:)` calendar days for browsing.
- A `PrayerDay` answers from its Fajr through its `tomorrow`, never for a moment before its Fajr, which belongs to the day before. There is no `yesterday`.
- The calculators must keep the days tiling: Maghrib ends at the Isha actually used, tomorrow's Fajr takes the same adjustments as the next day's own, and an Isha that would reach the next Fajr throws.
- `PrayerDayRuleTests` holds the rule: sweeps over 16 real fixtures (three with Isha or Maghrib after midnight) for days, timelines, notifications and the Hijri date. A change to day logic lands with a case there.

## Build & test

```sh
swift build
swift test
```

Sandboxed Bash cannot run these (SwiftPM needs `/var/folders` caches the seatbelt blocks) — use Apple's Xcode MCP (`xcode` server): `XcodeOpenWorkspace` on this package directory, then `RunAllTests` (scheme `PrayKit-Package`). Verified on Xcode 27.0.

Tests live in `Tests/`, grouped in `Models/`, `Services/` and `Settings/` like the sources (the `PrayKitTests` target has `path: "Tests"`; **Swift Testing**; `PrayTestFixture` in `TestFixture.swift` supplies the log, settings storage and prayer manager against a defaults suite private to each test). `Package.xctestplan` at the root is the plan the shared `PrayKit-Package` scheme runs (`.swiftpm/xcode/xcshareddata/xcschemes/`). Suites are structs and tests are `@Test` functions: Swift Testing builds a fresh instance per test and runs them in parallel, so a suite must not share mutable state. Use `try #require` before comparing an optional, never `#expect(optional?.x == y)`, which traps the runner. A known bug is wrapped in `withKnownIssue("pw-NNN: …")`, which does not rethrow, so no `try` on the call itself. `#expect` has no tolerance form: write `#expect(abs(a - (b)) <= tolerance)` and mind the parentheses. Bug fixes land with a failing test first.

Settings live in `SettingsStorage` (PrayCore): values in the App Group suite under the keys every app version has used, a revision beside each, and `SettingsStorageTests` pins that on-disk format with a golden fixture, so a codec change that would strand older installs fails a test. `LocationRule` is the one rule for saving GPS fixes.

## Consumers

PrayWatch consumes this package as a **remote branch dep** (`branch: main`) — pushing to `main` here is effectively publishing to the app. Keep `main` green: `swift test` must pass before any push. Breaking API changes need a matching PrayWatch change in the same sitting.

The prayer-calculation domain knowledge (methods, angles, high-latitude handling) is researched in the Kevin home at `projects/pray-watch/research/prayer-calculations.md`.

## Skills

When working PrayKit alongside the PrayWatch checkout, load the relevant vetted skill from `../PrayWatch/.claude/skills/` before starting: `swift-testing-pro` (tests), `swift-concurrency-pro` (async/actors/Sendable), `swiftdata-pro` (persistence work).
