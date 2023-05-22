// swift-tools-version:5.3
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PackageDescription

let package = Package(
    name: "Readium",
    defaultLocalization: "en",
    platforms: [.iOS(.v11)],
    products: [
        .library(name: "R2Shared", targets: ["R2Shared"]),
        .library(name: "R2Streamer", targets: ["R2Streamer"]),
        .library(name: "R2Navigator", targets: ["R2Navigator"]),
        .library(name: "ReadiumOPDS", targets: ["ReadiumOPDS"]),
        .library(name: "ReadiumLCP", targets: ["ReadiumLCP"]),

        // Adapters to third-party dependencies.
        .library(name: "ReadiumAdapterGCDWebServer", targets: ["ReadiumAdapterGCDWebServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/cezheng/Fuzi.git", from: "3.1.3"),
        // From 1.6.0, the build fails in GitHub actions with Carthage
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", "1.5.1" ..< "1.6.0"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2"),
        .package(url: "https://github.com/ra1028/DifferenceKit.git", from: "1.3.0"),
        .package(url: "https://github.com/readium/GCDWebServer.git", from: "3.7.4"),
        // From 2.6.0, Xcode 14 is required
        .package(url: "https://github.com/scinfu/SwiftSoup.git", "2.5.3" ..< "2.6.0"),
        // 0.14 introduced a breaking change
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", "0.12.0" ..< "0.13.3"),
        // 0.9.12 requires iOS 12+
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", "0.9.0" ..< "0.9.12"),
    ],
    targets: [
        .target(
            name: "R2Shared",
            dependencies: ["ReadiumInternal", "Fuzi", "SwiftSoup", "Zip"],
            path: "Sources/Shared",
            exclude: [
                // Support for ZIPFoundation is not yet achieved.
                "Toolkit/Archive/ZIPFoundation.swift",
            ],
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("CoreServices"),
                .linkedFramework("UIKit"),
            ]
        ),
        .testTarget(
            name: "R2SharedTests",
            dependencies: ["R2Shared"],
            path: "Tests/SharedTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),

        .target(
            name: "R2Streamer",
            dependencies: [
                "CryptoSwift",
                "Fuzi",
                "GCDWebServer",
                "Zip",
                "R2Shared",
            ],
            path: "Sources/Streamer",
            resources: [
                .copy("Assets"),
            ]
        ),
        .testTarget(
            name: "R2StreamerTests",
            dependencies: ["R2Streamer"],
            path: "Tests/StreamerTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),

        .target(
            name: "R2Navigator",
            dependencies: [
                "ReadiumInternal",
                "R2Shared",
                "DifferenceKit",
                "SwiftSoup",
            ],
            path: "Sources/Navigator",
            exclude: [
                "EPUB/Scripts",
            ],
            resources: [
                .copy("EPUB/Assets"),
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "R2NavigatorTests",
            dependencies: ["R2Navigator"],
            path: "Tests/NavigatorTests"
        ),

        .target(
            name: "ReadiumOPDS",
            dependencies: [
                "Fuzi",
                "R2Shared",
            ],
            path: "Sources/OPDS"
        ),
        .testTarget(
            name: "ReadiumOPDSTests",
            dependencies: ["ReadiumOPDS"],
            path: "Tests/OPDSTests",
            resources: [
                .copy("Samples"),
            ]
        ),

        .target(
            name: "ReadiumLCP",
            dependencies: [
                "CryptoSwift",
                "ZIPFoundation",
                "R2Shared",
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "Sources/LCP",
            resources: [
                .process("Resources"),
            ]
        ),
        // These tests require a R2LCPClient.framework to run.
        // FIXME: Find a solution to run the tests with GitHub action.
        // .testTarget(
        //     name: "ReadiumLCPTests",
        //     dependencies: ["ReadiumLCP"],
        //     path: "Tests/LCPTests",
        //     resources: [
        //         .copy("Fixtures"),
        //     ]
        // ),

        .target(
            name: "ReadiumAdapterGCDWebServer",
            dependencies: [
                "GCDWebServer",
                "R2Shared",
            ],
            path: "Sources/Adapters/GCDWebServer"
        ),

        .target(
            name: "ReadiumInternal",
            path: "Sources/Internal"
        ),
        .testTarget(
            name: "ReadiumInternalTests",
            dependencies: ["ReadiumInternal"],
            path: "Tests/InternalTests"
        ),
    ]
)
