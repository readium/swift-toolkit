//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Smart pointer holding a weak reference to a reference-based object.
///
/// Get the reference by calling `weakVar()`.
/// Conveniently, the reference can be reset by setting the `ref` property.
@dynamicCallable
public class Weak<T: AnyObject>: @unchecked Sendable {
    fileprivate let lock = NSLock()

    // Weakly held reference.
    fileprivate weak var _ref: T?

    public var ref: T? {
        get { lock.withLock { _ref } }
        set { lock.withLock { _ref = newValue } }
    }

    public init(_ ref: T? = nil) {
        self._ref = ref
    }

    public func dynamicallyCall(withArguments args: [Any]) -> T? {
        ref
    }
}

/// Smart pointer passing as a Weak reference but preventing the reference from being lost.
/// Mainly useful for the unit test suite.
public class _Strong<T: AnyObject>: Weak<T>, @unchecked Sendable {
    private var strongRef: T?

    override public var ref: T? {
        get { lock.withLock { strongRef } }
        set {
            lock.withLock {
                _ref = newValue
                strongRef = newValue
            }
        }
    }

    override public init(_ ref: T? = nil) {
        strongRef = ref
        super.init(ref)
    }
}
