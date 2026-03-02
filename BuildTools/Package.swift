// swift-tools-version:5.3
//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v10_11)],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.59.1"),
    ],
    targets: [
        .target(name: "BuildTools", path: "", exclude: ["Sources"]),
        .target(
            name: "GeneratePodspecs",
            path: "Sources/GeneratePodspecs"
        ),
    ]
)
