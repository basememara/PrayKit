# PrayKit — Agent Guide

Open-source Swift package (github.com/ZamzamInc/PrayKit) powering the closed-source PrayWatch app. Prayer time calculation, Hijri calendar, Qibla, notification scheduling. Default branch: `main`.

## Layout

Pure SPM, `swift-tools-version: 5.7`, platforms macOS 12 / iOS 15 / watchOS 8. Four library products:

- `PrayCore` — enums, errors, extensions, service protocols, settings
- `PrayServices` — service implementations (Hijri, Notification, Prayer, Qibla, Resources)
- `PrayMocks` — test doubles
- `PrayKit` — umbrella

Dependencies (both branch-tracked): ZamzamKit (`main`), adhan-swift (`develop`). Honor the committed `Package.resolved`; re-resolve deliberately, in its own commit.

## Build & test

```sh
swift build
swift test
```

Sandboxed Bash cannot run these (SwiftPM needs `/var/folders` caches the seatbelt blocks) — use Apple's Xcode MCP (`xcode` server): `XcodeOpenWorkspace` on this package directory, then `RunAllTests` (scheme `PrayKit-Package`). Verified on Xcode 27.0.

Tests live flat in `Tests/` (the `PrayKitTests` target has `path: "Tests"`; XCTest; `TestCase.swift` is the shared base). `Package.xctestplan` at the root is the plan the shared `PrayKit-Package` scheme runs (`.swiftpm/xcode/xcshareddata/xcschemes/`). Match the existing XCTest style — the 5.7 tools version predates Swift Testing. Bug fixes land with a failing test first.

## Consumers

PrayWatch consumes this package as a **remote branch dep** (`branch: main`) — pushing to `main` here is effectively publishing to the app. Keep `main` green: `swift test` must pass before any push. Breaking API changes need a matching PrayWatch change in the same sitting.

The prayer-calculation domain knowledge (methods, angles, high-latitude handling) is researched in the Kevin home at `projects/pray-watch/research/prayer-calculations.md`.

## Skills

When working PrayKit alongside the PrayWatch checkout, load the relevant vetted skill from `../PrayWatch/.claude/skills/` before starting: `swift-testing-pro` (tests), `swift-concurrency-pro` (async/actors/Sendable), `swiftdata-pro` (the planned Preferences→SwiftData migration).
