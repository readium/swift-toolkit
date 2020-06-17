//
//  ProxyFetcher.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
        return closure(link)
    }
    
    public func close() {}
    
}
