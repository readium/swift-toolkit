// swift-tools-version:5.3
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PackageDescription

let package = Package(
    name: "r2-navigator-swift",
    defaultLocalization: "en",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "R2Navigator",
            targets: ["R2Navigator"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ra1028/DifferenceKit.git", from: "1.2.0"),
        .package(url: "https://github.com/readium/r2-shared-swift.git", .branch("develop")),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.2"),
    ],
    targets: [
        .target(
            name: "R2Navigator",
            dependencies: [
                "DifferenceKit",
                "SwiftSoup",
                .product(name: "R2Shared", package: "r2-shared-swift"),
            ],
            path: "./r2-navigator-swift/",
            exclude: ["Info.plist"],
            resources: [
                .copy("EPUB/Assets"),
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "R2NavigatorTests",
            dependencies: ["R2Navigator"],
            path: "./r2-navigator-swiftTests/",
            exclude: ["Info.plist"]
        ),
    ]
)
