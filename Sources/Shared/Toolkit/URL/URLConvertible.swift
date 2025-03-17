//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type that can be converted into an ``AnyURL``.
public protocol URLConvertible {
    /// Converts the receiver to an ``AnyURL``.
    var anyURL: AnyURL { get }
}

extension URL: URLConvertible {
    public var anyURL: AnyURL {
        AnyURL(url: self)
    }
}
