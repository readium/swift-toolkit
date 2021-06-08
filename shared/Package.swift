// swift-tools-version:5.3
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PackageDescription

let package = Package(
    name: "r2-shared-swift",
    defaultLocalization: "en",
    platforms: [.iOS(.v10)],
    products: [
        .library(name: "R2Shared", targets: ["R2Shared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/cezheng/Fuzi.git", from: "3.1.3"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.2"),
    ],
    targets: [
        .target(
            name: "R2Shared",
            dependencies: ["Fuzi", "SwiftSoup", "Zip"],
            path: "./r2-shared-swift/",
            exclude: [
                "Info.plist",
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
            path: "./r2-shared-swiftTests/",
            exclude: ["Info.plist"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
