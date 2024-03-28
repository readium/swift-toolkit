//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

public typealias Promise<T> = Void

public extension OPDSParser {
    @available(*, unavailable, message: "Use `parseURL(url:completion:)` instead")
    static func parseURL(url: URL) -> Promise<ParseData> {}
}

public extension OPDS1Parser {
    @available(*, unavailable, message: "Use `parseURL(url:completion:)` instead")
    static func parseURL(url: URL) -> Promise<ParseData> {}

    @available(*, unavailable, message: "Use `fetchOpenSearchTemplate(feed:completion:)` instead")
    static func fetchOpenSearchTemplate(feed: Feed) -> Promise<String> {}
}

public extension OPDS2Parser {
    @available(*, unavailable, message: "Use `parseURL(url:completion:)` instead")
    static func parseURL(url: URL) -> Promise<ParseData> {}
}
