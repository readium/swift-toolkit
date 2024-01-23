//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type that can be converted into an ``AnyURL``.
public protocol URLConvertible {
    /// Converts the receiver to an ``AnyURL``.
    var anyURL: AnyURL { get }

    /// Converts the receiver to a ``RelativeURL``, if the represented URL is
    /// relative.
    var relativeURL: RelativeURL? { get }

    /// Converts the receiver to an ``AnyAbsoluteURL``, if the represented URL
    /// is absolute.
    var absoluteURL: AbsoluteURL? { get }
}

public extension URLConvertible {
    var relativeURL: RelativeURL? { anyURL.relativeURL }
    var absoluteURL: AbsoluteURL? { anyURL.absoluteURL }
}

extension URL: URLConvertible {
    public var anyURL: AnyURL {
        AnyURL(url: self)
    }
}
