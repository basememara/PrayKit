# PrayKit — Agent Guide

Open-source Swift package (github.com/basememara/PrayKit) powering the closed-source PrayWatch app. Prayer time calculation, Hijri calendar, Qibla, notification scheduling. Default branch: `main`.

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
- The calculators must keep the days tiling: Maghrib ends at the Isha actually used, tomorrow's Fajr takes the same adjustments as the next day's own, and an Isha that would reach the next Fajr throws. The night (its middle and last third) runs from Maghrib to the Fajr actually used (`PrayerTime.night`), so the last third ends with Isha; a short night can put its middle before Isha, so a day's times are kept in time order, and a night too short to order the two leaves them out rather than failing the day.
- What a screen lists is a separate rule: a day's times until its turnover, then the next day's (`PrayerDay.turnover`, `listedDay`, `PrayerTimer.listedTimes`, `PrayerManager.fetch(listedAt:)`). The turnover is 12 AM in the place's zone, or later when tonight's Isha hasn't begun or its iqama or count-up hasn't ended by then (Paris on France 18), and the next Fajr at the latest. Change the cut-over there and every face follows; the timeline holds an entry at it.
- `PrayerDayRuleTests` holds the rule: sweeps over 17 real fixtures (three with Isha or Maghrib after midnight, one with Fajr before it) for days, timelines, notifications and the Hijri date. A change to day logic lands with a case there.

## Build & test

```sh
swift build
swift test
```

Sandboxed Bash cannot run these (SwiftPM needs `/var/folders` caches the seatbelt blocks) — use Apple's Xcode MCP (`xcode` server): `XcodeOpenWorkspace` on this package directory, then `RunAllTests` (scheme `PrayKit-Package`). Verified on Xcode 27.2 (2026-11-02, 786 tests).

Tests live in `Tests/`, grouped in `Models/`, `Services/` and `Settings/` like the sources (the `PrayKitTests` target has `path: "Tests"`; **Swift Testing**; `PrayTestFixture` in `TestFixture.swift` supplies the log, settings storage and prayer manager against a defaults suite private to each test). `Package.xctestplan` at the root is the plan the shared `PrayKit-Package` scheme runs (`.swiftpm/xcode/xcshareddata/xcschemes/`). Suites are structs and tests are `@Test` functions: Swift Testing builds a fresh instance per test and runs them in parallel, so a suite must not share mutable state. Use `try #require` before comparing an optional, never `#expect(optional?.x == y)`, which traps the runner. A known bug is wrapped in `withKnownIssue("pw-NNN: …")`, which does not rethrow, so no `try` on the call itself. `#expect` has no tolerance form: write `#expect(abs(a - (b)) <= tolerance)` and mind the parentheses. Bug fixes land with a failing test first.

`PrayerTimeSnapshotTests` pins what the engine computes. `Tests/Snapshots/PrayerTimes/<case>.tsv` holds one day per row for each case: places on the method their zone gives them, every method at Kuala Lumpur, London and Oslo, and one setting at a time (high-latitude rules, adjustments, custom angles, Hanafi), over the 21st of each month of 2026, a day in Ramadan, Dec 31 and each zone's clock changes. A day that throws is recorded as an `error:` row, and a polar day whose times were borrowed (`PolarResolution`) ends with a `borrowed:` cell naming the source; a case that sets the polar choice says so in its header. `RecommendedMethods.tsv` holds the method each time zone the host lists gives a user whose method follows the place, plus map entries the host doesn't list. A missing file records and fails once. A changed one fails, listing every moved row with its delta, and writes `<name>.actual.tsv` beside it (gitignored); after review, copy it over the snapshot and commit that change on its own, with the reason. A snapshot proves nothing moved, not that a time is right: `# note:` lines mark rows known to be wrong, and a case removed from the table must take its file with it.

`PrayerTimerSnapshotTests` pins every field a face reads from a `PrayerTimer` the same way, in `Tests/Snapshots/PrayerTimers/<fixture>.<settings row>.tsv`: each day fixture sampled at every moment its countdown changes, a second either side, and on the hour, across a settings matrix (iqama timer on and off, no count-up, Sunrise after Isha, a khutba, a reminder length per prayer). A change to the timer that moves a field fails with the rows that moved.

Notification scheduling is a pure plan and a thin applier. `NotificationPlan.make` (PrayServices, internal) decides every request and removal from the days, the settings, the request and one `now`; `NotificationServiceUN.apply` only talks to the notification center, in a fixed order: the plan's removals, the stale sweep, the adds, the background refresh, the Siri donation. `NotificationPlanSnapshotTests` pins the plan in `Tests/Snapshots/NotificationPlans/<fixture>.<settings row>.tsv`, one row per request with its fire time on the place's clock, wording case, sound, level, category and payload. `ScheduleBranches` lists the branches of the decision, and a test fails if no settings row reaches one. A change to what is scheduled lands as a snapshot diff with its reason; the applier has no test, so a change there needs a device run.

Settings live in `SettingsStorage` (PrayCore): values in the App Group suite under the keys every app version has used, a revision beside each, and `SettingsStorageTests` pins that on-disk format with a golden fixture, so a codec change that would strand older installs fails a test. `LocationRule` is the one rule for saving GPS fixes. Two things it keeps per device, because the place is: a place picked by hand is pinned where it was picked (`isPlacePinned`, never synced; `followsLocation` is the question to ask, not `isGPSEnabled`), and a method that follows the place is read from the device's own place (`Settings.method(at:)`), whatever method is stored.

SwiftLint (`.swiftlint.yml`, the rules PrayWatch and ZamzamKit share) has no build phase in a package, so run `swiftlint` from the package root before a push. `swiftlint --fix` rewrites from the source text alone, so a fix can compile and still change behavior (a protocol's `@escaping` stripped, a double optional's `?? nil` removed): run it one rule at a time with `--only-rule`, read every hunk, and make declaration changes (access, `final`, attributes, initializers) by hand.

## Consumers

PrayWatch consumes this package as a **remote branch dep** (`branch: main`) — pushing to `main` here is effectively publishing to the app. Keep `main` green: `swift test` must pass before any push. Breaking API changes need a matching PrayWatch change in the same sitting.

The prayer-calculation domain knowledge (methods, angles, high-latitude handling) is researched in the Kevin home at `projects/pray-watch/research/prayer-calculations.md`.

## Skills

When working PrayKit alongside the PrayWatch checkout, load the relevant vetted skill from `../PrayWatch/.claude/skills/` before starting: `swift-testing-pro` (tests), `swift-concurrency-pro` (async/actors/Sendable), `swiftdata-pro` (persistence work).
