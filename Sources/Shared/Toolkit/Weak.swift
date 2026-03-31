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
    public package(set) weak var ref: T?

    public init(_ ref: T? = nil) {
        self.ref = ref
    }

    public func dynamicallyCall(withArguments args: [Any]) -> T? {
        ref
    }
}
