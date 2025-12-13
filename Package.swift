// swift-tools-version:5.10
//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PackageDescription

let package = Package(
    name: "Readium",
    defaultLocalization: "en",
    platforms: [.iOS("13.4")],
    products: [
        .library(name: "ReadiumShared", targets: ["ReadiumShared"]),
        .library(name: "ReadiumStreamer", targets: ["ReadiumStreamer"]),
        .library(name: "ReadiumNavigator", targets: ["ReadiumNavigator"]),
        .library(name: "ReadiumOPDS", targets: ["ReadiumOPDS"]),
        .library(name: "ReadiumLCP", targets: ["ReadiumLCP"]),

        // Adapters to third-party dependencies.
        .library(name: "ReadiumAdapterGCDWebServer", targets: ["ReadiumAdapterGCDWebServer"]),
        .library(name: "ReadiumAdapterLCPSQLite", targets: ["ReadiumAdapterLCPSQLite"]),
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.0"),
        .package(url: "https://github.com/ra1028/DifferenceKit.git", from: "1.3.0"),
        .package(url: "https://github.com/readium/Fuzi.git", from: "4.0.0"),
        .package(url: "https://github.com/readium/GCDWebServer.git", from: "4.0.0"),
        .package(url: "https://github.com/readium/ZIPFoundation.git", from: "3.0.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
    ],
    targets: [
        .target(
            name: "ReadiumShared",
            dependencies: [
                "ReadiumInternal",
                "SwiftSoup",
                "Zip",
                .product(name: "ReadiumFuzi", package: "Fuzi"),
                .product(name: "ReadiumZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "Sources/Shared",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("CoreServices"),
                .linkedFramework("UIKit"),
            ]
        ),
        .testTarget(
            name: "ReadiumSharedTests",
            dependencies: [
                "ReadiumShared",
                "TestPublications",
            ],
            path: "Tests/SharedTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),

        .target(
            name: "ReadiumStreamer",
            dependencies: [
                "CryptoSwift",
                "ReadiumShared",
                .product(name: "ReadiumFuzi", package: "Fuzi"),
            ],
            path: "Sources/Streamer",
            resources: [
                .copy("Assets"),
            ]
        ),
        .testTarget(
            name: "ReadiumStreamerTests",
            dependencies: ["ReadiumStreamer"],
            path: "Tests/StreamerTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),

        .target(
            name: "ReadiumNavigator",
            dependencies: [
                "ReadiumInternal",
                "ReadiumShared",
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
            name: "ReadiumNavigatorTests",
            dependencies: ["ReadiumNavigator"],
            path: "Tests/NavigatorTests",
            exclude: [
                "UITests",
            ]
        ),

        .target(
            name: "ReadiumOPDS",
            dependencies: [
                "ReadiumShared",
                .product(name: "ReadiumFuzi", package: "Fuzi"),
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
                "ReadiumShared",
                .product(name: "ReadiumZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "Sources/LCP",
            resources: [
                .process("Resources"),
            ]
        ),
        // These tests require a R2LCPClient.framework to run.
        // TODO: Find a solution to run the tests with GitHub action.
        // .testTarget(
        //     name: "ReadiumLCPTests",
        //     dependencies: ["ReadiumLCP"],
        //     path: "Tests/LCPTests",
        //     resources: [
        //         .copy("../Fixtures"),
        //     ]
        // ),

        .target(
            name: "ReadiumAdapterGCDWebServer",
            dependencies: [
                .product(name: "ReadiumGCDWebServer", package: "GCDWebServer"),
                "ReadiumShared",
            ],
            path: "Sources/Adapters/GCDWebServer"
        ),

        .target(
            name: "ReadiumAdapterLCPSQLite",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                "ReadiumLCP",
            ],
            path: "Sources/Adapters/LCPSQLite"
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

        // Shared test publications used across multiple test targets.
        .target(
            name: "TestPublications",
            path: "Tests/Publications",
            resources: [
                .copy("Publications"),
            ]
        ),
    ]
)
