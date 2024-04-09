//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Delegates the creation of a `Resource` to a `closure`.
public final class ProxyFetcher: Fetcher {
    public typealias Closure = (Link) -> Resource

    private let closure: Closure

    public init(closure: @escaping Closure) {
        self.closure = closure
    }

    public var links: [Link] { [] }

    public func get(_ link: Link) -> Resource {
        closure(link)
    }

    public func close() {}
}
