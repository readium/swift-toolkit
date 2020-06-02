//
//  Fetcher.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

typealias LinkParameters = [String: String]

/// Provides access to a `Resource` from a `Link`.
protocol Fetcher {
    
    /// Returns the `Resource` at the given `link`'s HREF.
    ///
    /// A `Resource` is always returned, since for some cases we can't know if it exists before
    /// actually fetching it, such as HTTP. Therefore, errors are handled at the Resource level.
    ///
    /// You can provide HREF `parameters` that the source will understand, such as:
    ///  * when `link` is templated,
    ///  * to append additional query parameters to an HTTP request.
    ///
    /// The `parameters` are expected to be percent-decoded.
    func get(_ link: Link, parameters: LinkParameters) -> Resource
    
    /// Closes any opened file handles, removes temporary files, etc.
    func close()
    
}

extension Fetcher {
    
    func get(_ link: Link) -> Resource {
        return get(link, parameters: [:])
    }
    
}
