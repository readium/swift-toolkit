//
//  TransformingFetcher.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Transforms the resources' content of a child fetcher using a list of `ResourceTransformer`
/// functions.
final class TransformingFetcher: Fetcher {

    private let fetcher: Fetcher
    private let transformers: [ResourceTransformer]
    
    init(fetcher: Fetcher, transformers: [ResourceTransformer]) {
        self.fetcher = fetcher
        self.transformers = transformers
    }
    
    convenience init(fetcher: Fetcher, transformer: @escaping ResourceTransformer) {
        self.init(fetcher: fetcher, transformers: [transformer])
    }

    func get(_ link: Link, parameters: LinkParameters) -> Resource {
        let resource = fetcher.get(link, parameters: parameters)
        return transformers.reduce(resource) { resource, transformer in
            transformer(resource)
        }
    }
    
    func close() {
        fetcher.close()
    }
    
}
