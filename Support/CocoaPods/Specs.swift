//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/// Readium toolkit version — bump this when releasing a new version, then run `make podspecs`.
let version = "3.7.0"

/// Minimum iOS deployment target shared by all modules.
let iosTarget = "15.0"

/// Swift version requirement shared by all modules.
let swiftVersion = "5.10"

// MARK: - Data model

struct ModuleSpec {
    let name: String
    /// Path to source files, relative to the repo root (e.g. "Sources/Shared").
    let sourcePath: String
    let summary: String
    var frameworks: [String] = []
    var libraries: [String] = []
    var xcconfig: [String: String] = [:]
    /// Key = bundle name, values = glob patterns relative to repo root.
    var resourceBundles: [String: [String]] = [:]
    var dependencies: [Dependency] = []
}

enum Dependency {
    /// A sibling Readium pod at the same version (e.g. `~> 3.7.0`).
    case readium(String)
    /// An external pod with an explicit version constraint.
    case pod(String, String)
}

// MARK: - Module Definitions (ordered by podspec push order)

let modules: [ModuleSpec] = [
    ModuleSpec(
        name: "ReadiumInternal",
        sourcePath: "Sources/Internal",
        summary: "Private utilities used by the Readium modules",
        xcconfig: ["HEADER_SEARCH_PATHS": "$(SDKROOT)/usr/include/libxml2"]
    ),
    ModuleSpec(
        name: "ReadiumShared",
        sourcePath: "Sources/Shared",
        summary: "Readium Shared",
        frameworks: ["CoreServices"],
        libraries: ["xml2"],
        xcconfig: ["HEADER_SEARCH_PATHS": "$(SDKROOT)/usr/include/libxml2"],
        resourceBundles: ["ReadiumShared": ["Sources/Shared/Resources/**"]],
        dependencies: [
            .readium("ReadiumInternal"),
            .pod("Minizip", "~> 1.0.0"),
            .pod("SwiftSoup", "~> 2.7.0"),
            .pod("ReadiumFuzi", "~> 4.0.0"),
            .pod("ReadiumZIPFoundation", "~> 3.0.1"),
        ]
    ),
    ModuleSpec(
        name: "ReadiumStreamer",
        sourcePath: "Sources/Streamer",
        summary: "Readium Streamer",
        libraries: ["z", "xml2"],
        xcconfig: ["HEADER_SEARCH_PATHS": "$(SDKROOT)/usr/include/libxml2"],
        resourceBundles: ["ReadiumStreamer": [
            "Sources/Streamer/Resources/**",
            "Sources/Streamer/Assets",
        ]],
        dependencies: [
            .readium("ReadiumInternal"),
            .readium("ReadiumShared"),
            .pod("ReadiumFuzi", "~> 4.0.0"),
            .pod("CryptoSwift", "~> 1.8.0"),
        ]
    ),
    ModuleSpec(
        name: "ReadiumNavigator",
        sourcePath: "Sources/Navigator",
        summary: "Readium Navigator",
        resourceBundles: ["ReadiumNavigator": [
            "Sources/Navigator/Resources/**",
            "Sources/Navigator/EPUB/Assets",
        ]],
        dependencies: [
            .readium("ReadiumInternal"),
            .readium("ReadiumShared"),
            .pod("DifferenceKit", "~> 1.0"),
            .pod("SwiftSoup", "~> 2.7.0"),
        ]
    ),
    ModuleSpec(
        name: "ReadiumOPDS",
        sourcePath: "Sources/OPDS",
        summary: "Readium OPDS",
        xcconfig: ["HEADER_SEARCH_PATHS": "$(SDKROOT)/usr/include/libxml2"],
        dependencies: [
            .readium("ReadiumInternal"),
            .readium("ReadiumShared"),
            .pod("ReadiumFuzi", "~> 4.0.0"),
        ]
    ),
    ModuleSpec(
        name: "ReadiumLCP",
        sourcePath: "Sources/LCP",
        summary: "Readium LCP",
        xcconfig: ["HEADER_SEARCH_PATHS": "$(SDKROOT)/usr/include/libxml2"],
        resourceBundles: ["ReadiumLCP": [
            "Sources/LCP/Resources/**",
            "Sources/LCP/**/*.xib",
        ]],
        dependencies: [
            .readium("ReadiumInternal"),
            .readium("ReadiumShared"),
            .pod("ReadiumZIPFoundation", "~> 3.0.1"),
            .pod("CryptoSwift", "~> 1.8.0"),
        ]
    ),
    ModuleSpec(
        name: "ReadiumAdapterGCDWebServer",
        sourcePath: "Sources/Adapters/GCDWebServer",
        summary: "Adapter to use GCDWebServer as an HTTP server in Readium",
        xcconfig: ["HEADER_SEARCH_PATHS": "$(SDKROOT)/usr/include/libxml2"],
        dependencies: [
            .readium("ReadiumInternal"),
            .readium("ReadiumShared"),
            .pod("ReadiumGCDWebServer", "~> 4.0.0"),
        ]
    ),
    ModuleSpec(
        name: "ReadiumAdapterLCPSQLite",
        sourcePath: "Sources/Adapters/LCPSQLite",
        summary: "Adapter to use SQLite.swift for the Readium LCP repositories",
        xcconfig: ["HEADER_SEARCH_PATHS": "$(SDKROOT)/usr/include/libxml2"],
        dependencies: [
            .readium("ReadiumInternal"),
            .readium("ReadiumShared"),
            .readium("ReadiumLCP"),
            .pod("SQLite.swift", "~> 0.15.0"),
        ]
    ),
]
