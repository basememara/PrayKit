# PrayKit

[![Platform](https://img.shields.io/badge/platform-macos%20%7C%20ios%20%7C%20watchos%20%7C%20ipados-lightgrey)](https://github.com/ZamzamInc/PrayKit)
[![Swift](https://img.shields.io/badge/Swift-5-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-14-blue.svg)](https://developer.apple.com/xcode)
[![SPM](https://img.shields.io/badge/SPM-Compatible-blue)](https://swift.org/package-manager)
[![MIT](https://img.shields.io/badge/License-MIT-red.svg)](https://opensource.org/licenses/MIT)

PrayKit is a Swift package that powers the [Pray Watch](https://apps.apple.com/app/appname/id989923828) app and used for rapid development of Apple platform prayer apps and services. It is a collection of micro utilities and extensions around the [Adhan](https://github.com/batoulapps/adhan-swift) prayer library.

*Note: This library is highly volatile and changes often to stay ahead of cutting-edge technologies. It is recommended to copy over code that you want into your own libraries or fork it.*

## Installation

### Swift Package Manager

`.package(url: "git@github.com:ZamzamInc/PrayKit.git", .upToNextMajor(from: "1.0.0"))`

## Usage

The `PrayKit` package is divided into four different targets:

* _PrayCore_: Utilities, extensions, service protocols
* _PrayServices_: Concrete services that conform to the core protocols
* _PrayMocks_: Resources for creating test instances
* _PrayKit_: Dependency injection container

### Dependency Injection

In `PrayKit`, there is the `PrayKitDependency` protocol that represents the dependency container that wraps all services:

```swift
public protocol PrayKitDependency {
    // Settings
    func constants() -> Constants
    func preferences() -> Preferences
    func localStorage() -> UserDefaults

    // Network
    func networkManager() -> NetworkManager
    func networkService() -> NetworkService
    func networkAdapter() -> URLRequestAdapter?

    // Services
    func prayerManager() -> PrayerManager
    func prayerService() -> PrayerService
    func prayerServiceLondon() -> PrayerService

    func qiblaService() -> QiblaService
    func hijriService() -> HijriService
    func notificationService() -> NotificationService

    func locationManager() -> LocationManager
    func locationService() -> LocationService

    // Diagnostics
    func log() -> LogManager
    func logServices() -> [LogService]
}
```

The SwiftUI `EnvironmentValues` type can be extended to conform to the `PrayKitDependency` protocol and supply the concrete instances:

```swift
extension EnvironmentValues: PrayKitDependency {
    // Thread-safe single instance
    private static let preferences = Preferences(
        defaults: UserDefaults(suiteName: "{{your suite name}}") ?? .standard
    )

    public func preferences() -> Preferences {
        Self.preferences
    }
}

extension EnvironmentValues {
    private static let localStorage: UserDefaults = .standard

    public func localStorage() -> UserDefaults {
        Self.localStorage
    }
}

// MARK: Network

extension EnvironmentValues {
    private static let networkManager = NetworkManager(
        service: networkService,
        adapter: networkAdapter
    )

    public func networkManager() -> NetworkManager {
        Self.networkManager
    }
}

extension EnvironmentValues {
    private static let networkService = NetworkServiceFoundation()

    public func networkService() -> NetworkService {
        Self.networkService
    }

    public func networkAdapter() -> URLRequestAdapter? { nil }
}

// MARK: Services

extension EnvironmentValues {
    private static let notificationService = NotificationServiceUN(
        prayerManager: prayerManager,
        userNotification: .current(),
        preferences: preferences,
        constants: constants,
        localized: NotificationServiceLocalize(),
        log: log
    )

    public func notificationService() -> NotificationService {
        Self.notificationService
    }
}

extension EnvironmentValues {
    private static let prayerManager = PrayerManager(
        service: prayerService,
        londonService: prayerServiceLondon,
        preferences: preferences,
        log: log
    )

    public func prayerManager() -> PrayerManager {
        Self.prayerManager
    }
}

extension EnvironmentValues {
    private static let prayerService = PrayerServiceAdhan(log: log)

    public func prayerService() -> PrayerService {
        Self.prayerService
    }
}

extension EnvironmentValues {
    private static let prayerServiceLondon = PrayerServiceLondon(
        networkManager: networkManager,
        apiKey: "{{your api key}}",
        log: log
    )

    public func prayerServiceLondon() -> PrayerService {
        Self.prayerServiceLondon
    }
}

extension EnvironmentValues {
    private static let qiblaService = QiblaServiceAdhan()

    public func qiblaService() -> QiblaService {
        Self.qiblaService
    }
}

extension EnvironmentValues {
    private static let hijriService = HijriServiceStatic(
        prayerManager: prayerManager,
        preferences: preferences
    )

    public func hijriService() -> HijriService {
        Self.hijriService
    }
}

extension EnvironmentValues {
    private static let locationManager = LocationManager(service: locationService)

    public func locationManager() -> LocationManager {
        Self.locationManager
    }
}

extension EnvironmentValues {
    private static let locationService = LocationServiceCore(
        desiredAccuracy: kCLLocationAccuracyThreeKilometers,
        distanceFilter: 1000
    )

    public func locationService() -> LocationService {
        Self.locationService
    }
}

// MARK: Diagnostics

extension EnvironmentValues {
    private static let log = LogManager(services: logServices)

    public func log() -> LogManager {
        Self.log
    }
}

extension EnvironmentValues {
    private static let logServices: [LogService] = [
        LogServiceConsole(
            minLevel: constants.isDebug || constants.isRunningOnSimulator ? .verbose : .none,
            subsystem: "{{your app}}"
        )
    ]

    public func logServices() -> [LogService] {
        Self.logServices
    }
}
```

Lazy thread-safety was provided for free by using the static properties. More importantly though, `EnvironmentValues` now conforms to the dependency container. We can take this one step further by exposing this to any SwiftUI component by adding a property for the dependency container, which will return itself since it conforms to the container:

```swift
extension EnvironmentValues {
    /// Dependency container for creating instances.
    var dependency: PrayKitDependency? { self }
}
```

Now in SwiftUI, you can add the following property wrapper to access the dependency injection container:

```swift
struct ContentView: View {
    @Environment(\.dependency) dependency

    var body: some View {
        Text("Salam, world!")
            .task {
                guard let preferences = dependency?.preferences() else { return }
                let request = PrayerAPI.Request(from: preferences)
                let prayerDay = await dependency?.prayerManager().fetch(for: .now, with: request)
            }
    }
}
```

## Author

* Basem Emara, https://zamzam.io

## License

`PrayKit` is available under the MIT license. See the [LICENSE](https://github.com/ZamzamInc/ZamzamKit/blob/master/LICENSE) file for more info.

