//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type that can be converted into a URL.
public protocol URLConvertible {
    /// Converts the receiver to an `AnyURL`.
    var anyURL: AnyURL { get }

    /// Converts the receiver to a `RelativeURL`, if the represented URL is
    /// relative.
    var relativeURL: RelativeURL? { get }

    /// Converts the receiver to an `AnyAbsoluteURL`, if the represented URL is
    /// absolute.
    var absoluteURL: AnyAbsoluteURL? { get }
}

public extension URLConvertible {
    var relativeURL: RelativeURL? { anyURL.relativeURL }
    var absoluteURL: AnyAbsoluteURL? { anyURL.absoluteURL }
}

extension AnyURL: URLConvertible {
    public var anyURL: AnyURL { self }

    public var relativeURL: RelativeURL? {
        guard case let .relative(url) = self else {
            return nil
        }
        return url
    }

    public var absoluteURL: AnyAbsoluteURL? {
        guard case let .absolute(url) = self else {
            return nil
        }
        return url
    }
}

extension RelativeURL: URLConvertible {
    public var anyURL: AnyURL { .relative(self) }
    public var relativeURL: RelativeURL? { self }
    public var absoluteURL: AnyAbsoluteURL? { nil }
}

extension AnyAbsoluteURL: URLConvertible {
    public var anyURL: AnyURL { .absolute(self) }
    public var relativeURL: RelativeURL? { nil }
    public var absoluteURL: AnyAbsoluteURL? { self }
}

extension HTTPURL: URLConvertible {
    public var anyURL: AnyURL { .absolute(.http(self)) }
    public var relativeURL: RelativeURL? { nil }
    public var absoluteURL: AnyAbsoluteURL? { .http(self) }
}

extension FileURL: URLConvertible {
    public var anyURL: AnyURL { .absolute(.file(self)) }
    public var relativeURL: RelativeURL? { nil }
    public var absoluteURL: AnyAbsoluteURL? { .file(self) }
}

extension NonSpecialAbsoluteURL: URLConvertible {
    public var anyURL: AnyURL { .absolute(.other(self)) }
    public var relativeURL: RelativeURL? { nil }
    public var absoluteURL: AnyAbsoluteURL? { .other(self) }
}
