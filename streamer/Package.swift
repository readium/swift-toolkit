// swift-tools-version:5.3
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PackageDescription

let package = Package(
    name: "r2-streamer-swift",
    defaultLocalization: "en",
    platforms: [.iOS(.v10)],
    products: [
        .library(name: "R2Streamer", targets: ["R2Streamer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/cezheng/Fuzi.git", from: "3.1.3"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.8"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.1"),
        .package(url: "https://github.com/readium/GCDWebServer.git", from: "3.7.0"),
        .package(url: "https://github.com/readium/r2-shared-swift.git", .branch("develop")),
    ],
    targets: [
        .target(
            name: "R2Streamer",
            dependencies: [
                "CryptoSwift",
                "Fuzi",
                "GCDWebServer",
                "Zip",
                .product(name: "R2Shared", package: "r2-shared-swift"),
            ],
            path: "./r2-streamer-swift/",
            exclude: ["Info.plist"],
            resources: [
                .copy("Assets"),
            ]
        ),
        .testTarget(
            name: "R2StreamerTests",
            dependencies: ["R2Streamer"],
            path: "./r2-streamer-swiftTests/",
            exclude: ["Info.plist"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
