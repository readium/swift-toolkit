//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Caches the result of the `block` computation for subsequent calls.
public func memoize<T>(_ block: @escaping () async -> T) -> () async -> T {
    var cache: T?
    return {
        if cache == nil {
            cache = await block()
        }
        return cache!
    }
}

/// Caches the result of the `block` computation for subsequent calls.
public func memoize<T>(_ block: @escaping () async throws -> T) -> () async throws -> T {
    var cache: Result<T, Error>?
    return {
        if cache == nil {
            do {
                cache = try await .success(block())
            } catch {
                cache = .failure(error)
            }
        }
        return try cache!.get()
    }
}
