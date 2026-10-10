# PrayKit

[![Platform](https://img.shields.io/badge/platform-macos%20%7C%20ios%20%7C%20watchos%20%7C%20ipados-lightgrey)](https://github.com/ZamzamInc/PrayKit)
[![Swift](https://img.shields.io/badge/Swift-5-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-27-blue.svg)](https://developer.apple.com/xcode)
[![SPM](https://img.shields.io/badge/SPM-Compatible-blue)](https://swift.org/package-manager)
[![MIT](https://img.shields.io/badge/License-MIT-red.svg)](https://opensource.org/licenses/MIT)

PrayKit is a Swift package that powers the [Pray Watch](https://apps.apple.com/app/appname/id989923828) app and used for rapid development of Apple platform prayer apps and services. It is a collection of micro utilities and extensions around the [Adhan](https://github.com/batoulapps/adhan-swift) prayer library.

*Note: This library is highly volatile and changes often to stay ahead of cutting-edge technologies. It is recommended to copy over code that you want into your own libraries or fork it.*

Agent-driven maintenance (build and test loop, conventions, consumer contract) is documented in [AGENTS.md](AGENTS.md).

## Installation

### Swift Package Manager

`.package(url: "git@github.com:ZamzamInc/PrayKit.git", .upToNextMajor(from: "1.0.0"))`

## Usage

The `PrayKit` package is divided into four different targets:

* _PrayCore_: Utilities, extensions, service protocols
* _PrayServices_: Concrete services that conform to the core protocols
* _PrayMocks_: Resources for creating test instances
* _PrayKit_: Umbrella that imports the core and the services

### Composing the services

The services are plain values; build each one once at your composition root and pass it where it's needed. The settings live in `SettingsStorage`, which every process of an app (its widgets and extensions included) opens over the same App Group suite:

```swift
let storage = SettingsStorage(defaults: UserDefaults(suiteName: "{{your suite name}}") ?? .standard)
let log = LogManager(services: [LogServiceConsole(minLevel: .verbose, subsystem: "{{your app}}")])

let prayerManager = PrayerManager(
    service: PrayerServiceAdhan(log: log),
    londonService: PrayerServiceLondon(networkManager: NetworkManager(service: NetworkServiceFoundation()), apiKey: "{{key}}", log: log),
    log: log
)
```

A day's prayers for the device's settings and place:

```swift
let prayerDay = try await prayerManager.fetch(for: .now, state: storage.load())
let current = prayerDay.lastObligatory(at: .now)
let next = prayerDay.nextObligatory(at: .now)
```

In SwiftUI, load in `.task(id:)`, so a change to the settings reloads the view:

```swift
struct ContentView: View {
    let prayerManager: PrayerManager
    let state: DeviceState
    @State private var prayerDay: PrayerDay?

    var body: some View {
        Text(prayerDay?.nextObligatory(at: .now)?.type.rawValue ?? "")
            .task(id: state) { prayerDay = try? await prayerManager.fetch(for: .now, state: state) }
    }
}
```

## Testing

Tests live flat in `Tests/` and run with `swift test`. In Xcode, the shared `PrayKit-Package` scheme runs `Package.xctestplan` at the package root.

## Author

* Basem Emara, https://zamzam.io

## License

`PrayKit` is available under the MIT license. See the [LICENSE](https://github.com/ZamzamInc/ZamzamKit/blob/master/LICENSE) file for more info.

