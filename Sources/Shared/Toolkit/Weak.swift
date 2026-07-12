//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

/// Smart pointer holding a weak reference to a reference-based object.
///
/// Get the reference by calling `weakVar()`.
/// Conveniently, the reference can be reset by setting the `ref` property.
@dynamicCallable
public final class Weak<T: AnyObject & Sendable>: Sendable {
    /// Invariant making `nonisolated(unsafe)` sound: `ref` is written exactly
    /// once, before the `Weak` instance is shared with other isolation
    /// domains (see `Publication.init`), and is read-only afterwards.
    public package(set) nonisolated(unsafe) weak var ref: T?

    public init(_ ref: T? = nil) {
        self.ref = ref
    }

    public func dynamicallyCall(withArguments args: [Any]) -> T? {
        ref
    }
}
