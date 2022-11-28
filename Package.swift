// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "PrayKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "PrayKit", targets: ["PrayKit"]),
        .library(name: "PrayCore", targets: ["PrayCore"]),
        .library(name: "PrayServices", targets: ["PrayServices"]),
        .library(name: "PrayMocks", targets: ["PrayMocks"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/ZamzamInc/ZamzamKit.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/batoulapps/adhan-swift.git",
            branch: "develop"
        )
    ],
    targets: [
        .target(
            name: "PrayKit",
            dependencies: [
                "PrayCore",
                "PrayServices",
                "PrayMocks"
            ]
        ),
        .testTarget(
            name: "PrayKitTests",
            dependencies: [
                "PrayCore",
                "PrayMocks",
                "PrayServices"
            ]
        ),
        .target(
            name: "PrayCore",
            dependencies: [
                .product(name: "ZamzamCore", package: "ZamzamKit"),
                .product(name: "ZamzamLocation", package: "ZamzamKit"),
                .product(name: "ZamzamNotification", package: "ZamzamKit"),
                .product(name: "ZamzamUI", package: "ZamzamKit")
            ]
        ),
        .target(
            name: "PrayServices",
            dependencies: [
                "PrayCore",
                .product(name: "Adhan", package: "adhan-swift")
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "PrayMocks",
            dependencies: ["PrayCore"]
        )
    ]
)
