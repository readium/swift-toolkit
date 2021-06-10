// swift-tools-version:5.3
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PackageDescription

let package = Package(
    name: "r2-lcp-swift",
    defaultLocalization: "en",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "ReadiumLCP",
            targets: ["ReadiumLCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.8"),
        .package(url: "https://github.com/readium/r2-shared-swift.git", .branch("develop")),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.12.2"),
        // 0.9.12 requires iOS 12+
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", "0.9.0"..<"0.9.12"),
    ],
    targets: [
        .target(
            name: "ReadiumLCP",
            dependencies: [
                "CryptoSwift",
                "ZIPFoundation",
                .product(name: "R2Shared", package: "r2-shared-swift"),
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "./readium-lcp-swift/",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ]
        ),
        // The test target depends on R2LCPClient.framework.
        // Couldn't find a way to link to it unless it is wrapped in a XCFramework.
        // .testTarget(
        //     name: "ReadiumLCPTests",
        //     dependencies: ["ReadiumLCP"],
        //     path: "./readium-lcp-swiftTests/",
        //     exclude: ["Info.plist"],
        //     resources: [
        //         .copy("Fixtures")
        //     ]
        // )
    ]
)
