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
    platforms: [.iOS(.v10)],
    products: [
        .library(name: "R2Shared", targets: ["R2Shared"]),
        .library(name: "R2Streamer", targets: ["R2Streamer"]),
        .library(name: "R2Navigator", targets: ["R2Navigator"]),
        .library(name: "ReadiumOPDS", targets: ["ReadiumOPDS"]),
        .library(name: "ReadiumLCP", targets: ["ReadiumLCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/cezheng/Fuzi.git", from: "3.1.3"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.8"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.1"),
        .package(url: "https://github.com/ra1028/DifferenceKit.git", from: "1.2.0"),
        .package(url: "https://github.com/readium/GCDWebServer.git", from: "3.7.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.2"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.12.2"),
        // 0.9.12 requires iOS 12+
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", "0.9.0"..<"0.9.12"),
    ],
    targets: [
        .target(
            name: "R2Shared",
            dependencies: ["Fuzi", "SwiftSoup", "Zip"],
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
                "R2Shared"
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
                "DifferenceKit",
                "SwiftSoup",
                "R2Shared"
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
                "R2Shared"
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
                .process("Resources")
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
    ]
)

