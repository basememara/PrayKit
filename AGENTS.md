# PrayKit — Agent Guide

Open-source Swift package (github.com/basememara/PrayKit) powering the closed-source PrayWatch app. Prayer time calculation, Hijri calendar, Qibla, notification scheduling. Default branch: `main`.

## Layout

Pure SPM, `swift-tools-version: 6.0`, platforms macOS 14 / iOS 17 / watchOS 10 (matching ZamzamKit 7 and the app). Every library target builds in the **Swift 6 language mode** under strict concurrency; Models and service protocols are `Sendable`; the service structs that hold `UserDefaults` or `UNUserNotificationCenter` are `@unchecked Sendable` with a comment naming the invariant. Four library products:

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
- What a screen lists is a separate rule: a day's times until its turnover, then the next day's (`PrayerDay.turnover`, `listedDay`, `PrayerManager.fetch(listedAt:)`). The turnover is 12 AM in the place's zone, or later when tonight's Isha hasn't begun or its iqama or count-up hasn't ended by then (Paris on France 18), and the next Fajr at the latest. Change the cut-over there and every face follows; the timeline holds an entry at it. A list's rows come from that day's `listed(at:)`, or `PrayerTimer.listed`: its times in time order, each with its stage (`ListedPrayerTests`). A stage read from the day a timer counts in, past that day's span, calls the prayer under way passed.
- `PrayerDayRuleTests` holds the rule: sweeps over 17 real fixtures (three with Isha or Maghrib after midnight, one with Fajr before it) for days, timelines, notifications and the Hijri date. A change to day logic lands with a case there.

## Timetables

Some methods read an authority's published timetable instead of calculating; London's Unified Prayer Timetable is the first. `PrayerManager` takes them as `timetables`, a method to the service that reads it, and every other method goes to the calculating service.

| Piece | What it knows |
|---|---|
| `PrayerTimetableSource` (`Sources/PrayServices/Prayer/Timetables/`) | One authority: its folder name (`id`), what one table covers (`period`: a year, a month or a week), the zone a place reads (`zone(for:)`, none by default), the request for a table and how its response reads. `PrayerTimetableSourceLondon` is the model. |
| `PrayerTimetableStore` (same folder) | Where a table is and when the API is asked: the bundled copy first, then the saved file, then the network. A table is whole once it has a day for every day of its period, and a whole table is never asked for again. One the API hasn't published, published in part or refused (a 4xx) is asked for again only after six hours, a wait every process sharing the folder keeps; the days a part table has are saved and read meanwhile, and stay when a later ask fails. A server error or no connection with nothing saved is asked again next time. A request gives up after fifteen seconds, and concurrent days share one. |
| `PrayerServiceTimetable` (`Sources/PrayServices/Prayer/`) | A printed day into prayer times, the same for every source: clocks read in the request's time zone, the user's adjustments, the order check, and tomorrow's Fajr from the table holding tomorrow. It is the one public type, with a factory per source (`.london(apiKey:networkManager:directory:log:)`). |

The bundled tables (`Sources/PrayServices/Resources/PrayerTimetables/`, copied into the bundle with its folders) and the saved ones (the folder the app passes in, in its App Group) share one layout:

```
PrayerTimetables/
├── london/                  a folder per source
│   ├── 2026.json            a file per table, named for the period it covers
│   └── 2028.asked           saved only: when the API was last asked and didn't have the whole table
└── <source>/<zone>/         a folder per zone, where the source has them
    ├── 2027-03.json         a month
    └── 2027-03-08.json      a week, named by its Monday
```

- A file holds the API's response as it came, so the bundled copy, the saved copy and a script's download read the same way. The bundle comes first, so a saved copy never hides a table the package ships.
- Saving a table removes the saved tables older than the period before today's, never one ahead of today, so a calendar looking ahead keeps what the widgets read. The wait and that count are constants in the store; they become per source when one needs different values.
- **Keys:** this package never holds one. A source that needs a key takes it in its initializer and puts it on its request, the app supplies it, and the store never logs a request, a URL or an error that prints one (`PrayerServiceTimetableTests` holds that).
- A source that isn't one request per table (a login first, a rolling window) conforms to `PrayerService` itself, reuses `PrayerTime.day` and `checkOrder`, and is registered in `timetables` the same way.

Adding a source:

1. `PrayerTimetableSource<Name>.swift` beside London's: `id`, `period`, the request, and `days(from:)` over private `Decodable` types. A day that can't be read is left out, which leaves the table short of whole, so it is asked for again every six hours until the day reads; a table not yet published reads as no days.
2. A factory on `PrayerServiceTimetable`, and its line in the app's `timetables` dictionary.
3. The method: a `CalculationMethod` case if it's new, its zones in `mapped`, and its `reach` when the timetable holds only near a city (`CalculationMethod+Recommended.swift`). A new case also needs its branch in `CalculationParameters`' switch, as `.london` has; the calculator never reads it.
4. Tests: the source's own, as `PrayerTimetableSourceLondonTests` (a bundled table reads in full, its format's edges), and a `PrayerTimes` snapshot case for a place on it.
5. Optional: bundled tables in `Resources/PrayerTimetables/<id>/`, for installs that are offline when a period turns over.

## Build & test

```sh
swift build
swift test
```

Sandboxed Bash cannot run these (SwiftPM needs `/var/folders` caches the seatbelt blocks) — use Apple's Xcode MCP (`xcode` server): `XcodeOpenWorkspace` on this package directory, then `RunAllTests` (scheme `PrayKit-Package`). Verified on Xcode 27.2 (2026-11-02, 786 tests).

Tests live in `Tests/`, grouped in `Models/`, `Services/` and `Settings/` like the sources (the `PrayKitTests` target has `path: "Tests"`; **Swift Testing**; `PrayTestFixture` in `TestFixture.swift` supplies the log, settings storage and prayer manager against a defaults suite private to each test). `Package.xctestplan` at the root is the plan the shared `PrayKit-Package` scheme runs (`.swiftpm/xcode/xcshareddata/xcschemes/`). Suites are structs and tests are `@Test` functions: Swift Testing builds a fresh instance per test and runs them in parallel, so a suite must not share mutable state. Use `try #require` before comparing an optional, never `#expect(optional?.x == y)`, which traps the runner. A known bug is wrapped in `withKnownIssue("pw-NNN: …")`, which does not rethrow, so no `try` on the call itself. `#expect` has no tolerance form: write `#expect(abs(a - (b)) <= tolerance)` and mind the parentheses. Bug fixes land with a failing test first.

`PrayerTimeSnapshotTests` pins what the engine computes. `Tests/Snapshots/PrayerTimes/<case>.tsv` holds one day per row for each case: places on the method their zone gives them, every method at Kuala Lumpur, London and Oslo, and one setting at a time (high-latitude rules, adjustments, custom angles, Hanafi), over the 21st of each month of 2026, a day in Ramadan, Dec 31 and each zone's clock changes. A day that throws is recorded as an `error:` row, and a polar day whose times were borrowed (`PolarResolution`) ends with a `borrowed:` cell naming the source; a case that sets the polar choice says so in its header. `RecommendedMethods.tsv` holds the method each time zone the host lists gives a user whose method follows the place, plus map entries the host doesn't list. A missing file records and fails once. A changed one fails, listing every moved row with its delta, and writes `<name>.actual.tsv` beside it (gitignored); after review, copy it over the snapshot and commit that change on its own, with the reason. A snapshot proves nothing moved, not that a time is right: `# note:` lines mark rows known to be wrong, and a case removed from the table must take its file with it.

`PrayerTimerSnapshotTests` pins every field a face reads from a `PrayerTimer` the same way, in `Tests/Snapshots/PrayerTimers/<fixture>.<settings row>.tsv`: each day fixture sampled at every moment its countdown changes, a second either side, and on the hour, across a settings matrix (iqama timer on and off, no count-up, Sunrise after Isha, a khutba, a reminder length per prayer). A change to the timer that moves a field fails with the rows that moved.

Notification scheduling is a pure plan and a thin applier. `NotificationPlan.make` (PrayServices, internal) decides every request and removal from the days, the settings, the request and one `now`; `NotificationServiceUN.apply` only talks to the notification center, in a fixed order: the plan's removals, the stale sweep, the adds, the background refresh, the Siri donation. It writes each request's wording through the app's `NotificationServiceLocalizable`, with every time in it, and in the Siri shortcuts, written by `DateFormatter.prayerTime` on the app's 24-hour setting (`enable24hTimeFormat`), which `PrayerRequestHash` carries so switching it reschedules. With every prayer sound off (`Settings.isPrayerSoundsDisabled`) a run plans nothing: it clears the pending main, reminder and calibrate notifications (`NotificationPlan.clearedCategories`) before the request-hash check, so every caller inherits it. `NotificationPlanSnapshotTests` pins the plan in `Tests/Snapshots/NotificationPlans/<fixture>.<settings row>.tsv`, one row per request with its fire time on the place's clock, wording case, sound, level, category and payload. `ScheduleBranches` lists the branches of the decision, and a test fails if no settings row reaches one. A change to what is scheduled lands as a snapshot diff with its reason; the applier has no test, so a change there needs a device run.

Settings live in `SettingsStorage` (PrayCore): values in the App Group suite under the keys every app version has used, a revision beside each, and `SettingsStorageTests` pins that on-disk format with a golden fixture, so a codec change that would strand older installs fails a test. `LocationRule` is the one rule for saving GPS fixes. Two things it keeps per device, because the place is: a place picked by hand is pinned where it was picked (`isPlacePinned`, never synced; `followsLocation` is the question to ask, not `isGPSEnabled`), and a method that follows the place is read from the device's own place (`Settings.method(at:)`), whatever method is stored.

SwiftLint (`.swiftlint.yml`, the rules PrayWatch and ZamzamKit share) has no build phase in a package, so run `swiftlint` from the package root before a push. `swiftlint --fix` rewrites from the source text alone, so a fix can compile and still change behavior (a protocol's `@escaping` stripped, a double optional's `?? nil` removed): run it one rule at a time with `--only-rule`, read every hunk, and make declaration changes (access, `final`, attributes, initializers) by hand.

## Consumers

PrayWatch consumes this package as a **remote branch dep** (`branch: main`) — pushing to `main` here is effectively publishing to the app. Keep `main` green: `swift test` must pass before any push. Breaking API changes need a matching PrayWatch change in the same sitting.

The prayer-calculation domain knowledge (methods, angles, high-latitude handling) is researched in the Kevin home at `projects/pray-watch/research/prayer-calculations.md`.

## Skills

When working PrayKit alongside the PrayWatch checkout, load the relevant vetted skill from `../PrayWatch/.claude/skills/` before starting: `swift-testing-pro` (tests), `swift-concurrency-pro` (async/actors/Sendable), `swiftdata-pro` (persistence work).
