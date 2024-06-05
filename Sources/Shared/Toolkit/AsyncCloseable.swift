//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Holds closeable resources, such as open files or streams.
public protocol AsyncCloseable {
    /// Closes this object and releases any resources associated with it.
    /// If the object is already closed then invoking this method has no effect.
    func close() async
}

public extension AsyncCloseable {
    /// Executes the given block function on this resource and then closes it down correctly whether
    /// an error is thrown or not.
    func use<T>(_ block: (Self) async throws -> T) async rethrows -> T {
        // Can't use `defer` with async functions.
        do {
            let result = try await block(self)
            await close()
            return result

        } catch {
            await close()
            throw error
        }
    }
}
