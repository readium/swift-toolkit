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
    platforms: [.iOS(.v13)],
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
        .package(url: "https://github.com/cezheng/Fuzi.git", from: "3.1.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.0"),
        .package(url: "https://github.com/ra1028/DifferenceKit.git", from: "1.3.0"),
        .package(url: "https://github.com/readium/GCDWebServer.git", from: "4.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "ReadiumShared",
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
            name: "ReadiumSharedTests",
            dependencies: ["ReadiumShared"],
            path: "Tests/SharedTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),

        .target(
            name: "ReadiumStreamer",
            dependencies: [
                "CryptoSwift",
                "Fuzi",
                .product(name: "ReadiumGCDWebServer", package: "GCDWebServer"),
                "Zip",
                "ReadiumShared",
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
            path: "Tests/NavigatorTests"
        ),

        .target(
            name: "ReadiumOPDS",
            dependencies: [
                "Fuzi",
                "ReadiumShared",
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
                "ReadiumShared",
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
    ]
)
