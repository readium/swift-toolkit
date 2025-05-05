//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Measures the execution time of `block`.
public func measure<T>(_ tag: String, _ block: () -> T) -> T {
    let startPoint = Date()
    defer { print("⏱️ Measure \(tag): \(Date().timeIntervalSince(startPoint)) seconds") }
    return block()
}

/// Measures the execution time of `block`.
public func measure<T>(_ tag: String, _ block: () async -> T) async -> T {
    let startPoint = Date()
    defer { print("⏱️ Measure \(tag): \(Date().timeIntervalSince(startPoint)) seconds") }
    return await block()
}
