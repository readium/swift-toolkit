//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Holds closeable resources, such as open files or streams.
public protocol Closeable {
    /// Closes this object and releases any resources associated with it.
    /// If the object is already closed then invoking this method has no effect.
    @available(*, deprecated, message: "Handle Resource deallocation with `deinit` instead.")
    func close()
}

public extension Closeable {
    func close() {}
}

public extension Closeable {
    /// Executes the given block function on this resource and then closes it down correctly whether
    /// an error is thrown or not.
    @available(*, deprecated, message: "The resource is automatically closed when deallocated")
    @inlinable func use<T>(_ block: (Self) throws -> T) rethrows -> T {
        // Can't use `defer` with async functions.
        do {
            let result = try block(self)
            close()
            return result

        } catch {
            close()
            throw error
        }
    }
}
