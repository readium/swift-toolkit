//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Smart pointer holding a weak reference to a reference-based object.
///
/// Get the reference by calling `weakVar()`.
/// Conveniently, the reference can be reset by setting the `ref` property.
@dynamicCallable
public class Weak<T: AnyObject> {
    // Weakly held reference.
    public weak var ref: T?

    public init(_ ref: T? = nil) {
        self.ref = ref
    }

    public func dynamicallyCall(withArguments args: [Any]) -> T? {
        ref
    }
}

/// Smart pointer passing as a Weak reference but preventing the reference from being lost.
/// Mainly useful for the unit test suite.
public class _Strong<T: AnyObject>: Weak<T> {
    private var strongRef: T?

    override public var ref: T? {
        get { super.ref }
        set {
            super.ref = newValue
            strongRef = newValue
        }
    }

    override public init(_ ref: T? = nil) {
        strongRef = ref
        super.init(ref)
    }
}
