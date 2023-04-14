//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Transforms the resources' content of a child fetcher using a list of `ResourceTransformer`
/// functions.
public final class TransformingFetcher: Fetcher {
    private let fetcher: Fetcher
    private let transformers: [ResourceTransformer]

    public init(fetcher: Fetcher, transformers: [ResourceTransformer]) {
        self.fetcher = fetcher
        self.transformers = transformers
    }

    public convenience init(fetcher: Fetcher, transformer: @escaping ResourceTransformer) {
        self.init(fetcher: fetcher, transformers: [transformer])
    }

    public var links: [Link] { fetcher.links }

    public func get(_ link: Link) -> Resource {
        let resource = fetcher.get(link)
        return transformers.reduce(resource) { resource, transformer in
            transformer(resource)
        }
    }

    public func close() {
        fetcher.close()
    }
}
