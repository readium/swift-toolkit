// swift-tools-version:5.3
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PackageDescription

let package = Package(
    name: "r2-opds-swift",
    defaultLocalization: "en",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "ReadiumOPDS",
            targets: ["ReadiumOPDS"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/cezheng/Fuzi.git", from: "3.1.3"),
        .package(url: "https://github.com/readium/r2-shared-swift.git", from: "2.1.0"),
    ],
    targets: [
        .target(
            name: "ReadiumOPDS",
            dependencies: [
                "Fuzi",
                .product(name: "R2Shared", package: "r2-shared-swift"),
            ],
            path: "./readium-opds/",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "ReadiumOPDSTests",
            dependencies: ["ReadiumOPDS"],
            path: "./readium-opdsTests/",
            exclude: ["Info.plist"],
            resources: [
                .copy("Samples"),
            ]
        ),
    ]
)
