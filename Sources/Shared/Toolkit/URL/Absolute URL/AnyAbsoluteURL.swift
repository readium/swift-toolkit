//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents any type of absolute URL.
public enum AnyAbsoluteURL: AbsoluteURLProtocol, Hashable {
    case http(HTTPURL)
    case file(FileURL)
    case other(NonSpecialAbsoluteURL)

    public init?(url: URL) {
        if let url = HTTPURL(url: url) {
            self = .http(url)
        } else if let url = FileURL(url: url) {
            self = .file(url)
        } else if let url = NonSpecialAbsoluteURL(url: url) {
            self = .other(url)
        } else {
            return nil
        }
    }

    private var wrapped: AbsoluteURLProtocol {
        switch self {
        case let .http(url):
            return url
        case let .file(url):
            return url
        case let .other(url):
            return url
        }
    }

    public var url: URL { wrapped.url }
    public var scheme: URLScheme { wrapped.scheme }
    public var origin: String? { wrapped.origin }

    public var httpURL: HTTPURL? { wrapped as? HTTPURL }
    public var fileURL: FileURL? { wrapped as? FileURL }
}
